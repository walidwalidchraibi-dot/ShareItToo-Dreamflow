import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

import cors from 'cors';
import express from 'express';
import { rateLimit } from 'express-rate-limit';
import { fileTypeFromBuffer } from 'file-type';
import helmet from 'helmet';
import multer from 'multer';

import {
  accountDeletionConfirmForm,
  accountDeletionRequestForm,
  consumeActionToken,
  createActionToken,
  lockValidActionToken,
  passwordResetForm,
  resultPage,
} from './account_actions.js';
import { config } from './config.js';
import { inTransaction, pool } from './db.js';
import {
  amountToMinor,
  canTransitionBooking,
  normalizeBookingStatus,
  normalizeCurrency,
  parseBookingPeriod,
} from './booking_domain.js';
import {
  getMailerStatus,
  sendAccountDeletionEmail,
  sendEmailChangeAlert,
  sendEmailChangeVerification,
  sendPasswordResetEmail,
  sendVerificationEmail,
} from './mailer.js';
import { publishToAll, publishToUsers } from './realtime.js';
import { releaseMetadata } from './release.js';
import {
  bearerToken,
  defaultProfile,
  hashPassword,
  hashRefreshToken,
  isValidBirthDate,
  isValidEmail,
  isValidPassword,
  newRefreshToken,
  normalizeEmail,
  passwordPolicyError,
  requireAuth,
  safeText,
  sanitizeProfileUpdate,
  shapeUser,
  signAccessToken,
  verifyAccessToken,
  verifyPassword,
} from './security.js';

