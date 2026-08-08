import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

import cors from 'cors';
import express from 'express';
import { rateLimit } from 'express-rate-limit';
import { fileTypeFromBuffer } from 'file-type';
import helmet from 'helmet';
import multer from 'multer';

import { config } from './config.js';
import { inTransaction, pool } from './db.js';
import { publishToAll, publishToUsers } from './realtime.js';
import {
  defaultProfile,
  hashPassword,
  hashRefreshToken,
  isValidEmail,
  isValidPassword,
  newRefreshToken,
  normalizeEmail,
  requireAuth,
  safeText,
  sanitizeProfileUpdate,
  shapeUser,
  signAccessToken,
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

function identifier(value, prefix) {
  const raw = typeof value === 'string' ? value.trim() : '';
  if (raw && raw.length <= 120 && /^[A-Za-z0-9_.:-]+$/.test(raw)) return raw;
  return `${prefix}_${crypto.randomUUID()}`;
}

function ensureObject(value, code = 'invalid_payload') {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new HttpError(400, code);
  return { ...value };
}

function allowedStatus(value) {
  const allowed = new Set(['pending', 'accepted', 'declined', 'cancelled', 'running', 'completed']);
  return allowed.has(value) ? value : 'pending';
}

function canTransition({ current, next, actorId, ownerId, renterId }) {
  if (current === next) return true;
  if (current === 'pending' && (next === 'accepted' || next === 'declined')) return actorId === ownerId;
  if (current === 'pending' && next === 'cancelled') return actorId === renterId;
  if (current === 'accepted' && next === 'running') return actorId === renterId;
  if (current === 'accepted' && next === 'cancelled') return actorId === ownerId || actorId === renterId;
  if (current === 'running' && next === 'completed') return actorId === ownerId;
  return false;
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
  const status = allowedStatus(payload.status ?? existingStatus);
  const start = Date.parse(payload.start);
  const end = Date.parse(payload.end);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) {
    throw new HttpError(400, 'invalid_rental_period');
  }
  return {
    ...payload,
    id,
    itemId,
    ownerId,
    renterId,
    status,
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

  const nextStatus = allowedStatus(candidate.status ?? existing.status);
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

async function issueSession(client, user, userAgent) {
  const refreshToken = newRefreshToken();
  const refreshHash = hashRefreshToken(refreshToken);
  const expiresAt = new Date(Date.now() + config.refreshTokenLifetimeDays * 24 * 60 * 60 * 1000);
  await client.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at, user_agent)
     VALUES ($1, $2, $3, $4)`,
    [user.id, refreshHash, expiresAt, safeText(userAgent, 500) || null],
  );
  return {
    accessToken: signAccessToken(user),
    refreshToken,
    expiresIn: config.accessTokenLifetimeSeconds,
    user: shapeUser(user),
  };
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

  const generalLimiter = rateLimit({ windowMs: 60_000, limit: 240, standardHeaders: 'draft-8', legacyHeaders: false });
  const authLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 30, standardHeaders: 'draft-8', legacyHeaders: false });
  app.use(generalLimiter);

  app.get('/health', asyncRoute(async (_req, res) => {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', service: 'shareittoo-api', time: new Date().toISOString() });
  }));

  app.post('/v1/auth/register', authLimiter, asyncRoute(async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    const password = req.body?.password;
    if (!isValidEmail(email)) throw new HttpError(400, 'invalid_email');
    if (!isValidPassword(password)) throw new HttpError(400, 'password_too_short');
    const passwordHash = await hashPassword(password);
    const userId = crypto.randomUUID();

    const session = await inTransaction(async (client) => {
      const existing = await client.query('SELECT 1 FROM users WHERE email = $1', [email]);
      if (existing.rowCount) throw new HttpError(409, 'email_in_use');
      const result = await client.query(
        `INSERT INTO users (id, email, password_hash, profile)
         VALUES ($1, $2, $3, $4::jsonb)
         RETURNING *`,
        [userId, email, passwordHash, JSON.stringify(defaultProfile({ email }))],
      );
      return issueSession(client, result.rows[0], req.get('user-agent'));
    });
    res.status(201).json(session);
  }));

  app.post('/v1/auth/login', authLimiter, asyncRoute(async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    const password = req.body?.password;
    if (!isValidEmail(email) || typeof password !== 'string') throw new HttpError(401, 'invalid_credentials');
    const result = await pool.query(
      `SELECT * FROM users WHERE email = $1 AND deactivated_at IS NULL`,
      [email],
    );
    const user = result.rows[0];
    if (!user?.password_hash || !(await verifyPassword(password, user.password_hash))) {
      throw new HttpError(401, 'invalid_credentials');
    }
    const session = await inTransaction((client) => issueSession(client, user, req.get('user-agent')));
    res.json(session);
  }));

  app.post('/v1/auth/refresh', authLimiter, asyncRoute(async (req, res) => {
    const refreshToken = safeText(req.body?.refreshToken, 500);
    if (!refreshToken) throw new HttpError(401, 'invalid_refresh_token');
    const currentHash = hashRefreshToken(refreshToken);
    const session = await inTransaction(async (client) => {
      const result = await client.query(
        `SELECT u.id, u.email, u.password_hash, u.profile, u.created_at,
                u.updated_at, u.deactivated_at,
                rt.id AS refresh_id, rt.user_id AS refresh_user_id,
                rt.expires_at AS refresh_expires_at, rt.revoked_at AS refresh_revoked_at
         FROM refresh_tokens rt JOIN users u ON u.id = rt.user_id
         WHERE rt.token_hash = $1 FOR UPDATE`,
        [currentHash],
      );
      const row = result.rows[0];
      if (!row || row.refresh_revoked_at || new Date(row.refresh_expires_at) <= new Date() || row.deactivated_at) {
        throw new HttpError(401, 'invalid_refresh_token');
      }
      const next = await issueSession(client, row, req.get('user-agent'));
      await client.query(
        `UPDATE refresh_tokens SET revoked_at = now(), replaced_by_hash = $2 WHERE token_hash = $1`,
        [currentHash, hashRefreshToken(next.refreshToken)],
      );
      return next;
    });
    res.json(session);
  }));

  app.post('/v1/auth/logout', asyncRoute(async (req, res) => {
    const refreshToken = safeText(req.body?.refreshToken, 500);
    if (refreshToken) {
      await pool.query(
        `UPDATE refresh_tokens SET revoked_at = COALESCE(revoked_at, now()) WHERE token_hash = $1`,
        [hashRefreshToken(refreshToken)],
      );
    }
    res.status(204).end();
  }));

  app.get('/v1/auth/me', requireAuth, asyncRoute(async (req, res) => {
    const result = await pool.query('SELECT * FROM users WHERE id = $1 AND deactivated_at IS NULL', [req.auth.userId]);
    if (!result.rowCount) throw new HttpError(404, 'user_not_found');
    res.json({ user: shapeUser(result.rows[0]) });
  }));

  app.patch('/v1/profile', requireAuth, asyncRoute(async (req, res) => {
    const update = sanitizeProfileUpdate(req.body?.profile ?? req.body);
    const result = await pool.query(
      `UPDATE users SET profile = profile || $2::jsonb WHERE id = $1 AND deactivated_at IS NULL RETURNING *`,
      [req.auth.userId, JSON.stringify(update)],
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

  app.get('/v1/listings/mine', requireAuth, asyncRoute(async (req, res) => {
    const result = await pool.query(
      `SELECT payload FROM listings WHERE owner_id = $1 ORDER BY created_at DESC LIMIT 500`,
      [req.auth.userId],
    );
    res.json({ listings: result.rows.map((row) => row.payload) });
  }));

  app.post('/v1/listings', requireAuth, asyncRoute(async (req, res) => {
    const id = identifier(req.body?.id === 'new' ? '' : req.body?.id, 'listing');
    const payload = listingPayload(req.body, { id, ownerId: req.auth.userId });
    const result = await pool.query(
      `INSERT INTO listings (id, owner_id, payload, is_active, created_at)
       VALUES ($1, $2, $3::jsonb, $4, $5::timestamptz)
       RETURNING payload`,
      [id, req.auth.userId, JSON.stringify(payload), payload.isActive, payload.createdAt],
    );
    publishToAll({ type: 'changed', resource: 'listings' });
    res.status(201).json({ listing: result.rows[0].payload });
  }));

  app.put('/v1/listings/:id', requireAuth, asyncRoute(async (req, res) => {
    const id = safeText(req.params.id, 120);
    const existing = await pool.query('SELECT * FROM listings WHERE id = $1', [id]);
    if (!existing.rowCount) throw new HttpError(404, 'listing_not_found');
    if (existing.rows[0].owner_id !== req.auth.userId) throw new HttpError(403, 'listing_forbidden');
    const payload = listingPayload(req.body, {
      id,
      ownerId: req.auth.userId,
      existingCreatedAt: new Date(existing.rows[0].created_at).toISOString(),
    });
    const result = await pool.query(
      `UPDATE listings SET payload = $2::jsonb, is_active = $3 WHERE id = $1 RETURNING payload`,
      [id, JSON.stringify(payload), payload.isActive],
    );
    publishToAll({ type: 'changed', resource: 'listings' });
    res.json({ listing: result.rows[0].payload });
  }));

  app.patch('/v1/listings/:id/status', requireAuth, asyncRoute(async (req, res) => {
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

  app.delete('/v1/listings/:id', requireAuth, asyncRoute(async (req, res) => {
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

  app.get('/v1/rental-requests', requireAuth, asyncRoute(async (req, res) => {
    res.json({ requests: await listRentalRequests(pool, req.auth.userId) });
  }));

  app.put('/v1/rental-requests/sync', requireAuth, asyncRoute(async (req, res) => {
    if (!Array.isArray(req.body?.requests) || req.body.requests.length > 500) throw new HttpError(400, 'invalid_requests');
    const participants = new Set([req.auth.userId]);
    const requests = await inTransaction(async (client) => {
      for (const raw of req.body.requests) {
        const candidate = ensureObject(raw, 'invalid_request');
        const id = identifier(candidate.id, 'request');
        const existingResult = await client.query('SELECT * FROM rental_requests WHERE id = $1 FOR UPDATE', [id]);
        if (!existingResult.rowCount) {
          const itemId = safeText(candidate.itemId, 120);
          const listingResult = await client.query('SELECT owner_id FROM listings WHERE id = $1 AND is_active = true', [itemId]);
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
          participants.add(ownerId);
          continue;
        }

        const existing = existingResult.rows[0];
        if (existing.owner_id !== req.auth.userId && existing.renter_id !== req.auth.userId) {
          throw new HttpError(403, 'request_forbidden');
        }
        const payload = existingRentalPayload(candidate, existing, req.auth.userId);
        if (!canTransition({ current: existing.status, next: payload.status, actorId: req.auth.userId, ownerId: existing.owner_id, renterId: existing.renter_id })) {
          throw new HttpError(409, 'invalid_status_transition', { current: existing.status, next: payload.status });
        }
        await client.query(
          `UPDATE rental_requests SET status = $2, payload = $3::jsonb WHERE id = $1`,
          [id, payload.status, JSON.stringify(payload)],
        );
        participants.add(existing.owner_id);
        participants.add(existing.renter_id);
      }
      return listRentalRequests(client, req.auth.userId);
    });
    publishToUsers([...participants], { type: 'changed', resource: 'rental_requests' });
    res.json({ requests });
  }));

  app.get('/v1/message-threads', requireAuth, asyncRoute(async (req, res) => {
    res.json({ threads: await listThreads(pool, req.auth.userId) });
  }));

  app.put('/v1/message-threads/sync', requireAuth, asyncRoute(async (req, res) => {
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
  app.post('/v1/uploads', requireAuth, upload.single('file'), asyncRoute(async (req, res) => {
    if (!req.file?.buffer) throw new HttpError(400, 'file_required');
    const detected = await fileTypeFromBuffer(req.file.buffer);
    const allowed = new Set(['image/jpeg', 'image/png', 'image/webp']);
    if (!detected || !allowed.has(detected.mime)) throw new HttpError(415, 'unsupported_image_type');
    const storageName = `${crypto.randomUUID()}.${detected.ext}`;
    await fs.mkdir(config.uploadDir, { recursive: true });
    await fs.writeFile(path.join(config.uploadDir, storageName), req.file.buffer, { flag: 'wx', mode: 0o640 });
    await pool.query(
      `INSERT INTO uploads (owner_id, storage_name, mime_type, byte_size) VALUES ($1, $2, $3, $4)`,
      [req.auth.userId, storageName, detected.mime, req.file.buffer.length],
    );
    res.status(201).json({ url: `${config.publicBaseUrl}/uploads/${storageName}` });
  }));
  app.use('/v1/uploads', express.static(config.uploadDir, { immutable: true, maxAge: '1y', fallthrough: false }));

  app.use((_req, res) => res.status(404).json({ error: 'not_found' }));
  app.use((error, _req, res, _next) => {
    const uploadTooLarge = error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE';
    const status = uploadTooLarge ? 413 : (error instanceof HttpError ? error.status : (error?.status ?? 500));
    const code = uploadTooLarge
      ? 'image_too_large'
      : (error instanceof HttpError ? error.code : (status === 500 ? 'internal_error' : 'request_failed'));
    if (status >= 500) console.error('[api]', error);
    res.status(status).json({ error: code, ...(error?.details ? { details: error.details } : {}) });
  });

  return app;
}