class HttpError extends Error {
  constructor(status, code, details = undefined) {
    super(code);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function asyncRoute(handler) {
  return (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
}

function sendHtml(res, status, html) {
  res.set({
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
  });
  res.status(status).send(html);
}

function identifier(value, prefix) {
  const raw = typeof value === 'string' ? value.trim() : '';
  if (raw && raw.length <= 120 && /^[A-Za-z0-9_.:-]+$/.test(raw)) return raw;
  return `${prefix}_${crypto.randomUUID()}`;
}

function ensureObject(value, code = 'invalid_payload') {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new HttpError(400, code);
  return { ...value };
}

const requireActiveAccount = asyncRoute(async (req, _res, next) => {
  const result = await pool.query(
    `SELECT u.id, u.email, u.role, u.account_status, u.deactivated_at,
            session.id AS session_id, session.revoked_at AS session_revoked_at
     FROM users AS u
     LEFT JOIN auth_sessions AS session
       ON session.id = $2 AND session.user_id = u.id
     WHERE u.id = $1`,
    [req.auth.userId, req.auth.sessionId],
  );
  const user = result.rows[0];
  if (!user || user.deactivated_at || user.account_status !== 'active'
      || !user.session_id || user.session_revoked_at) {
    throw new HttpError(401, 'account_not_active');
  }
  req.actor = {
    id: user.id,
    email: user.email,
    role: user.role,
    accountStatus: user.account_status,
    deactivatedAt: user.deactivated_at,
  };
  next();
});

async function writeAudit(client, {
  actor = null,
  action,
  resourceType,
  resourceId,
  metadata = {},
}) {
  await client.query(
    `INSERT INTO audit_log (actor_id, actor_role, action, resource_type, resource_id, metadata)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb)`,
    [
      actor?.id ?? null,
      actor?.role ?? 'system',
      action,
      resourceType,
      resourceId,
      JSON.stringify(metadata),
    ],
  );
}

function listingFinancials(payload) {
  return {
    currency: normalizeCurrency(payload.currency),
    pricePerDayMinor: amountToMinor(payload.pricePerDay),
    securityDepositMinor: amountToMinor(payload.deposit),
  };
}

function listingPayload(raw, { id, ownerId, existingCreatedAt = null }) {
  const payload = ensureObject(raw);
  const title = safeText(payload.title, 160);
  const description = safeText(payload.description, 10_000);
  if (!title || !description) throw new HttpError(400, 'listing_title_and_description_required');
  const createdAt = existingCreatedAt ?? (Date.parse(payload.createdAt) ? new Date(payload.createdAt).toISOString() : new Date().toISOString());
  const photos = Array.isArray(payload.photos) ? payload.photos.slice(0, 12).map((photo) => safeText(photo, 4000)).filter(Boolean) : [];
  return {
    ...payload,
    id,
    ownerId,
    title,
    description,
    photos,
    createdAt,
    status: safeText(payload.status, 30) || 'active',
    isActive: payload.isActive !== false && payload.status !== 'ended',
  };
}

function rentalPayload(raw, { id, itemId, ownerId, renterId, existingStatus = null }) {
  const payload = ensureObject(raw);
  const status = normalizeBookingStatus(payload.status ?? existingStatus);
  const period = parseBookingPeriod(payload.start, payload.end);
  if (!period) {
    throw new HttpError(400, 'invalid_rental_period');
  }
  return {
    ...payload,
    id,
    itemId,
    ownerId,
    renterId,
    status,
    start: period.startsAt.toISOString(),
    end: period.endsAt.toISOString(),
    createdAt: Date.parse(payload.createdAt) ? new Date(payload.createdAt).toISOString() : new Date().toISOString(),
  };
}

function existingRentalPayload(raw, existing, actorId) {
  const candidate = ensureObject(raw, 'invalid_request');
  const stored = ensureObject(existing.payload, 'invalid_stored_request');
  const isRenter = actorId === existing.renter_id;
  const merged = { ...stored };

  for (const key of [
    'needsReview', 'reviewReason', 'reviewSource', 'reviewRequestedAt',
    'handoverConfirmation', 'returnConfirmation',
  ]) {
    if (Object.hasOwn(candidate, key)) merged[key] = candidate[key];
  }
  if (isRenter && existing.status === 'pending') {
    for (const key of ['start', 'end', 'expressRequested', 'expressRequestedAt']) {
      if (Object.hasOwn(candidate, key)) merged[key] = candidate[key];
    }
  }
  if (isRenter && (stored.expressStatus === null || stored.expressStatus === 'pending')) {
    merged.expressStatus = candidate.expressRequested === false ? null : 'pending';
  }
  if (!isRenter && ['pending', 'accepted', 'declined'].includes(candidate.expressStatus)) {
    merged.expressStatus = candidate.expressStatus;
    merged.expressConfirmedAt = candidate.expressConfirmedAt ?? null;
  }

  const nextStatus = normalizeBookingStatus(candidate.status ?? existing.status);
  merged.status = nextStatus;
  if (nextStatus === 'cancelled') merged.cancelledBy = isRenter ? 'renter' : 'owner';
  return rentalPayload(merged, {
    id: existing.id,
    itemId: existing.item_id,
    ownerId: existing.owner_id,
    renterId: existing.renter_id,
    existingStatus: existing.status,
  });
}

function threadPayload(raw, { id, requestId, itemId, user1Id, user2Id, createdAt }) {
  const payload = ensureObject(raw);
  return {
    ...payload,
    id,
    requestId,
    itemId,
    user1Id,
    user2Id,
    messages: undefined,
    archivedForUserIds: undefined,
    createdAt: createdAt.toISOString(),
  };
}

function requestIp(req) {
  const value = safeText(req.ip, 64);
  return value || null;
}

function normalizePhoneE164(value) {
  const raw = safeText(value, 40);
  if (!raw) return null;
  const compact = raw.replace(/[\s().-]/g, '').replace(/^00/, '+');
  return /^\+[1-9][0-9]{7,14}$/.test(compact) ? compact : undefined;
}

function deviceLabel(userAgent) {
  const agent = safeText(userAgent, 500).toLowerCase();
  if (/iphone|ipad/.test(agent)) return 'iPhone/iPad';
  if (/android/.test(agent)) return 'Android';
  if (/macintosh|mac os/.test(agent)) return 'Mac';
  if (/windows/.test(agent)) return 'Windows';
  if (/linux/.test(agent)) return 'Linux';
  if (/chrome|safari|firefox|edge/.test(agent)) return 'Browser';
  return 'Unbekanntes Gerät';
}

async function issueSession(client, user, {
  userAgent,
  ipAddress,
  sessionId = null,
  familyId = null,
} = {}) {
  const normalizedAgent = safeText(userAgent, 500) || null;
  const normalizedIp = safeText(ipAddress, 64) || null;
  const activeSessionId = sessionId ?? crypto.randomUUID();
  const activeFamilyId = familyId ?? crypto.randomUUID();
  if (!sessionId) {
    await client.query(
      `INSERT INTO auth_sessions (
         id, user_id, device_label, user_agent, ip_address
       ) VALUES ($1, $2, $3, $4, $5::inet)`,
      [activeSessionId, user.id, deviceLabel(normalizedAgent), normalizedAgent, normalizedIp],
    );
  } else {
    await client.query(
      `UPDATE auth_sessions
       SET last_seen_at = now(), user_agent = COALESCE($2, user_agent),
           device_label = CASE WHEN $2 IS NULL THEN device_label ELSE $3 END,
           ip_address = COALESCE($4::inet, ip_address)
       WHERE id = $1 AND revoked_at IS NULL`,
      [activeSessionId, normalizedAgent, deviceLabel(normalizedAgent), normalizedIp],
    );
  }
  const refreshToken = newRefreshToken();
  const refreshHash = hashRefreshToken(refreshToken);
  const expiresAt = new Date(Date.now() + config.refreshTokenLifetimeDays * 24 * 60 * 60 * 1000);
  await client.query(
    `INSERT INTO refresh_tokens (
       user_id, token_hash, expires_at, user_agent, session_id, family_id
     ) VALUES ($1, $2, $3, $4, $5, $6)`,
    [user.id, refreshHash, expiresAt, normalizedAgent, activeSessionId, activeFamilyId],
  );
  return {
    accessToken: signAccessToken(user, { sessionId: activeSessionId }),
    refreshToken,
    expiresIn: config.accessTokenLifetimeSeconds,
    sessionId: activeSessionId,
    user: shapeUser(user),
  };
}

async function createAndSendVerification(user) {
  const token = await inTransaction((client) => createActionToken(client, {
    userId: user.id,
    kind: 'verify_email',
  }));
  await sendVerificationEmail({
    email: user.email,
    displayName: user.profile?.displayName,
    token,
  });
}

async function resetPasswordWithToken(token, password) {
  const policyError = passwordPolicyError(password);
  if (policyError) throw new HttpError(400, policyError);
  const passwordHash = await hashPassword(password);
  return inTransaction(async (client) => {
    const row = await lockValidActionToken(client, { token, kind: 'reset_password' });
    if (!row) throw new HttpError(400, 'invalid_or_expired_reset_link');
    await client.query(
      `UPDATE users
       SET password_hash = $2, password_changed_at = now(),
           failed_login_attempts = 0, login_locked_until = NULL
       WHERE id = $1`,
      [row.id, passwordHash],
    );
    await consumeActionToken(client, row.action_token_id);
    await client.query(
      `UPDATE auth_action_tokens
       SET consumed_at = COALESCE(consumed_at, now())
       WHERE user_id = $1 AND kind = 'reset_password'`,
      [row.id],
    );
    await client.query(
      'UPDATE refresh_tokens SET revoked_at = COALESCE(revoked_at, now()) WHERE user_id = $1',
      [row.id],
    );
    await client.query(
      `UPDATE auth_sessions
       SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'password_reset')
       WHERE user_id = $1`,
      [row.id],
    );
    await writeAudit(client, {
      actor: { id: row.id, role: row.role ?? 'user' },
      action: 'auth.password_reset',
      resourceType: 'user',
      resourceId: row.id,
    });
    return row;
  });
}

async function accountDeletionPreflight(client, userId) {
  const result = await client.query(
    `SELECT
       (SELECT count(*)::int FROM bookings
        WHERE (owner_id = $1 OR renter_id = $1)
          AND status IN ('pending', 'accepted', 'running')) AS active_bookings,
       (SELECT count(*)::int FROM payouts
        WHERE payee_id = $1 AND status IN ('scheduled', 'pending')) AS open_payouts,
       (SELECT count(*)::int FROM payments AS payment
        JOIN bookings AS booking ON booking.id = payment.booking_id
        WHERE (booking.owner_id = $1 OR booking.renter_id = $1)
          AND payment.status IN ('created', 'requires_action', 'authorized')) AS active_payments,
       (SELECT count(*)::int FROM disputes AS dispute
        JOIN bookings AS booking ON booking.id = dispute.booking_id
        WHERE (booking.owner_id = $1 OR booking.renter_id = $1)
          AND dispute.status IN ('open', 'investigating', 'waiting_for_user')) AS open_disputes`,
    [userId],
  );
  const counts = result.rows[0] ?? {};
  const definitions = [
    ['active_bookings', 'Aktive oder bevorstehende Buchungen'],
    ['open_payouts', 'Offene Auszahlungen'],
    ['active_payments', 'Laufende Zahlungsabwicklung'],
    ['open_disputes', 'Offene Streitfälle'],
  ];
  const blockers = definitions
    .map(([id, label]) => ({ id, label, count: Number(counts[id] ?? 0) }))
    .filter((blocker) => blocker.count > 0);
  return { canDelete: blockers.length === 0, blockers };
}

async function eraseAccount(client, user, { actorRole = 'user', source = 'app' } = {}) {
  const preflight = await accountDeletionPreflight(client, user.id);
  if (!preflight.canDelete) throw new HttpError(409, 'account_deletion_blocked', preflight);
  const anonymousEmail = `deleted+${crypto.randomUUID()}@anonymized.invalid`;
  await client.query(
    `UPDATE listings
     SET is_active = false,
         payload = jsonb_build_object(
           'id', id,
           'ownerId', owner_id,
           'title', COALESCE(NULLIF(payload->>'title', ''), 'Gelöschtes Angebot'),
           'status', 'ended',
           'isActive', false,
           'photos', '[]'::jsonb,
           'createdAt', COALESCE(payload->>'createdAt', created_at::text)
         )
     WHERE owner_id = $1`,
    [user.id],
  );
  await client.query(
    `UPDATE rental_requests
     SET payload = payload - ARRAY[
       'addressLine', 'deliveryAddressLine', 'deliveryCity', 'deliveryPostalCode',
       'returnAddressLine', 'returnCity', 'returnPostalCode',
       'renterName', 'listerName', 'ownerName', 'email', 'phone'
     ]::text[]
     WHERE owner_id = $1 OR renter_id = $1`,
    [user.id],
  );
  await client.query(
    `UPDATE message_threads
     SET payload = payload - ARRAY['renterName', 'listerName', 'ownerName', 'email', 'phone']::text[]
     WHERE user1_id = $1 OR user2_id = $1`,
    [user.id],
  );
  await client.query(
    `UPDATE messages
     SET body = '[Nachricht nach Kontolöschung entfernt]', sender_id = NULL
     WHERE sender_id = $1`,
    [user.id],
  );
  await client.query('UPDATE reviews SET body = NULL WHERE reviewer_id = $1', [user.id]);
  const erasedUploads = await client.query(
    'DELETE FROM uploads WHERE owner_id = $1 RETURNING storage_name',
    [user.id],
  );
  await client.query('DELETE FROM push_devices WHERE user_id = $1', [user.id]);
  await client.query('DELETE FROM auth_identities WHERE user_id = $1', [user.id]);
  await client.query('DELETE FROM auth_action_tokens WHERE user_id = $1', [user.id]);
  await client.query('DELETE FROM refresh_tokens WHERE user_id = $1', [user.id]);
  await client.query('DELETE FROM auth_sessions WHERE user_id = $1', [user.id]);
  await client.query(
    `UPDATE users
     SET email = $2,
         password_hash = NULL,
         profile = '{"displayName":"Gelöschter Nutzer","emailVerified":false,"phoneVerified":false,"isVerified":false,"isBanned":false,"role":"user"}'::jsonb,
         account_status = 'closed',
         deactivated_at = COALESCE(deactivated_at, now()),
         personal_data_erased_at = now(),
         email_verified_at = NULL,
         phone_e164 = NULL,
         phone_verified_at = NULL,
         failed_login_attempts = 0,
         login_locked_until = NULL
     WHERE id = $1`,
    [user.id, anonymousEmail],
  );
  await writeAudit(client, {
    actor: { id: user.id, role: actorRole },
    action: 'account.deleted',
    resourceType: 'user',
    resourceId: user.id,
    metadata: {
      source,
      retained: ['pseudonymous_booking_records', 'legally_required_financial_records', 'audit_log'],
      erasedUploadCount: erasedUploads.rowCount,
    },
  });
  return {
    deleted: true,
    erasedUploadStorageNames: erasedUploads.rows.map((row) => row.storage_name),
  };
}

async function removeErasedUploadFiles(storageNames) {
  const failures = [];
  for (const storageName of storageNames) {
    if (!/^[0-9a-f-]{36}\.[a-z0-9]+$/i.test(storageName)) {
      failures.push({ storageName, code: 'invalid_storage_name' });
      continue;
    }
    try {
      await fs.unlink(path.join(config.uploadDir, storageName));
    } catch (error) {
      if (error?.code !== 'ENOENT') failures.push({ storageName, code: error?.code ?? 'unlink_failed' });
    }
  }
  if (failures.length) {
    console.error('[account] erased upload file cleanup failed', failures);
  }
  return failures;
}

async function listRentalRequests(client, userId) {
  const result = await client.query(
    `SELECT payload FROM rental_requests
     WHERE owner_id = $1 OR renter_id = $1
     ORDER BY created_at DESC`,
    [userId],
  );
  return result.rows.map((row) => row.payload);
}

async function listThreads(client, userId) {
  const result = await client.query(
    `SELECT id, request_id, item_id, user1_id, user2_id, payload, archived_for, created_at, last_message_at
     FROM message_threads
     WHERE user1_id = $1 OR user2_id = $1
     ORDER BY COALESCE(last_message_at, created_at) DESC`,
    [userId],
  );
  const threads = [];
  for (const row of result.rows) {
    const messages = await client.query(
      `SELECT id, sender_id, sender_type, body, is_read, created_at
       FROM messages WHERE thread_id = $1 ORDER BY created_at`,
      [row.id],
    );
    threads.push({
      ...(row.payload ?? {}),
      id: row.id,
      requestId: row.request_id,
      itemId: row.item_id,
      user1Id: row.user1_id,
      user2Id: row.user2_id,
      archivedForUserIds: Array.isArray(row.archived_for) ? row.archived_for : [],
      createdAt: new Date(row.created_at).toISOString(),
      lastMessageAt: row.last_message_at ? new Date(row.last_message_at).toISOString() : null,
      messages: messages.rows.map((message) => ({
        id: message.id,
        senderId: message.sender_type === 'system' ? 'system' : message.sender_id,
        text: message.body,
        timestamp: new Date(message.created_at).toISOString(),
        isRead: message.is_read,
      })),
    });
  }
  return threads;
}

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(cors({
    origin(origin, callback) {
      if (!origin || config.corsOrigins.includes(origin)) return callback(null, true);
      return callback(new HttpError(403, 'origin_not_allowed'));
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type'],
  }));
  app.use(express.json({ limit: '2mb' }));
  app.use(express.urlencoded({ extended: false, limit: '20kb' }));

  const limitHandler = (_req, res) => res.status(429).json({ error: 'rate_limit_exceeded' });
  const generalLimiter = rateLimit({ windowMs: 60_000, limit: 240, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const registrationLimiter = rateLimit({ windowMs: 60 * 60_000, limit: 5, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const loginLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 8, standardHeaders: 'draft-8', legacyHeaders: false, skipSuccessfulRequests: true, handler: limitHandler });
  const refreshLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 60, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const actionLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 5, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const deletionLimiter = rateLimit({ windowMs: 60 * 60_000, limit: 3, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  app.use(generalLimiter);

  app.get('/health', asyncRoute(async (_req, res) => {
    await pool.query('SELECT 1');
    const mail = getMailerStatus();
    res.json({
      status: mail === 'ok' ? 'ok' : 'degraded',
      service: 'shareittoo-api',
      checks: { database: 'ok', mail },
      release: releaseMetadata,
      time: new Date().toISOString(),
    });
  }));

  app.get('/health/live', (_req, res) => {
    res.json({ status: 'ok', service: 'shareittoo-api', release: releaseMetadata });
  });

  app.get('/health/ready', asyncRoute(async (_req, res) => {
    await pool.query('SELECT 1');
    const mail = getMailerStatus();
    const ready = mail !== 'error' && mail !== 'unverified';
    res.status(ready ? 200 : 503).json({
      status: ready ? 'ok' : 'degraded',
      service: 'shareittoo-api',
      checks: { database: 'ok', mail },
      release: releaseMetadata,
    });
  }));

  app.get('/version', (_req, res) => {
    res.set('Cache-Control', 'no-store').json(releaseMetadata);
  });

  app.post('/v1/auth/register', registrationLimiter, asyncRoute(async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    const password = req.body?.password;
    const displayName = safeText(req.body?.displayName, 80);
    if (!isValidEmail(email)) throw new HttpError(400, 'invalid_email');
    const policyError = passwordPolicyError(password);
    if (policyError) throw new HttpError(400, policyError);
    if (req.body?.termsAccepted !== true
        || req.body?.privacyAccepted !== true
        || req.body?.minimumAgeConfirmed !== true) {
      throw new HttpError(400, 'registration_consents_required');
    }
    const passwordHash = await hashPassword(password);
    const userId = crypto.randomUUID();
    let verificationUser = null;

    await inTransaction(async (client) => {
      const existing = await client.query('SELECT * FROM users WHERE email = $1', [email]);
      if (existing.rowCount) {
        const user = existing.rows[0];
        if (!user.email_verified_at && !user.deactivated_at && user.account_status === 'active') {
          verificationUser = user;
        }
        return;
      }
      const profile = { ...defaultProfile({ email }), ...(displayName ? { displayName } : {}) };
      const result = await client.query(
        `INSERT INTO users (
           id, email, password_hash, profile,
           terms_accepted_at, privacy_accepted_at, minimum_age_confirmed_at
         ) VALUES ($1, $2, $3, $4::jsonb, now(), now(), now())
         RETURNING *`,
        [userId, email, passwordHash, JSON.stringify(profile)],
      );
      verificationUser = result.rows[0];
      await writeAudit(client, {
        actor: { id: userId, role: 'user' },
        action: 'account.registered',
        resourceType: 'user',
        resourceId: userId,
        metadata: { method: 'email_password' },
      });
    });
    if (verificationUser) {
      try {
        await createAndSendVerification(verificationUser);
      } catch (error) {
        console.error('[auth] registration verification delivery failed', error?.code ?? error?.message ?? error);
      }
    }
    res.status(202).json({ accepted: true });
  }));

  app.post('/v1/auth/login', loginLimiter, asyncRoute(async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    const password = req.body?.password;
    if (!isValidEmail(email) || typeof password !== 'string') throw new HttpError(401, 'invalid_credentials');
    const result = await pool.query(
      `SELECT * FROM users
       WHERE email = $1 AND deactivated_at IS NULL AND account_status = 'active'`,
      [email],
    );
    const user = result.rows[0];
    if (!user?.password_hash) {
      await hashPassword('invalid-login-candidate-12345');
      throw new HttpError(401, 'invalid_credentials');
    }
    const accountLocked = user.login_locked_until
      && new Date(user.login_locked_until).getTime() > Date.now();
    const passwordMatches = await verifyPassword(password, user.password_hash);
    if (accountLocked || !passwordMatches) {
      if (!accountLocked) {
        await pool.query(
          `UPDATE users
           SET failed_login_attempts = LEAST(failed_login_attempts + 1, 1000),
               login_locked_until = CASE
                 WHEN failed_login_attempts + 1 >= $2
                   THEN now() + ($3::int * interval '1 minute')
                 ELSE login_locked_until
               END
           WHERE id = $1`,
          [user.id, config.failedLoginLimit, config.failedLoginLockMinutes],
        );
      }
      throw new HttpError(401, 'invalid_credentials');
    }
    if (!user.email_verified_at) throw new HttpError(403, 'email_verification_required');
    const session = await inTransaction(async (client) => {
      await client.query(
        `UPDATE users
         SET failed_login_attempts = 0, login_locked_until = NULL
         WHERE id = $1`,
        [user.id],
      );
      const issued = await issueSession(client, user, {
        userAgent: req.get('user-agent'),
        ipAddress: requestIp(req),
      });
      await writeAudit(client, {
        actor: { id: user.id, role: user.role ?? 'user' },
        action: 'auth.login',
        resourceType: 'auth_session',
        resourceId: issued.sessionId,
      });
      return issued;
    });
    res.json(session);
  }));

  app.post('/v1/auth/refresh', refreshLimiter, asyncRoute(async (req, res) => {
    const refreshToken = safeText(req.body?.refreshToken, 500);
    if (!refreshToken) throw new HttpError(401, 'invalid_refresh_token');
    const currentHash = hashRefreshToken(refreshToken);
    const outcome = await inTransaction(async (client) => {
      const result = await client.query(
        `SELECT u.id, u.email, u.password_hash, u.profile, u.created_at,
                u.updated_at, u.deactivated_at, u.email_verified_at,
                u.password_changed_at, u.role, u.account_status,
                u.terms_accepted_at, u.privacy_accepted_at,
                u.minimum_age_confirmed_at, u.phone_verified_at,
                rt.id AS refresh_id, rt.user_id AS refresh_user_id,
                rt.expires_at AS refresh_expires_at, rt.revoked_at AS refresh_revoked_at,
                rt.replaced_by_hash, rt.session_id, rt.family_id,
                session.revoked_at AS session_revoked_at
         FROM refresh_tokens AS rt
         JOIN users AS u ON u.id = rt.user_id
         JOIN auth_sessions AS session ON session.id = rt.session_id
         WHERE rt.token_hash = $1 FOR UPDATE`,
        [currentHash],
      );
      const row = result.rows[0];
      if (!row) return { invalid: true };
      if (row.refresh_revoked_at && row.replaced_by_hash) {
        await client.query(
          `UPDATE auth_sessions
           SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = 'refresh_token_reuse'
           WHERE id = $1`,
          [row.session_id],
        );
        await client.query(
          `UPDATE refresh_tokens
           SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'refresh_token_reuse')
           WHERE session_id = $1`,
          [row.session_id],
        );
        await writeAudit(client, {
          actor: { id: row.id, role: row.role ?? 'user' },
          action: 'auth.refresh_reuse_detected',
          resourceType: 'auth_session',
          resourceId: row.session_id,
        });
        return { reuseDetected: true };
      }
      if (row.refresh_revoked_at || row.session_revoked_at
          || new Date(row.refresh_expires_at) <= new Date()
          || row.deactivated_at || row.account_status !== 'active') {
        return { invalid: true };
      }
      const next = await issueSession(client, row, {
        userAgent: req.get('user-agent'),
        ipAddress: requestIp(req),
        sessionId: row.session_id,
        familyId: row.family_id,
      });
      await client.query(
        `UPDATE refresh_tokens
         SET used_at = now(), revoked_at = now(), revoked_reason = 'rotated', replaced_by_hash = $2
         WHERE token_hash = $1`,
        [currentHash, hashRefreshToken(next.refreshToken)],
      );
      return { session: next };
    });
    if (outcome.reuseDetected) throw new HttpError(401, 'refresh_token_reuse_detected');
    if (outcome.invalid || !outcome.session) throw new HttpError(401, 'invalid_refresh_token');
    res.json(outcome.session);
  }));

  app.post('/v1/auth/logout', asyncRoute(async (req, res) => {
    const refreshToken = safeText(req.body?.refreshToken, 500);
    if (refreshToken) {
      await inTransaction(async (client) => {
        const found = await client.query(
          `SELECT user_id, session_id FROM refresh_tokens WHERE token_hash = $1 FOR UPDATE`,
          [hashRefreshToken(refreshToken)],
        );
        const row = found.rows[0];
        if (!row) return;
        await client.query(
          `UPDATE auth_sessions
           SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'logout')
           WHERE id = $1`,
          [row.session_id],
        );
        await client.query(
          `UPDATE refresh_tokens
           SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'logout')
           WHERE session_id = $1`,
          [row.session_id],
        );
      });
    }
    res.status(204).end();
  }));

  app.post('/v1/auth/email-verification/request', actionLimiter, asyncRoute(async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    const result = await pool.query(
      `SELECT * FROM users
       WHERE email = $1 AND deactivated_at IS NULL AND account_status = 'active'`,
      [email],
    );
    const user = result.rows[0];
    if (user && !user.email_verified_at) {
      try {
        await createAndSendVerification(user);
      } catch (error) {
        console.error('[auth] verification delivery failed', error?.code ?? error?.message ?? error);
      }
    }
    return res.status(202).json({ accepted: true });
  }));

  const confirmEmail = async (token) => inTransaction(async (client) => {
    const row = await lockValidActionToken(client, { token, kind: 'verify_email' });
    if (!row) throw new HttpError(400, 'invalid_or_expired_verification_link');
    await client.query(
      `UPDATE users
       SET email_verified_at = COALESCE(email_verified_at, now()),
           profile = jsonb_set(profile, '{emailVerified}', 'true'::jsonb)
       WHERE id = $1`,
      [row.id],
    );
    await consumeActionToken(client, row.action_token_id);
    return row;
  });

  app.get('/v1/auth/email-verification/confirm', actionLimiter, asyncRoute(async (req, res) => {
    try {
      await confirmEmail(safeText(req.query?.token, 500));
      sendHtml(res, 200, resultPage({
        success: true,
        title: 'E-Mail bestätigt',
        message: 'Deine E-Mail-Adresse wurde erfolgreich bestätigt. Du kannst zu ShareItToo zurückkehren.',
      }));
    } catch (error) {
      if (!(error instanceof HttpError)) throw error;
      sendHtml(res, 400, resultPage({
        success: false,
        title: 'Link nicht mehr gültig',
        message: 'Dieser Bestätigungslink ist ungültig, abgelaufen oder wurde bereits verwendet. Fordere in der App einen neuen Link an.',
      }));
    }
  }));

  app.post('/v1/auth/email-verification/confirm', actionLimiter, asyncRoute(async (req, res) => {
    await confirmEmail(safeText(req.body?.token, 500));
    res.json({ verified: true });
  }));

  app.post('/v1/auth/email-change/request', requireAuth, requireActiveAccount, actionLimiter, asyncRoute(async (req, res) => {
    const nextEmail = normalizeEmail(req.body?.newEmail);
    const currentPassword = req.body?.currentPassword;
    if (!isValidEmail(nextEmail)) throw new HttpError(400, 'invalid_email');
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [req.auth.userId]);
    const user = result.rows[0];
    if (!user?.password_hash || !(await verifyPassword(currentPassword, user.password_hash))) {
      throw new HttpError(401, 'invalid_credentials');
    }
    if (nextEmail === user.email) throw new HttpError(400, 'email_unchanged');

    const token = await inTransaction(async (client) => {
      const conflict = await client.query(
        'SELECT 1 FROM users WHERE email = $1 AND id <> $2',
        [nextEmail, user.id],
      );
      if (conflict.rowCount) throw new HttpError(409, 'email_in_use');
      const actionToken = await createActionToken(client, {
        userId: user.id,
        kind: 'change_email',
        payload: { newEmail: nextEmail },
      });
      await writeAudit(client, {
        actor: req.actor,
        action: 'auth.email_change_requested',
        resourceType: 'user',
        resourceId: user.id,
        metadata: {
          newEmailHash: crypto.createHash('sha256').update(nextEmail).digest('hex'),
        },
      });
      return actionToken;
    });

    await sendEmailChangeVerification({
      email: nextEmail,
      displayName: user.profile?.displayName,
      token,
    });
    try {
      await sendEmailChangeAlert({
        email: user.email,
        displayName: user.profile?.displayName,
      });
    } catch (error) {
      console.error('[auth] old-address email change alert failed', error?.code ?? error?.message ?? error);
    }
    res.status(202).json({ accepted: true });
  }));

  const confirmEmailChange = async (token) => inTransaction(async (client) => {
    const row = await lockValidActionToken(client, { token, kind: 'change_email' });
    const nextEmail = normalizeEmail(row?.action_payload?.newEmail);
    if (!row || !isValidEmail(nextEmail)) throw new HttpError(400, 'invalid_or_expired_email_change_link');
    const conflict = await client.query(
      'SELECT 1 FROM users WHERE email = $1 AND id <> $2',
      [nextEmail, row.id],
    );
    if (conflict.rowCount) throw new HttpError(409, 'email_in_use');
    await client.query(
      `UPDATE users
       SET email = $2,
           email_verified_at = now(),
           profile = jsonb_set(profile - 'email', '{emailVerified}', 'true'::jsonb, true),
           failed_login_attempts = 0,
           login_locked_until = NULL
       WHERE id = $1`,
      [row.id, nextEmail],
    );
    await consumeActionToken(client, row.action_token_id);
    await client.query(
      `UPDATE auth_action_tokens
       SET consumed_at = COALESCE(consumed_at, now())
       WHERE user_id = $1 AND kind = 'change_email'`,
      [row.id],
    );
    await client.query('DELETE FROM push_devices WHERE user_id = $1', [row.id]);
    await client.query(
      `UPDATE auth_sessions
       SET revoked_at = COALESCE(revoked_at, now()),
           revoked_reason = COALESCE(revoked_reason, 'email_changed')
       WHERE user_id = $1`,
      [row.id],
    );
    await client.query(
      `UPDATE refresh_tokens
       SET revoked_at = COALESCE(revoked_at, now()),
           revoked_reason = COALESCE(revoked_reason, 'email_changed')
       WHERE user_id = $1`,
      [row.id],
    );
    await writeAudit(client, {
      actor: { id: row.id, role: row.role ?? 'user' },
      action: 'auth.email_changed',
      resourceType: 'user',
      resourceId: row.id,
      metadata: {
        newEmailHash: crypto.createHash('sha256').update(nextEmail).digest('hex'),
      },
    });
    return { changed: true };
  });

  app.get('/v1/auth/email-change/confirm', actionLimiter, asyncRoute(async (req, res) => {
    try {
      await confirmEmailChange(safeText(req.query?.token, 500));
      return sendHtml(res, 200, resultPage({
        success: true,
        title: 'E-Mail-Adresse geändert',
        message: 'Deine neue E-Mail-Adresse ist bestätigt. Alle bisherigen Sitzungen wurden beendet. Melde dich jetzt erneut an.',
      }));
    } catch (error) {
      if (!(error instanceof HttpError)) throw error;
      return sendHtml(res, error.status, resultPage({
        success: false,
        title: 'E-Mail-Adresse nicht geändert',
        message: error.code === 'email_in_use'
          ? 'Diese E-Mail-Adresse wird bereits verwendet. Starte die Änderung in der App erneut.'
          : 'Dieser Link ist ungültig, abgelaufen oder wurde bereits verwendet.',
      }));
    }
  }));

  app.post('/v1/auth/email-change/confirm', actionLimiter, asyncRoute(async (req, res) => {
    res.json(await confirmEmailChange(safeText(req.body?.token, 500)));
  }));

  app.post('/v1/auth/password-reset/request', actionLimiter, asyncRoute(async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    if (isValidEmail(email)) {
      const result = await pool.query(
        `SELECT * FROM users
         WHERE email = $1 AND deactivated_at IS NULL AND account_status = 'active'`,
        [email],
      );
      const user = result.rows[0];
      if (user?.password_hash) {
        try {
          const token = await inTransaction((client) => createActionToken(client, {
            userId: user.id,
            kind: 'reset_password',
          }));
          await sendPasswordResetEmail({
            email: user.email,
            displayName: user.profile?.displayName,
            token,
          });
        } catch (error) {
          console.error('[auth] password reset delivery failed', error?.code ?? error?.message ?? error);
        }
      }
    }
    res.status(202).json({ accepted: true });
  }));

  app.get('/v1/auth/password-reset/form', actionLimiter, asyncRoute(async (req, res) => {
    const token = safeText(req.query?.token, 500);
    const valid = await inTransaction(async (client) => Boolean(
      await lockValidActionToken(client, { token, kind: 'reset_password' }),
    ));
    if (!valid) {
      return sendHtml(res, 400, resultPage({
        success: false,
        title: 'Link nicht mehr gültig',
        message: 'Dieser Link ist ungültig, abgelaufen oder wurde bereits verwendet. Fordere in der App einen neuen Link an.',
      }));
    }
    return sendHtml(res, 200, passwordResetForm({ token }));
  }));

  app.post('/v1/auth/password-reset/form', actionLimiter, asyncRoute(async (req, res) => {
    const token = safeText(req.body?.token, 500);
    const password = req.body?.password;
    const passwordConfirm = req.body?.passwordConfirm;
    if (password !== passwordConfirm || !isValidPassword(password)) {
      return sendHtml(res, 400, passwordResetForm({
        token,
        error: password !== passwordConfirm
          ? 'Die Passwörter stimmen nicht überein.'
          : 'Das Passwort muss mindestens zehn Zeichen, einen Buchstaben und eine Zahl enthalten.',
      }));
    }
    try {
      await resetPasswordWithToken(token, password);
      return sendHtml(res, 200, resultPage({
        success: true,
        title: 'Passwort geändert',
        message: 'Dein Passwort wurde sicher geändert. Melde dich jetzt mit dem neuen Passwort an.',
      }));
    } catch (error) {
      if (!(error instanceof HttpError)) throw error;
      return sendHtml(res, 400, resultPage({
        success: false,
        title: 'Link nicht mehr gültig',
        message: 'Dieser Link ist ungültig, abgelaufen oder wurde bereits verwendet.',
      }));
    }
  }));

  app.post('/v1/auth/password-reset/confirm', actionLimiter, asyncRoute(async (req, res) => {
    await resetPasswordWithToken(safeText(req.body?.token, 500), req.body?.password);
    res.json({ changed: true });
  }));

  app.get('/v1/auth/me', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await pool.query('SELECT * FROM users WHERE id = $1 AND deactivated_at IS NULL', [req.auth.userId]);
    if (!result.rowCount) throw new HttpError(404, 'user_not_found');
    res.json({ user: shapeUser(result.rows[0]) });
  }));

  app.get('/v1/auth/sessions', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await pool.query(
      `SELECT id, device_label, created_at, last_seen_at
       FROM auth_sessions
       WHERE user_id = $1 AND revoked_at IS NULL
       ORDER BY last_seen_at DESC`,
      [req.auth.userId],
    );
    res.json({
      sessions: result.rows.map((session) => ({
        id: session.id,
        name: session.device_label,
        location: session.id === req.auth.sessionId ? 'Aktuelle Sitzung' : 'Letzte bekannte Sitzung',
        createdAt: new Date(session.created_at).toISOString(),
        lastActive: new Date(session.last_seen_at).toISOString(),
        isThisDevice: session.id === req.auth.sessionId,
      })),
    });
  }));

  app.delete('/v1/auth/sessions/:id', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const sessionId = safeText(req.params.id, 80);
    await inTransaction(async (client) => {
      const result = await client.query(
        `UPDATE auth_sessions
         SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'user_revoked')
         WHERE id::text = $1 AND user_id = $2 AND revoked_at IS NULL
         RETURNING id`,
        [sessionId, req.auth.userId],
      );
      if (!result.rowCount) throw new HttpError(404, 'session_not_found');
      await client.query(
        `UPDATE refresh_tokens
         SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'user_revoked')
         WHERE session_id = $1`,
        [sessionId],
      );
      await client.query('DELETE FROM push_devices WHERE session_id = $1', [sessionId]);
      await writeAudit(client, {
        actor: req.actor,
        action: 'auth.session_revoked',
        resourceType: 'auth_session',
        resourceId: sessionId,
      });
    });
    res.status(204).end();
  }));

  app.post('/v1/auth/logout-all', requireAuth, requireActiveAccount, actionLimiter, asyncRoute(async (req, res) => {
    await inTransaction(async (client) => {
      await client.query(
        `UPDATE auth_sessions
         SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'logout_all')
         WHERE user_id = $1`,
        [req.auth.userId],
      );
      await client.query(
        `UPDATE refresh_tokens
         SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'logout_all')
         WHERE user_id = $1`,
        [req.auth.userId],
      );
      await client.query('DELETE FROM push_devices WHERE user_id = $1', [req.auth.userId]);
      await writeAudit(client, {
        actor: req.actor,
        action: 'auth.logout_all',
        resourceType: 'user',
        resourceId: req.auth.userId,
      });
    });
    res.status(204).end();
  }));

  app.post('/v1/auth/password/change', requireAuth, requireActiveAccount, actionLimiter, asyncRoute(async (req, res) => {
    const currentPassword = req.body?.currentPassword;
    const nextPassword = req.body?.newPassword;
    const policyError = passwordPolicyError(nextPassword);
    if (policyError) throw new HttpError(400, policyError);
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [req.auth.userId]);
    const user = result.rows[0];
    if (!user?.password_hash || !(await verifyPassword(currentPassword, user.password_hash))) {
      throw new HttpError(401, 'invalid_credentials');
    }
    const passwordHash = await hashPassword(nextPassword);
    await inTransaction(async (client) => {
      await client.query(
        `UPDATE users
         SET password_hash = $2, password_changed_at = now(),
             failed_login_attempts = 0, login_locked_until = NULL
         WHERE id = $1`,
        [req.auth.userId, passwordHash],
      );
      await client.query(
        `UPDATE auth_sessions
         SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'password_changed')
         WHERE user_id = $1`,
        [req.auth.userId],
      );
      await client.query(
        `UPDATE refresh_tokens
         SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'password_changed')
         WHERE user_id = $1`,
        [req.auth.userId],
      );
      await writeAudit(client, {
        actor: req.actor,
        action: 'auth.password_changed',
        resourceType: 'user',
        resourceId: req.auth.userId,
      });
    });
    res.status(204).end();
  }));

  app.put('/v1/auth/devices/push', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const token = safeText(req.body?.token, 4096);
    const platform = safeText(req.body?.platform, 20).toLowerCase();
    const locale = safeText(req.body?.locale, 20) || null;
    if (!token || !['ios', 'android', 'web'].includes(platform)) {
      throw new HttpError(400, 'invalid_push_device');
    }
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    const result = await pool.query(
      `INSERT INTO push_devices (
         user_id, session_id, platform, token, token_hash, locale
       ) VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (token_hash) DO UPDATE
       SET user_id = EXCLUDED.user_id,
           session_id = EXCLUDED.session_id,
           platform = EXCLUDED.platform,
           token = EXCLUDED.token,
           locale = EXCLUDED.locale,
           enabled = true,
           last_seen_at = now()
       RETURNING id, platform, locale, enabled, last_seen_at`,
      [req.auth.userId, req.auth.sessionId, platform, token, tokenHash, locale],
    );
    res.json({ device: result.rows[0] });
  }));

  app.delete('/v1/auth/devices/push/:id', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await pool.query(
      `DELETE FROM push_devices WHERE id::text = $1 AND user_id = $2 RETURNING id`,
      [safeText(req.params.id, 80), req.auth.userId],
    );
    if (!result.rowCount) throw new HttpError(404, 'push_device_not_found');
    res.status(204).end();
  }));

  app.get('/v1/account/deletion-preflight', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    res.json(await accountDeletionPreflight(pool, req.auth.userId));
  }));

  app.post('/v1/account/deletion', requireAuth, requireActiveAccount, actionLimiter, asyncRoute(async (req, res) => {
    const currentPassword = req.body?.currentPassword;
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [req.auth.userId]);
    const user = result.rows[0];
    if (!user?.password_hash || !(await verifyPassword(currentPassword, user.password_hash))) {
      throw new HttpError(401, 'invalid_credentials');
    }
    const outcome = await inTransaction((client) => eraseAccount(client, user, {
      actorRole: req.actor.role,
      source: 'app',
    }));
    await removeErasedUploadFiles(outcome.erasedUploadStorageNames);
    res.json({ deleted: true });
  }));

  app.get('/v1/account-deletion', deletionLimiter, (_req, res) => {
    sendHtml(res, 200, accountDeletionRequestForm({ submitted: false }));
  });

  app.post('/v1/account-deletion/request', deletionLimiter, asyncRoute(async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    const result = await pool.query(
      `SELECT * FROM users
       WHERE email = $1 AND account_status = 'active' AND deactivated_at IS NULL`,
      [email],
    );
    const user = result.rows[0];
    if (user) {
      try {
        const token = await inTransaction((client) => createActionToken(client, {
          userId: user.id,
          kind: 'delete_account',
        }));
        await sendAccountDeletionEmail({
          email: user.email,
          displayName: user.profile?.displayName,
          token,
        });
      } catch (error) {
        console.error('[account] deletion link delivery failed', error?.code ?? error?.message ?? error);
      }
    }
    sendHtml(res, 202, accountDeletionRequestForm({ submitted: true }));
  }));

  app.get('/v1/account-deletion/confirm', deletionLimiter, asyncRoute(async (req, res) => {
    const token = safeText(req.query?.token, 500);
    const valid = await inTransaction(async (client) => Boolean(
      await lockValidActionToken(client, { token, kind: 'delete_account' }),
    ));
    if (!valid) {
      return sendHtml(res, 400, resultPage({
        success: false,
        title: 'Link nicht mehr gültig',
        message: 'Dieser Löschlink ist ungültig, abgelaufen oder wurde bereits verwendet.',
      }));
    }
    return sendHtml(res, 200, accountDeletionConfirmForm({ token }));
  }));

  app.post('/v1/account-deletion/confirm', deletionLimiter, asyncRoute(async (req, res) => {
    const token = safeText(req.body?.token, 500);
    try {
      const outcome = await inTransaction(async (client) => {
        const user = await lockValidActionToken(client, { token, kind: 'delete_account' });
        if (!user) throw new HttpError(400, 'invalid_or_expired_deletion_link');
        return eraseAccount(client, user, { actorRole: user.role ?? 'user', source: 'web' });
      });
      await removeErasedUploadFiles(outcome.erasedUploadStorageNames);
      return sendHtml(res, 200, resultPage({
        success: true,
        title: 'Konto gelöscht',
        message: 'Dein ShareItToo-Konto wurde geschlossen und deine personenbezogenen Daten wurden gelöscht oder anonymisiert.',
      }));
    } catch (error) {
      if (error instanceof HttpError && error.code === 'account_deletion_blocked') {
        return sendHtml(res, 409, accountDeletionConfirmForm({
          token,
          error: 'Die Löschung ist aktuell wegen einer offenen Buchung, Zahlung, Auszahlung oder eines Streitfalls blockiert. Bitte kläre den Vorgang zuerst in der App oder mit dem Support.',
        }));
      }
      if (!(error instanceof HttpError)) throw error;
      return sendHtml(res, 400, resultPage({
        success: false,
        title: 'Link nicht mehr gültig',
        message: 'Dieser Löschlink ist ungültig, abgelaufen oder wurde bereits verwendet.',
      }));
    }
  }));

  app.patch('/v1/profile', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const update = sanitizeProfileUpdate(req.body?.profile ?? req.body);
    if (!isValidBirthDate(update.birthDate)) throw new HttpError(400, 'minimum_age_required');
    const updatesPhone = Object.hasOwn(update, 'phone');
    const normalizedPhone = updatesPhone ? normalizePhoneE164(update.phone) : null;
    if (normalizedPhone === undefined) throw new HttpError(400, 'invalid_phone');
    if (updatesPhone) update.phone = normalizedPhone;
    const result = await pool.query(
      `UPDATE users
       SET profile = profile || $2::jsonb,
           phone_e164 = CASE WHEN $3::boolean THEN $4 ELSE phone_e164 END,
           phone_verified_at = CASE
             WHEN $3::boolean AND phone_e164 IS DISTINCT FROM $4 THEN NULL
             ELSE phone_verified_at
           END
       WHERE id = $1 AND deactivated_at IS NULL
       RETURNING *`,
      [req.auth.userId, JSON.stringify(update), updatesPhone, normalizedPhone],
    );
    if (!result.rowCount) throw new HttpError(404, 'user_not_found');
    publishToUsers([req.auth.userId], { type: 'changed', resource: 'profiles' });
    res.json({ user: shapeUser(result.rows[0]) });
  }));

  app.get('/v1/profiles/:id', asyncRoute(async (req, res) => {
    const result = await pool.query('SELECT * FROM users WHERE id = $1 AND deactivated_at IS NULL', [safeText(req.params.id, 120)]);
    if (!result.rowCount) throw new HttpError(404, 'user_not_found');
    res.json({ user: shapeUser(result.rows[0], { publicOnly: true }) });
  }));

  app.get('/v1/listings', asyncRoute(async (_req, res) => {
    const result = await pool.query(
      `SELECT payload FROM listings WHERE is_active = true ORDER BY created_at DESC LIMIT 500`,
    );
    res.json({ listings: result.rows.map((row) => row.payload) });
  }));

  app.get('/v1/listings/mine', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await pool.query(
      `SELECT payload FROM listings WHERE owner_id = $1 ORDER BY created_at DESC LIMIT 500`,
      [req.auth.userId],
    );
    res.json({ listings: result.rows.map((row) => row.payload) });
  }));

  app.post('/v1/listings', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const id = identifier(req.body?.id === 'new' ? '' : req.body?.id, 'listing');
    const payload = listingPayload(req.body, { id, ownerId: req.auth.userId });
    const financials = listingFinancials(payload);
    const result = await inTransaction(async (client) => {
      const inserted = await client.query(
        `INSERT INTO listings (
           id, owner_id, payload, is_active, currency, price_per_day_minor,
           security_deposit_minor, created_at
         )
         VALUES ($1, $2, $3::jsonb, $4, $5, $6, $7, $8::timestamptz)
         RETURNING payload`,
        [
          id,
          req.auth.userId,
          JSON.stringify(payload),
          payload.isActive,
          financials.currency,
          financials.pricePerDayMinor,
          financials.securityDepositMinor,
          payload.createdAt,
        ],
      );
      await writeAudit(client, {
        actor: req.actor,
        action: 'listing.created',
        resourceType: 'listing',
        resourceId: id,
      });
      return inserted;
    });
    publishToAll({ type: 'changed', resource: 'listings' });
    res.status(201).json({ listing: result.rows[0].payload });
  }));

  app.put('/v1/listings/:id', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const id = safeText(req.params.id, 120);
    const existing = await pool.query('SELECT * FROM listings WHERE id = $1', [id]);
    if (!existing.rowCount) throw new HttpError(404, 'listing_not_found');
    if (existing.rows[0].owner_id !== req.auth.userId) throw new HttpError(403, 'listing_forbidden');
    const payload = listingPayload(req.body, {
      id,
      ownerId: req.auth.userId,
      existingCreatedAt: new Date(existing.rows[0].created_at).toISOString(),
    });
    const financials = listingFinancials(payload);
    const result = await inTransaction(async (client) => {
      const updated = await client.query(
        `UPDATE listings
         SET payload = $2::jsonb, is_active = $3, currency = $4,
             price_per_day_minor = $5, security_deposit_minor = $6
         WHERE id = $1
         RETURNING payload`,
        [
          id,
          JSON.stringify(payload),
          payload.isActive,
          financials.currency,
          financials.pricePerDayMinor,
          financials.securityDepositMinor,
        ],
      );
      await writeAudit(client, {
        actor: req.actor,
        action: 'listing.updated',
        resourceType: 'listing',
        resourceId: id,
      });
      return updated;
    });
    publishToAll({ type: 'changed', resource: 'listings' });
    res.json({ listing: result.rows[0].payload });
  }));

  app.patch('/v1/listings/:id/status', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const id = safeText(req.params.id, 120);
    const status = safeText(req.body?.status, 30);
    if (!['active', 'paused', 'ended'].includes(status)) throw new HttpError(400, 'invalid_listing_status');
    const isActive = status === 'active';
    const result = await pool.query(
      `UPDATE listings
       SET is_active = $3,
           payload = jsonb_set(jsonb_set(payload, '{isActive}', to_jsonb($3::boolean)), '{status}', to_jsonb($4::text))
       WHERE id = $1 AND owner_id = $2
       RETURNING payload`,
      [id, req.auth.userId, isActive, status],
    );
    if (!result.rowCount) throw new HttpError(404, 'listing_not_found');
    publishToAll({ type: 'changed', resource: 'listings' });
    res.json({ listing: result.rows[0].payload });
  }));

  app.delete('/v1/listings/:id', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await pool.query(
      `UPDATE listings
       SET is_active = false,
           payload = jsonb_set(jsonb_set(payload, '{isActive}', 'false'::jsonb), '{status}', '"ended"'::jsonb)
       WHERE id = $1 AND owner_id = $2 AND is_active = true
       RETURNING id`,
      [safeText(req.params.id, 120), req.auth.userId],
    );
    if (!result.rowCount) throw new HttpError(404, 'listing_not_found');
    publishToAll({ type: 'changed', resource: 'listings' });
    res.status(204).end();
  }));

  app.get('/v1/rental-requests', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    res.json({ requests: await listRentalRequests(pool, req.auth.userId) });
  }));

  app.put('/v1/rental-requests/sync', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    if (!Array.isArray(req.body?.requests) || req.body.requests.length > 500) throw new HttpError(400, 'invalid_requests');
    const participants = new Set([req.auth.userId]);
    const requests = await inTransaction(async (client) => {
      for (const raw of req.body.requests) {
        const candidate = ensureObject(raw, 'invalid_request');
        const id = identifier(candidate.id, 'request');
        const existingResult = await client.query(
          `SELECT request.*, booking.status AS booking_status
           FROM rental_requests AS request
           LEFT JOIN bookings AS booking ON booking.id = request.id
           WHERE request.id = $1
           FOR UPDATE OF request`,
          [id],
        );
        if (!existingResult.rowCount) {
          const itemId = safeText(candidate.itemId, 120);
          const listingResult = await client.query(
            `SELECT owner_id, currency, security_deposit_minor
             FROM listings WHERE id = $1 AND is_active = true`,
            [itemId],
          );
          if (!listingResult.rowCount) throw new HttpError(404, 'listing_not_found', { itemId });
          const ownerId = listingResult.rows[0].owner_id;
          if (ownerId === req.auth.userId) throw new HttpError(409, 'cannot_rent_own_listing');
          const payload = rentalPayload(
            { ...candidate, status: 'pending', createdAt: new Date().toISOString() },
            { id, itemId, ownerId, renterId: req.auth.userId },
          );
          await client.query(
            `INSERT INTO rental_requests (id, item_id, owner_id, renter_id, status, payload, created_at)
             VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::timestamptz)`,
            [id, itemId, ownerId, req.auth.userId, payload.status, JSON.stringify(payload), payload.createdAt],
          );
          await client.query(
            `INSERT INTO bookings (
               id, listing_id, owner_id, renter_id, status, starts_at, ends_at,
               currency, quoted_total_minor, security_deposit_minor, created_at
             )
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
            [
              id,
              itemId,
              ownerId,
              req.auth.userId,
              payload.status,
              payload.start,
              payload.end,
              normalizeCurrency(listingResult.rows[0].currency),
              amountToMinor(payload.quotedTotalRenter),
              listingResult.rows[0].security_deposit_minor,
              payload.createdAt,
            ],
          );
          await client.query(
            `INSERT INTO booking_events (
               booking_id, actor_id, event_type, to_status, metadata
             ) VALUES ($1, $2, 'booking.created', $3, '{}'::jsonb)`,
            [id, req.auth.userId, payload.status],
          );
          await writeAudit(client, {
            actor: req.actor,
            action: 'booking.created',
            resourceType: 'booking',
            resourceId: id,
            metadata: { listingId: itemId },
          });
          participants.add(ownerId);
          continue;
        }

        const existing = existingResult.rows[0];
        if (existing.owner_id !== req.auth.userId && existing.renter_id !== req.auth.userId) {
          throw new HttpError(403, 'request_forbidden');
        }
        const payload = existingRentalPayload(candidate, existing, req.auth.userId);
        if (existing.booking_status === null) {
          throw new HttpError(500, 'booking_projection_missing');
        }
        if (!canTransitionBooking({ current: existing.status, next: payload.status, actorId: req.auth.userId, ownerId: existing.owner_id, renterId: existing.renter_id })) {
          throw new HttpError(409, 'invalid_status_transition', { current: existing.status, next: payload.status });
        }
        await client.query(
          `UPDATE rental_requests SET status = $2, payload = $3::jsonb WHERE id = $1`,
          [id, payload.status, JSON.stringify(payload)],
        );
        await client.query(
          `UPDATE bookings
           SET status = $2, starts_at = $3, ends_at = $4,
               quoted_total_minor = $5, version = version + 1
           WHERE id = $1`,
          [id, payload.status, payload.start, payload.end, amountToMinor(payload.quotedTotalRenter)],
        );
        await client.query(
          `INSERT INTO booking_events (
             booking_id, actor_id, event_type, from_status, to_status, metadata
           ) VALUES ($1, $2, $3, $4, $5, '{}'::jsonb)`,
          [
            id,
            req.auth.userId,
            existing.status === payload.status ? 'booking.updated' : 'booking.status_changed',
            existing.status,
            payload.status,
          ],
        );
        await writeAudit(client, {
          actor: req.actor,
          action: existing.status === payload.status ? 'booking.updated' : 'booking.status_changed',
          resourceType: 'booking',
          resourceId: id,
          metadata: { fromStatus: existing.status, toStatus: payload.status },
        });
        participants.add(existing.owner_id);
        participants.add(existing.renter_id);
      }
      return listRentalRequests(client, req.auth.userId);
    }, { deadlockRetries: 2 });
    publishToUsers([...participants], { type: 'changed', resource: 'rental_requests' });
    res.json({ requests });
  }));

  app.get('/v1/message-threads', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    res.json({ threads: await listThreads(pool, req.auth.userId) });
  }));

  app.put('/v1/message-threads/sync', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    if (!Array.isArray(req.body?.threads) || req.body.threads.length > 500) throw new HttpError(400, 'invalid_threads');
    const affectedUsers = new Set([req.auth.userId]);
    const threads = await inTransaction(async (client) => {
      for (const raw of req.body.threads) {
        const candidate = ensureObject(raw, 'invalid_thread');
        const requestId = safeText(candidate.requestId, 120);
        const requestResult = await client.query('SELECT * FROM rental_requests WHERE id = $1', [requestId]);
        if (!requestResult.rowCount) continue;
        const request = requestResult.rows[0];
        if (request.owner_id !== req.auth.userId && request.renter_id !== req.auth.userId) throw new HttpError(403, 'thread_forbidden');
        if (!['accepted', 'running', 'completed'].includes(request.status)) continue;

        const proposedId = identifier(candidate.id, 'thread');
        const existingResult = await client.query('SELECT * FROM message_threads WHERE request_id = $1 FOR UPDATE', [requestId]);
        const isNew = !existingResult.rowCount;
        const threadId = isNew ? proposedId : existingResult.rows[0].id;
        const createdAt = isNew ? new Date() : new Date(existingResult.rows[0].created_at);
        const payload = threadPayload(candidate, {
          id: threadId,
          requestId,
          itemId: request.item_id,
          user1Id: request.renter_id,
          user2Id: request.owner_id,
          createdAt,
        });
        const previousArchived = isNew
          ? []
          : (Array.isArray(existingResult.rows[0].archived_for) ? existingResult.rows[0].archived_for : []);
        const requestedArchived = Array.isArray(candidate.archivedForUserIds) ? candidate.archivedForUserIds.map(String) : [];
        const archived = new Set(previousArchived);
        if (requestedArchived.includes(req.auth.userId)) archived.add(req.auth.userId);
        else archived.delete(req.auth.userId);
        const lastMessageAt = Date.parse(candidate.lastMessageAt) ? new Date(candidate.lastMessageAt) : null;

        if (isNew) {
          await client.query(
            `INSERT INTO message_threads (id, request_id, item_id, user1_id, user2_id, payload, archived_for, created_at, last_message_at)
             VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8, $9)`,
            [threadId, requestId, request.item_id, request.renter_id, request.owner_id, JSON.stringify(payload), JSON.stringify([...archived]), createdAt, lastMessageAt],
          );
        } else {
          await client.query(
            `UPDATE message_threads SET payload = $2::jsonb, archived_for = $3::jsonb,
                    last_message_at = COALESCE($4, last_message_at)
             WHERE id = $1`,
            [threadId, JSON.stringify(payload), JSON.stringify([...archived]), lastMessageAt],
          );
        }

        const messages = Array.isArray(candidate.messages) ? candidate.messages.slice(0, 2000) : [];
        for (const messageRaw of messages) {
          const message = ensureObject(messageRaw, 'invalid_message');
          const messageId = identifier(message.id, 'message');
          const existingMessage = await client.query('SELECT sender_id, sender_type FROM messages WHERE id = $1', [messageId]);
          if (existingMessage.rowCount) {
            await client.query('UPDATE messages SET is_read = $2 WHERE id = $1 AND thread_id = $3', [messageId, message.isRead === true, threadId]);
            continue;
          }
          const senderIsSystem = message.senderId === 'system';
          if ((!senderIsSystem && message.senderId !== req.auth.userId) || (senderIsSystem && !isNew)) {
            throw new HttpError(403, 'message_sender_forbidden');
          }
          const body = safeText(message.text, 4000);
          if (!body) continue;
          const timestamp = Date.parse(message.timestamp) ? new Date(message.timestamp) : new Date();
          await client.query(
            `INSERT INTO messages (id, thread_id, sender_id, sender_type, body, is_read, created_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [messageId, threadId, senderIsSystem ? null : req.auth.userId, senderIsSystem ? 'system' : 'user', body, message.isRead === true, timestamp],
          );
        }
        affectedUsers.add(request.owner_id);
        affectedUsers.add(request.renter_id);
      }
      return listThreads(client, req.auth.userId);
    });
    publishToUsers([...affectedUsers], { type: 'changed', resource: 'message_threads' });
    res.json({ threads });
  }));

  const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 8 * 1024 * 1024, files: 1 } });
  app.post('/v1/uploads', requireAuth, requireActiveAccount, upload.single('file'), asyncRoute(async (req, res) => {
    if (!req.file?.buffer) throw new HttpError(400, 'file_required');
    const detected = await fileTypeFromBuffer(req.file.buffer);
    const allowed = new Set(['image/jpeg', 'image/png', 'image/webp']);
    if (!detected || !allowed.has(detected.mime)) throw new HttpError(415, 'unsupported_image_type');
    const allowedPurposes = new Set([
      'listing_image',
      'profile_image',
      'message_attachment',
      'handover_evidence',
      'return_evidence',
    ]);
    const purpose = safeText(req.body?.purpose, 40) || 'listing_image';
    if (!allowedPurposes.has(purpose)) throw new HttpError(400, 'invalid_upload_purpose');
    const listingId = safeText(req.body?.listingId, 120) || null;
    const threadId = safeText(req.body?.threadId, 120) || null;
    const visibility = ['listing_image', 'profile_image'].includes(purpose) ? 'public' : 'private';

    if (listingId) {
      const listing = await pool.query(
        'SELECT owner_id FROM listings WHERE id = $1',
        [listingId],
      );
      if (!listing.rowCount) throw new HttpError(404, 'listing_not_found');
      if (listing.rows[0].owner_id !== req.auth.userId) throw new HttpError(403, 'upload_forbidden');
    }
    if (visibility === 'private') {
      if (!threadId) throw new HttpError(400, 'private_upload_thread_required');
      const thread = await pool.query(
        `SELECT user1_id, user2_id FROM message_threads WHERE id = $1`,
        [threadId],
      );
      if (!thread.rowCount) throw new HttpError(404, 'thread_not_found');
      if (![thread.rows[0].user1_id, thread.rows[0].user2_id].includes(req.auth.userId)) {
        throw new HttpError(403, 'upload_forbidden');
      }
    }

    const storageName = `${crypto.randomUUID()}.${detected.ext}`;
    await fs.mkdir(config.uploadDir, { recursive: true });
    await fs.writeFile(path.join(config.uploadDir, storageName), req.file.buffer, { flag: 'wx', mode: 0o640 });
    try {
      await inTransaction(async (client) => {
        const result = await client.query(
          `INSERT INTO uploads (
             owner_id, storage_name, mime_type, byte_size, purpose, visibility,
             listing_id, thread_id
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
           RETURNING id`,
          [
            req.auth.userId,
            storageName,
            detected.mime,
            req.file.buffer.length,
            purpose,
            visibility,
            listingId,
            threadId,
          ],
        );
        await writeAudit(client, {
          actor: req.actor,
          action: 'upload.created',
          resourceType: 'upload',
          resourceId: result.rows[0].id,
          metadata: { purpose, visibility },
        });
      });
    } catch (error) {
      await fs.unlink(path.join(config.uploadDir, storageName)).catch(() => {});
      throw error;
    }
    res.status(201).json({ url: `${config.publicBaseUrl}/uploads/${storageName}` });
  }));

  app.get('/v1/uploads/:storageName', asyncRoute(async (req, res) => {
    const storageName = safeText(req.params.storageName, 160);
    const result = await pool.query(
      `SELECT upload.*, thread.user1_id, thread.user2_id
       FROM uploads AS upload
       LEFT JOIN message_threads AS thread ON thread.id = upload.thread_id
       WHERE upload.storage_name = $1`,
      [storageName],
    );
    const uploadRecord = result.rows[0];
    if (!uploadRecord) throw new HttpError(404, 'upload_not_found');

    if (uploadRecord.visibility !== 'public') {
      const token = bearerToken(req);
      let userId = null;
      let sessionId = null;
      try {
        const payload = token ? verifyAccessToken(token) : null;
        userId = payload?.sub ?? null;
        sessionId = payload?.sid ?? null;
      } catch {
        throw new HttpError(401, 'invalid_or_expired_session');
      }
      if (!userId || !sessionId) throw new HttpError(401, 'authentication_required');
      const actor = await pool.query(
        `SELECT u.id
         FROM users AS u
         JOIN auth_sessions AS session
           ON session.id = $2 AND session.user_id = u.id AND session.revoked_at IS NULL
         WHERE u.id = $1 AND u.account_status = 'active' AND u.deactivated_at IS NULL`,
        [userId, sessionId],
      );
      if (!actor.rowCount) throw new HttpError(401, 'account_not_active');
      if (![uploadRecord.owner_id, uploadRecord.user1_id, uploadRecord.user2_id].includes(userId)) {
        throw new HttpError(403, 'upload_forbidden');
      }
    }

    const contents = await fs.readFile(path.join(config.uploadDir, uploadRecord.storage_name));
    res.set({
      'Content-Type': uploadRecord.mime_type,
      'Content-Length': String(uploadRecord.byte_size),
      'Cache-Control': uploadRecord.visibility === 'public'
        ? 'public, max-age=31536000, immutable'
        : 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    res.send(contents);
  }));

  app.use((_req, res) => res.status(404).json({ error: 'not_found' }));
  app.use((error, _req, res, _next) => {
    const uploadTooLarge = error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE';
    const bookingConflict = error?.code === '23P01';
    const status = bookingConflict
      ? 409
      : (uploadTooLarge ? 413 : (error instanceof HttpError ? error.status : (error?.status ?? 500)));
    const code = uploadTooLarge
      ? 'image_too_large'
      : (bookingConflict
          ? 'booking_period_unavailable'
          : (error instanceof HttpError ? error.code : (status === 500 ? 'internal_error' : 'request_failed')));
    if (status >= 500) console.error('[api]', error);
    res.status(status).json({ error: code, ...(error?.details ? { details: error.details } : {}) });
  });

  return app;
}
