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
  publicComplianceOverview,
  publicPrivacyPage,
  publicImprintPage,
  publicSupportPage,
  resultPage,
} from './account_actions.js';
import {
  deletePushDevicesForSession,
  revokeSessionByRefreshToken,
} from './auth_session_actions.js';
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
  amendBooking,
  BookingWorkflowError,
  assertBookingPilot,
  checkListingAvailability,
  createBooking,
  getListingAvailability,
  listBookings,
  quoteBooking,
  replaceListingAvailability,
  transitionBooking,
} from './booking_workflow.js';
import {
  BookingFlowTimeError,
  getBookingFlowTime,
  updateBookingFlowTime,
} from './booking_flow_time.js';
import { BookingConfirmationError } from './booking_confirmation_domain.js';
import {
  getConditionEvidenceSummary,
  recordConditionConfirmation,
} from './booking_condition_evidence_workflow.js';
import {
  issueBookingConfirmationChallenge,
  verifyBookingConfirmationChallenge,
} from './booking_confirmation_workflow.js';
import {
  getMailerStatus,
  sendAccountDeletionEmail,
  sendEmailChangeAlert,
  sendEmailChangeVerification,
  sendPasswordResetEmail,
  sendVerificationEmail,
} from './mailer.js';
import {
  blockUser,
  ensureBookingThread,
  listBlocks,
  listCommunicationThreads,
  listThreadMessages,
  markThreadRead,
  MessageWorkflowError,
  sendThreadMessage,
  setThreadArchived,
  unblockUser,
} from './message_workflow.js';
import {
  drainNotificationOutbox,
  notificationHealth,
} from './notifications.js';
import {
  createConnectOnboarding,
  createPaymentCheckout,
  getBookingPayment,
  getConnectStatus,
  paymentHealth,
  refundPayment,
  releasePayout,
  simulatePaymentEvent,
  verifyAndApplyWebhook,
} from './payment_workflow.js';
import { PaymentDomainError } from './payment_domain.js';
import { ModerationDomainError } from './moderation_domain.js';
import {
  createAccountLegalHold,
  createBookingReview,
  createReport,
  createStaffElevation,
  getStaffEvidence,
  getStaffReport,
  liftUserSuspension,
  listMyReports,
  listAccountLegalHolds,
  listPublishedReviews,
  listStaffAudit,
  listStaffBookings,
  listStaffListings,
  listStaffPayments,
  listStaffReports,
  listStaffUsers,
  ModerationWorkflowError,
  releaseAccountLegalHold,
  setListingModeration,
  setUserSuspension,
  staffOverview,
  updateStaffReport,
  verifyStaffElevation,
} from './moderation_workflow.js';
import { publishToAll, publishToUsers } from './realtime.js';
import {
  inspectRetentionInventory,
  RetentionInventoryError,
} from './retention_inventory.js';
import {
  FinancialDocumentError,
  getFinancialDocumentArtifact,
  listFinancialDocuments,
} from './financial_documents.js';
import { releaseMetadata } from './release.js';
import {
  privatePilotDeclarations,
  privatePilotDocument,
} from './private_pilot_domain.js';
import { v51ContractDocumentReadiness } from './v51_contract_workflow.js';
import {
  getV51ContractReceipt,
  V51ContractReceiptError,
} from './v51_contract_receipt.js';
import {
  getV51WithdrawalReceipt,
  recordV51Withdrawal,
  V51WithdrawalError,
} from './v51_withdrawal_workflow.js';
import {
  evaluateReturnTimeline,
  splitAuthorizedBookingAmount,
} from './private_pilot_return_domain.js';
import { errorPayload, requestContext, safeErrorLog } from './observability.js';
import { buildAccountExport } from './privacy_export.js';
import { createMapsProxy, MapsProxyError } from './maps_proxy.js';
import {
  SocialAuthError,
  verifyFirebaseSocialToken,
} from './firebase_social_auth.js';
import {
  deleteFirebasePhoneIdentity,
  PhoneVerificationError,
  verifyFirebasePhoneToken,
} from './firebase_phone_verification.js';
import {
  drainFirebaseIdentityDeletionOutbox,
  enqueueFirebaseIdentityDeletions,
} from './firebase_identity_cleanup.js';
import {
  ListingValidationError,
  listingProjection,
  normalizeListingPayload,
  parseCatalogQuery,
  shapePublicListing,
  storageNameFromListingPhoto,
} from './listing_catalog.js';
import { ImageProcessingError, sanitizeImage } from './media_pipeline.js';
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

const mapsProxy = createMapsProxy({ apiKey: config.maps.serverApiKey });

function kickNotificationWorker() {
  void drainNotificationOutbox().catch((error) => {
    console.error('[notifications] background drain failed', error?.message ?? error);
  });
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

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function deepLinkFallbackPage({ kind, id }) {
  const labels = {
    booking: 'Buchung',
    chat: 'Chat',
    listing: 'Anzeige',
    payment: 'Zahlung',
    profile: 'Profil',
  };
  const label = labels[kind] ?? 'Inhalt';
  const schemeUrl = `shareittoo://${kind}/${encodeURIComponent(id)}`;
  return `<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${label} in ShareItToo öffnen</title></head>
<body style="margin:0;background:#f3f6fb;font-family:Arial,sans-serif;color:#172033"><main style="max-width:560px;margin:12vh auto;padding:24px"><section style="background:#fff;border-radius:20px;padding:32px;box-shadow:0 10px 30px rgba(20,35,70,.08)"><div style="font-size:26px;font-weight:800;color:#2156d9">ShareItToo</div><h1>${label} öffnen</h1><p>Öffne den sicheren Kontext in der ShareItToo-App. Nach der Anmeldung wird deine Berechtigung erneut geprüft.</p><p><a href="${escapeHtml(schemeUrl)}" style="display:inline-block;background:#2156d9;color:#fff;text-decoration:none;font-weight:700;padding:14px 22px;border-radius:12px">In der App öffnen</a></p><p style="font-size:13px;color:#5d6980">Wenn die App noch nicht installiert ist, kehre bitte zur ShareItToo-Website zurück. Dieser Link enthält keine Zahlungs- oder Zugangsdaten.</p><p><a href="${escapeHtml(config.appPublicUrl)}">Zur ShareItToo-Website</a></p></section></main></body></html>`;
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

function requireUnsuspendedScope(...scopes) {
  return asyncRoute(async (req, _res, next) => {
    const result = await pool.query(
      `SELECT scope FROM user_suspensions
       WHERE user_id = $1 AND lifted_at IS NULL AND starts_at <= now()
         AND (ends_at IS NULL OR ends_at > now())
         AND (scope = 'account' OR scope = ANY($2::text[]))
       LIMIT 1`,
      [req.auth.userId, scopes],
    );
    if (result.rowCount) throw new HttpError(403, 'action_blocked_by_moderation', { scope: result.rows[0].scope });
    next();
  });
}

const requireStaffElevation = asyncRoute(async (req, _res, next) => {
  req.staffElevation = await verifyStaffElevation(pool, {
    actor: req.actor,
    sessionId: req.auth.sessionId,
    token: req.get('X-Admin-Step-Up'),
  });
  next();
});

async function writeAudit(client, {
  actor = null,
  action,
  resourceType,
  resourceId,
  requestId = null,
  metadata = {},
}) {
  await client.query(
    `INSERT INTO audit_log (
       actor_id, actor_role, action, resource_type, resource_id, request_id, metadata
     ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)`,
    [
      actor?.id ?? null,
      actor?.role ?? 'system',
      action,
      resourceType,
      resourceId,
      requestId,
      JSON.stringify(metadata),
    ],
  );
}

async function writePrivatePilotDeclaration(client, {
  userId,
  declarationType,
  listingId = null,
  bookingId = null,
  accepted = true,
}) {
  const wordingKey = {
    account_private: 'account',
    listing_private: 'listing',
    booking_private: 'booking',
  }[declarationType];
  if (!wordingKey) throw new Error('invalid_private_pilot_declaration_type');
  await client.query(
    `INSERT INTO legal_declarations (
       user_id, listing_id, booking_id, declaration_type, exact_wording,
       document_name, document_version, app_version, language, accepted
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
    [
      userId,
      listingId,
      bookingId,
      declarationType,
      privatePilotDeclarations[wordingKey],
      privatePilotDocument.name,
      privatePilotDocument.version,
      releaseMetadata.version,
      privatePilotDocument.language,
      accepted,
    ],
  );
}

function listingFinancials(payload) {
  return {
    currency: normalizeCurrency(payload.currency),
    pricePerDayMinor: amountToMinor(payload.pricePerDay),
    securityDepositMinor: null,
  };
}

function listingPayload(raw, {
  id,
  ownerId,
  existingCreatedAt = null,
  existingPayload = null,
}) {
  const source = ensureObject(raw);
  try {
    return normalizeListingPayload(source, {
      id,
      ownerId,
      existing: existingCreatedAt
        ? {
            createdAt: existingCreatedAt,
            verificationStatus: safeText(existingPayload?.verificationStatus, 30) || 'pending',
            timesLent: Number.isInteger(existingPayload?.timesLent) ? existingPayload.timesLent : 0,
          }
        : null,
      privatePilot: config.privatePilotV4Enabled,
    });
  } catch (error) {
    if (error instanceof ListingValidationError) {
      throw new HttpError(400, error.code, error.details);
    }
    throw error;
  }
}

function listingProjectionValues(payload) {
  const projection = listingProjection(payload);
  return [
    projection.status,
    projection.isActive,
    projection.title,
    projection.description,
    projection.categoryId,
    projection.subcategory,
    projection.condition,
    projection.locationText,
    projection.city,
    projection.country,
    projection.latitude,
    projection.longitude,
    projection.minDays,
    projection.maxDays,
    projection.handoverRadiusKm,
    projection.protectionModel,
    projection.publishedAt,
    projection.endedAt,
  ];
}

async function bindListingUploads(client, { listingId, ownerId, photos, requirePhoto }) {
  const storageNames = photos.map((photo) => storageNameFromListingPhoto(photo, config.publicBaseUrl));
  if (storageNames.some((storageName) => !storageName)) {
    throw new HttpError(400, 'listing_photo_must_be_uploaded');
  }
  const uniqueNames = [...new Set(storageNames)];
  if (requirePhoto && uniqueNames.length === 0) throw new HttpError(400, 'listing_photo_required');

  if (uniqueNames.length > 0) {
    const records = await client.query(
      `SELECT id, owner_id, storage_name, purpose, content_scan_status, listing_id
       FROM uploads
       WHERE storage_name = ANY($1::text[])
       FOR UPDATE`,
      [uniqueNames],
    );
    if (records.rowCount !== uniqueNames.length) throw new HttpError(400, 'listing_photo_not_found');
    for (const record of records.rows) {
      if (record.owner_id !== ownerId) throw new HttpError(403, 'listing_photo_forbidden');
      if (record.purpose !== 'listing_image' || record.content_scan_status !== 'passed') {
        throw new HttpError(400, 'listing_photo_not_approved');
      }
      if (record.listing_id && record.listing_id !== listingId) {
        throw new HttpError(409, 'listing_photo_already_used');
      }
    }
  }

  await client.query(
    `UPDATE uploads
     SET listing_id = NULL, visibility = 'private'
     WHERE listing_id = $1
       AND NOT (storage_name = ANY($2::text[]))`,
    [listingId, uniqueNames],
  );
  if (uniqueNames.length > 0) {
    await client.query(
      `UPDATE uploads
       SET listing_id = $1, visibility = 'public'
       WHERE storage_name = ANY($2::text[])`,
      [listingId, uniqueNames],
    );
  }
}

function buildCatalogSearch(search) {
  const values = [];
  const bind = (value) => {
    values.push(value);
    return `$${values.length}`;
  };
  const clauses = [
    'listing.catalog_version = 1',
    'listing.is_active = true',
    "listing.status = 'active'",
    "listing.moderation_status = 'active'",
  ];
  let distanceExpression = 'NULL::double precision';
  if (search.latitude !== null && search.longitude !== null) {
    const latitude = bind(search.latitude);
    const longitude = bind(search.longitude);
    const publicLatitude = 'round(listing.latitude::numeric, 2)::double precision';
    const publicLongitude = 'round(listing.longitude::numeric, 2)::double precision';
    distanceExpression = `6371.0 * acos(least(1.0, greatest(-1.0,
      cos(radians(${latitude})) * cos(radians(${publicLatitude}))
      * cos(radians(${publicLongitude}) - radians(${longitude}))
      + sin(radians(${latitude})) * sin(radians(${publicLatitude}))
    )))`;
    if (search.radiusKm !== null) clauses.push(`${distanceExpression} <= ${bind(search.radiusKm)}`);
  }
  if (search.q) {
    const query = bind(search.q);
    clauses.push(`(
      to_tsvector(
        'simple'::regconfig,
        coalesce(listing.title, '') || ' ' ||
        coalesce(listing.description, '') || ' ' ||
        coalesce(listing.category_id, '') || ' ' ||
        coalesce(listing.subcategory, '') || ' ' ||
        coalesce(listing.city, '') || ' ' ||
        coalesce(listing.country, '')
      )
        @@ websearch_to_tsquery('simple', ${query})
      OR listing.title ILIKE '%' || ${query} || '%'
      OR listing.description ILIKE '%' || ${query} || '%'
    )`);
  }
  if (search.categories.length > 0) clauses.push(`listing.category_id = ANY(${bind(search.categories)}::text[])`);
  if (search.conditions.length > 0) clauses.push(`listing.condition = ANY(${bind(search.conditions)}::text[])`);
  if (search.minPrice !== null) clauses.push(`listing.price_per_day_minor >= ${bind(Math.round(search.minPrice * 100))}`);
  if (search.maxPrice !== null) clauses.push(`listing.price_per_day_minor <= ${bind(Math.round(search.maxPrice * 100))}`);

  const orderBy = {
    newest: 'listing.created_at DESC, listing.id ASC',
    price_asc: 'listing.price_per_day_minor ASC, listing.created_at DESC, listing.id ASC',
    price_desc: 'listing.price_per_day_minor DESC, listing.created_at DESC, listing.id ASC',
    distance: 'distance_km ASC NULLS LAST, listing.created_at DESC, listing.id ASC',
  }[search.sort];
  const limit = bind(search.limit + 1);
  const offset = bind(search.offset);
  return {
    text: `SELECT listing.payload, media.storage_names, ${distanceExpression} AS distance_km
      FROM listings AS listing
      JOIN LATERAL (
        SELECT array_agg(upload.storage_name ORDER BY upload.created_at) AS storage_names
        FROM uploads AS upload
        WHERE upload.listing_id = listing.id
          AND upload.purpose = 'listing_image'
          AND upload.visibility = 'public'
          AND upload.content_scan_status = 'passed'
      ) AS media ON cardinality(media.storage_names) > 0
      WHERE ${clauses.join('\n AND ')}
      ORDER BY ${orderBy}
      LIMIT ${limit}
      OFFSET ${offset}`,
    values,
  };
}

function publicListingFromRow(row) {
  const allowed = new Set(row.storage_names ?? []);
  const payload = ensureObject(row.payload, 'invalid_stored_listing');
  const photos = Array.isArray(payload.photos)
    ? payload.photos.filter((photo) => {
        const storageName = storageNameFromListingPhoto(photo, config.publicBaseUrl);
        return storageName && allowed.has(storageName);
      })
    : [];
  return shapePublicListing({ ...payload, photos }, { distanceKm: row.distance_km });
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

  if (!config.privatePilotV4Enabled && Object.hasOwn(candidate, 'handoverConfirmation')) {
    merged.handoverConfirmation = candidate.handoverConfirmation;
  }

  if (config.privatePilotV4Enabled) {
    const now = new Date();
    merged.handoverConfirmation = stored.handoverConfirmation ?? null;
    const storedConfirmation = stored.returnConfirmation
      && typeof stored.returnConfirmation === 'object'
      && !Array.isArray(stored.returnConfirmation)
      ? { ...stored.returnConfirmation }
      : {};
    merged.returnConfirmation = storedConfirmation;
    const normalizedConfirmation = storedConfirmation;
    const ownerConfirmed = Number.isFinite(Date.parse(normalizedConfirmation.ownerConfirmedAt));
    const renterConfirmed = Number.isFinite(Date.parse(normalizedConfirmation.renterConfirmedAt));
    const t0 = Number.isFinite(Date.parse(stored.returnT0))
      ? new Date(stored.returnT0)
      : new Date(stored.end);
    const requestedEvidence = Array.isArray(candidate.reviewEvidenceReferences)
      ? candidate.reviewEvidenceReferences
        .map((entry) => safeText(entry, 500))
        .filter(Boolean)
        .slice(0, 20)
      : [];
    const requestsNewCase = candidate.needsReview === true && stored.needsReview !== true;

    if (requestsNewCase) {
      const reason = safeText(candidate.reviewReason, 2000);
      const reportDeadline = new Date(t0.getTime() + 48 * 60 * 60 * 1000);
      if (reason.length < 10 || requestedEvidence.length === 0) {
        throw new HttpError(400, 'substantiated_return_case_required');
      }
      if (now > reportDeadline) {
        throw new HttpError(409, 'return_report_window_closed');
      }
      const amounts = splitAuthorizedBookingAmount({
        authorizedBookingMinor: Number(stored.quotedTotalMinor ?? 0),
        contestedAuthorizedMinor: Number(candidate.contestedAuthorizedMinor ?? 0),
        allegedDamageMinor: Number(candidate.allegedDamageMinorRecordedOnly ?? 0),
      });
      merged.needsReview = true;
      merged.reviewReason = reason;
      merged.reviewSource = safeText(candidate.reviewSource, 120) || 'booking_return';
      merged.reviewRequestedAt = now.toISOString();
      merged.reviewEvidenceReferences = requestedEvidence;
      merged.returnCaseOpenedAt = now.toISOString();
      merged.contestedAuthorizedMinor = amounts.contestedAuthorizedMinor;
      merged.allegedDamageMinorRecordedOnly = amounts.allegedDamageMinorRecordedOnly;
    } else if (stored.needsReview === true) {
      for (const key of [
        'needsReview', 'reviewReason', 'reviewSource', 'reviewRequestedAt',
        'reviewEvidenceReferences', 'returnCaseOpenedAt', 'returnCaseClosedAt',
        'contestedAuthorizedMinor', 'allegedDamageMinorRecordedOnly',
      ]) {
        if (Object.hasOwn(stored, key)) merged[key] = stored[key];
      }
    }

    const shouldTrackReturn = existing.status === 'completed'
      || ownerConfirmed
      || renterConfirmed
      || merged.needsReview === true;
    if (shouldTrackReturn) {
      const timeline = evaluateReturnTimeline({
        scheduledReturnAt: stored.end,
        mutuallyConfirmedActualReturnAt: t0,
        ownerConfirmed,
        renterConfirmed,
        substantiatedCaseOpenedAt: merged.needsReview === true
          ? merged.returnCaseOpenedAt
          : null,
        now,
      });
      merged.returnState = timeline.state;
      merged.returnT0 = timeline.t0;
      merged.returnReportDeadline = timeline.reportDeadline;
      merged.returnClarificationDeadline = timeline.clarificationDeadline;
      merged.payoutInstructionDueAt = timeline.payoutInstructionDueAt;
      merged.needsReview = timeline.state === 'needsReview';
    }
  } else {
    if (Object.hasOwn(candidate, 'returnConfirmation')) {
      merged.returnConfirmation = candidate.returnConfirmation;
    }
    for (const key of [
      'needsReview', 'reviewReason', 'reviewSource', 'reviewRequestedAt',
    ]) {
      if (Object.hasOwn(candidate, key)) merged[key] = candidate[key];
    }
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
          AND dispute.status IN ('open', 'investigating', 'waiting_for_user')) AS open_disputes,
       (SELECT count(*)::int FROM reports AS report
        WHERE report.status IN ('open', 'triaged', 'investigating', 'actioned')
          AND (
            report.reporter_id = $1 OR report.assigned_to = $1
            OR (report.target_type = 'user' AND report.target_id = $1)
            OR (report.target_type = 'listing' AND EXISTS (
              SELECT 1 FROM listings WHERE id = report.target_id AND owner_id = $1
            ))
            OR (report.target_type = 'booking' AND EXISTS (
              SELECT 1 FROM bookings WHERE id = report.target_id AND (owner_id = $1 OR renter_id = $1)
            ))
          )) AS open_reports,
       (SELECT count(*)::int FROM account_legal_holds
        WHERE user_id = $1 AND released_at IS NULL) AS active_legal_holds`,
    [userId],
  );
  const counts = result.rows[0] ?? {};
  const definitions = [
    ['active_bookings', 'Aktive oder bevorstehende Buchungen'],
    ['open_payouts', 'Offene Auszahlungen'],
    ['active_payments', 'Laufende Zahlungsabwicklung'],
    ['open_disputes', 'Offene Streitfälle'],
    ['open_reports', 'Offene Moderationsfälle'],
    ['active_legal_holds', 'Rechtliche Aufbewahrungssperre'],
  ];
  const blockers = definitions
    .map(([id, label]) => ({ id, label, count: Number(counts[id] ?? 0) }))
    .filter((blocker) => blocker.count > 0);
  return { canDelete: blockers.length === 0, blockers };
}

async function reconcileExpiredAccountSuspension(email) {
  await inTransaction(async (client) => {
    const result = await client.query(
      `UPDATE users AS account
       SET account_status = 'active'
       WHERE account.email = $1 AND account.account_status = 'suspended'
         AND account.deactivated_at IS NULL
         AND NOT EXISTS (
           SELECT 1 FROM user_suspensions AS suspension
           WHERE suspension.user_id = account.id AND suspension.scope = 'account'
             AND suspension.lifted_at IS NULL AND suspension.starts_at <= now()
             AND (suspension.ends_at IS NULL OR suspension.ends_at > now())
         )
       RETURNING account.id`,
      [email],
    );
    if (result.rowCount) {
      await writeAudit(client, {
        action: 'moderation.account_suspension_expired',
        resourceType: 'user',
        resourceId: result.rows[0].id,
      });
    }
  });
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
    `DELETE FROM uploads AS upload
     WHERE upload.owner_id = $1
       AND NOT EXISTS (SELECT 1 FROM report_evidence WHERE upload_id = upload.id)
       AND NOT EXISTS (
         SELECT 1 FROM booking_condition_evidence
         WHERE upload_id = upload.id
       )
     RETURNING storage_name, thumbnail_storage_name`,
    [user.id],
  );
  await client.query('DELETE FROM notification_preferences WHERE user_id = $1', [user.id]);
  await client.query('DELETE FROM notifications WHERE user_id = $1', [user.id]);
  await client.query('DELETE FROM message_reads WHERE user_id = $1', [user.id]);
  await client.query(
    'DELETE FROM user_blocks WHERE blocker_id = $1 OR blocked_id = $1',
    [user.id],
  );
  await client.query(
    `UPDATE notification_outbox
     SET payload = '{}'::jsonb,
         status = CASE
           WHEN status IN ('pending', 'processing', 'retry') THEN 'suppressed'
           ELSE status
         END,
         locked_at = NULL,
         locked_by = NULL,
         provider_message_id = NULL,
         last_error_code = CASE
           WHEN status IN ('pending', 'processing', 'retry') THEN 'account_deleted'
           ELSE NULL
         END
     WHERE user_id = $1`,
    [user.id],
  );
  await client.query('DELETE FROM push_devices WHERE user_id = $1', [user.id]);
  const firebaseIdentityDeletionIds = await enqueueFirebaseIdentityDeletions(client, {
    userId: user.id,
  });
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
      retained: [
        'pseudonymous_booking_records',
        'legally_required_financial_records',
        'pseudonymous_notification_delivery_audit',
        'pseudonymous_booking_condition_evidence',
        'audit_log',
      ],
      erasedUploadCount: erasedUploads.rowCount,
    },
  });
  return {
    deleted: true,
    erasedUploadStorageNames: erasedUploads.rows.flatMap((row) => [
      row.storage_name,
      row.thumbnail_storage_name,
    ]).filter(Boolean),
    firebaseIdentityDeletionIds,
  };
}

async function removeErasedUploadFiles(storageNames) {
  const failures = [];
  for (const storageName of storageNames) {
    if (!/^[0-9a-f-]{36}(?:-(?:full|thumb))?\.[a-z0-9]+$/i.test(storageName)) {
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
  return listBookings(client, userId);
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

export function createApp({
  verifySocialToken = verifyFirebaseSocialToken,
  verifyPhoneToken = verifyFirebasePhoneToken,
  deletePhoneIdentity = deleteFirebasePhoneIdentity,
  drainFirebaseIdentityDeletions = (ids) => drainFirebaseIdentityDeletionOutbox({
    client: pool,
    ids,
  }),
} = {}) {
  const app = express();
  const attemptFirebaseIdentityDeletion = async (ids) => {
    try {
      await drainFirebaseIdentityDeletions(ids);
    } catch (error) {
      console.error(
        '[privacy] immediate Firebase identity cleanup failed; durable retry remains queued',
        error?.code ?? error?.message ?? 'cleanup_failed',
      );
    }
  };
  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(requestContext());
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(cors({
    origin(origin, callback) {
      if (!origin || config.corsOrigins.includes(origin)) return callback(null, true);
      return callback(new HttpError(403, 'origin_not_allowed'));
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key', 'X-Admin-Step-Up', 'X-Request-ID'],
    exposedHeaders: ['X-Request-ID', 'Content-Disposition', 'X-SIT-Artifact-SHA256'],
  }));
  const webhookLimiter = rateLimit({
    windowMs: 60_000,
    limit: 600,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    handler: (req, res) => res.status(429).json(errorPayload(req, 'rate_limit_exceeded')),
  });
  app.post('/v1/payments/webhook', webhookLimiter, express.raw({ type: 'application/json', limit: '2mb' }), asyncRoute(async (req, res) => {
    const result = await verifyAndApplyWebhook(req.body, req.get('Stripe-Signature'));
    kickNotificationWorker();
    res.json({ received: true, ...result });
  }));
  app.use(express.json({ limit: '2mb' }));
  app.use(express.urlencoded({ extended: false, limit: '20kb' }));

  const limitHandler = (req, res) => res.status(429).json(errorPayload(req, 'rate_limit_exceeded'));
  const generalLimiter = rateLimit({ windowMs: 60_000, limit: 240, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const registrationLimiter = rateLimit({ windowMs: 60 * 60_000, limit: 5, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const loginLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 8, standardHeaders: 'draft-8', legacyHeaders: false, skipSuccessfulRequests: true, handler: limitHandler });
  const socialAuthLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 12, standardHeaders: 'draft-8', legacyHeaders: false, skipSuccessfulRequests: true, handler: limitHandler });
  const refreshLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 60, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const actionLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 5, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const phoneVerificationLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 8, standardHeaders: 'draft-8', legacyHeaders: false, skipSuccessfulRequests: true, handler: limitHandler });
  const exportLimiter = rateLimit({ windowMs: 60 * 60_000, limit: 3, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const deletionLimiter = rateLimit({ windowMs: 60 * 60_000, limit: 3, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const mapsLimiter = rateLimit({ windowMs: 60_000, limit: 30, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const confirmationLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 30, standardHeaders: 'draft-8', legacyHeaders: false, handler: limitHandler });
  const staffElevationLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 5, standardHeaders: 'draft-8', legacyHeaders: false, skipSuccessfulRequests: true, handler: limitHandler });
  app.use(generalLimiter);

  app.get('/v1/maps/places/autocomplete', requireAuth, requireActiveAccount, mapsLimiter, asyncRoute(async (req, res) => {
    const suggestions = await mapsProxy.autocomplete({
      input: req.query.input,
      language: req.query.language,
      country: req.query.country,
    });
    res.json({ suggestions });
  }));

  app.get('/v1/maps/places/:placeId', requireAuth, requireActiveAccount, mapsLimiter, asyncRoute(async (req, res) => {
    const place = await mapsProxy.placeDetails({
      placeId: req.params.placeId,
      language: req.query.language,
    });
    res.json({ place });
  }));

  app.get('/health', asyncRoute(async (_req, res) => {
    await pool.query('SELECT 1');
    const mail = getMailerStatus();
    const [notifications, payments] = await Promise.all([notificationHealth(), paymentHealth()]);
    res.json({
      status: mail === 'ok' && notifications.dead === 0 && payments.failedEvents === 0 && payments.unbalanced === 0 ? 'ok' : 'degraded',
      service: 'shareittoo-api',
      checks: { database: 'ok', mail, notifications, payments },
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
    const [notifications, payments] = await Promise.all([notificationHealth(), paymentHealth()]);
    const ready = mail !== 'error' && mail !== 'unverified' && notifications.dead === 0
      && payments.failedEvents === 0 && payments.unbalanced === 0;
    res.status(ready ? 200 : 503).json({
      status: ready ? 'ok' : 'degraded',
      service: 'shareittoo-api',
      checks: { database: 'ok', mail, notifications, payments },
      release: releaseMetadata,
    });
  }));

  app.get('/version', (_req, res) => {
    res.set('Cache-Control', 'no-store').json(releaseMetadata);
  });

  app.get('/v1/open/:kind/:id', (req, res) => {
    const kind = safeText(req.params.kind, 20);
    const id = safeText(req.params.id, 120);
    if (!['booking', 'chat', 'listing', 'payment', 'profile'].includes(kind)
        || !id || !/^[A-Za-z0-9_.:-]+$/.test(id)) {
      return sendHtml(res, 404, resultPage({
        title: 'Link nicht verfügbar',
        message: 'Dieser ShareItToo-Link ist ungültig oder nicht mehr verfügbar.',
        success: false,
      }));
    }
    return sendHtml(res, 200, deepLinkFallbackPage({ kind, id }));
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
        || req.body?.minimumAgeConfirmed !== true
        || (config.privatePilotV4Enabled && req.body?.privateUseConfirmed !== true)) {
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
           terms_accepted_at, privacy_accepted_at, minimum_age_confirmed_at,
           private_use_confirmed_at
         ) VALUES ($1, $2, $3, $4::jsonb, now(), now(), now(),
           CASE WHEN $5::boolean THEN now() ELSE NULL END)
         RETURNING *`,
        [userId, email, passwordHash, JSON.stringify(profile), req.body?.privateUseConfirmed === true],
      );
      verificationUser = result.rows[0];
      if (config.privatePilotV4Enabled) {
        await writePrivatePilotDeclaration(client, {
          userId,
          declarationType: 'account_private',
        });
      }
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

  app.post('/v1/auth/social', socialAuthLimiter, asyncRoute(async (req, res) => {
    let identity;
    try {
      identity = await verifySocialToken(req.body?.idToken);
    } catch (error) {
      if (error instanceof SocialAuthError) {
        throw new HttpError(error.status, error.code);
      }
      throw error;
    }
    await reconcileExpiredAccountSuspension(identity.email);
    const consentsAccepted = req.body?.termsAccepted === true
      && req.body?.privacyAccepted === true
      && req.body?.minimumAgeConfirmed === true
      && (!config.privatePilotV4Enabled || req.body?.privateUseConfirmed === true);
    const outcome = await inTransaction(async (client) => {
      await client.query(
        'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
        [`social:${identity.provider}:${identity.subject}`],
      );
      let user;
      let linkedExistingAccount = false;
      let createdAccount = false;
      const linked = await client.query(
        `SELECT account.*
         FROM auth_identities AS identity
         JOIN users AS account ON account.id = identity.user_id
         WHERE identity.provider = $1 AND identity.provider_subject = $2
         FOR UPDATE OF identity, account`,
        [identity.provider, identity.subject],
      );
      if (linked.rowCount) {
        user = linked.rows[0];
      } else {
        const existing = await client.query(
          'SELECT * FROM users WHERE email = $1 FOR UPDATE',
          [identity.email],
        );
        user = existing.rows[0];
        if (user) {
          if (!identity.emailVerified) {
            throw new HttpError(409, 'social_account_link_requires_reauthentication');
          }
          linkedExistingAccount = true;
          const existingProvider = await client.query(
            'SELECT provider_subject FROM auth_identities WHERE user_id = $1 AND provider = $2',
            [user.id, identity.provider],
          );
          if (existingProvider.rowCount) {
            throw new HttpError(409, 'social_provider_already_linked');
          }
        } else {
          if (!consentsAccepted) {
            throw new HttpError(400, 'social_registration_consents_required');
          }
          const userId = crypto.randomUUID();
          const profile = {
            ...defaultProfile({ email: identity.email }),
            ...(identity.displayName ? { displayName: identity.displayName } : {}),
            emailVerified: identity.emailVerified,
          };
          const created = await client.query(
            `INSERT INTO users (
               id, email, password_hash, profile, email_verified_at,
               terms_accepted_at, privacy_accepted_at, minimum_age_confirmed_at,
               private_use_confirmed_at
             ) VALUES (
               $1, $2, NULL, $3::jsonb,
               CASE WHEN $4::boolean THEN now() ELSE NULL END,
               now(), now(), now(),
               CASE WHEN $5::boolean THEN now() ELSE NULL END
             )
             RETURNING *`,
            [
              userId,
              identity.email,
              JSON.stringify(profile),
              identity.emailVerified,
              req.body?.privateUseConfirmed === true,
            ],
          );
          user = created.rows[0];
          createdAccount = true;
          if (config.privatePilotV4Enabled) {
            await writePrivatePilotDeclaration(client, {
              userId,
              declarationType: 'account_private',
            });
          }
          await writeAudit(client, {
            actor: { id: user.id, role: user.role ?? 'user' },
            action: 'account.registered',
            resourceType: 'user',
            resourceId: user.id,
            requestId: req.requestId,
            metadata: { method: 'federated', provider: identity.provider },
          });
        }
        if (!createdAccount && (
          !user.terms_accepted_at
          || !user.privacy_accepted_at
          || !user.minimum_age_confirmed_at
          || (config.privatePilotV4Enabled && !user.private_use_confirmed_at)
        )) {
          if (!consentsAccepted) {
            throw new HttpError(400, 'social_registration_consents_required');
          }
          const consented = await client.query(
            `UPDATE users
             SET terms_accepted_at = COALESCE(terms_accepted_at, now()),
                 privacy_accepted_at = COALESCE(privacy_accepted_at, now()),
                 minimum_age_confirmed_at = COALESCE(minimum_age_confirmed_at, now()),
                 private_use_confirmed_at = CASE
                   WHEN $2::boolean THEN COALESCE(private_use_confirmed_at, now())
                   ELSE private_use_confirmed_at
                 END
             WHERE id = $1 RETURNING *`,
            [user.id, req.body?.privateUseConfirmed === true],
          );
          if (config.privatePilotV4Enabled && !user.private_use_confirmed_at) {
            await writePrivatePilotDeclaration(client, {
              userId: user.id,
              declarationType: 'account_private',
            });
          }
          user = consented.rows[0];
        }
        await client.query(
          `INSERT INTO auth_identities (
             user_id, provider, provider_subject, firebase_user_id, email_at_link,
             email_verified, last_login_at
           ) VALUES ($1, $2, $3, $4, $5, $6, now())`,
          [
            user.id,
            identity.provider,
            identity.subject,
            identity.firebaseUserId,
            identity.email,
            identity.emailVerified,
          ],
        );
      }
      if (user.deactivated_at || user.account_status !== 'active') {
        throw new HttpError(403, 'account_not_active');
      }
      if (!user.terms_accepted_at
          || !user.privacy_accepted_at
          || !user.minimum_age_confirmed_at
          || (config.privatePilotV4Enabled && !user.private_use_confirmed_at)) {
        if (!consentsAccepted) {
          throw new HttpError(400, 'social_registration_consents_required');
        }
        const consented = await client.query(
          `UPDATE users
           SET terms_accepted_at = COALESCE(terms_accepted_at, now()),
               privacy_accepted_at = COALESCE(privacy_accepted_at, now()),
               minimum_age_confirmed_at = COALESCE(minimum_age_confirmed_at, now()),
               private_use_confirmed_at = CASE
                 WHEN $2::boolean THEN COALESCE(private_use_confirmed_at, now())
                 ELSE private_use_confirmed_at
               END
           WHERE id = $1 RETURNING *`,
          [user.id, req.body?.privateUseConfirmed === true],
        );
        if (config.privatePilotV4Enabled && !user.private_use_confirmed_at) {
          await writePrivatePilotDeclaration(client, {
            userId: user.id,
            declarationType: 'account_private',
          });
        }
        user = consented.rows[0];
      }
      if (!user.email_verified_at
          && identity.emailVerified
          && user.email === identity.email) {
        const verified = await client.query(
          `UPDATE users
           SET email_verified_at = now(),
               profile = jsonb_set(profile, '{emailVerified}', 'true'::jsonb, true)
           WHERE id = $1 RETURNING *`,
          [user.id],
        );
        user = verified.rows[0];
      }
      await client.query(
        `UPDATE auth_identities
         SET firebase_user_id = $3,
             email_at_link = $4,
             email_verified = email_verified OR $5,
             last_login_at = now()
         WHERE provider = $1 AND provider_subject = $2`,
        [
          identity.provider,
          identity.subject,
          identity.firebaseUserId,
          identity.email,
          identity.emailVerified,
        ],
      );
      if (!user.email_verified_at) {
        return { verificationUser: user, session: null };
      }
      const issued = await issueSession(client, user, {
        userAgent: req.get('user-agent'),
        ipAddress: requestIp(req),
      });
      await writeAudit(client, {
        actor: { id: user.id, role: user.role ?? 'user' },
        action: 'auth.social_login',
        resourceType: 'auth_session',
        resourceId: issued.sessionId,
        requestId: req.requestId,
        metadata: {
          provider: identity.provider,
          createdAccount,
          linkedExistingAccount,
        },
      });
      return { verificationUser: null, session: issued };
    });
    if (outcome.verificationUser) {
      try {
        await createAndSendVerification(outcome.verificationUser);
      } catch (error) {
        console.error('[auth] social verification delivery failed', error?.code ?? error?.message ?? error);
      }
      return res.status(202).json({
        accepted: true,
        verificationEmailSent: true,
        email: outcome.verificationUser.email,
      });
    }
    return res.json(outcome.session);
  }));

  app.get('/v1/payments/connect/return', (req, res) => sendHtml(res, 200, resultPage({
    title: req.query.state === 'complete' ? 'Auszahlungskonto aktualisiert' : 'Auszahlungskonto fortsetzen',
    message: 'Kehre zur ShareItToo-App zurück. Der Kontostatus wird dort sicher neu geladen.',
    success: req.query.state === 'complete',
  })));

  app.get('/v1/payments/connect/status', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    res.json({ account: await getConnectStatus(req.actor.id) });
  }));

  app.post('/v1/admin/step-up', requireAuth, requireActiveAccount, staffElevationLimiter, asyncRoute(async (req, res) => {
    const elevation = await inTransaction((client) => createStaffElevation(client, {
      actor: req.actor,
      sessionId: req.auth.sessionId,
      currentPassword: req.body?.currentPassword,
    }));
    res.json({ elevation });
  }));

  app.post('/v1/payments/connect/onboarding', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await createConnectOnboarding({
      actor: req.actor,
      raw: req.body,
      key: req.get('Idempotency-Key'),
    });
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.get('/v1/bookings/:id/payment', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    res.json(await getBookingPayment({ actor: req.actor, bookingId: safeText(req.params.id, 120) }));
  }));

  app.post('/v1/bookings/:id/payment/checkout', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await createPaymentCheckout({
      actor: req.actor,
      bookingId: safeText(req.params.id, 120),
      key: req.get('Idempotency-Key'),
    });
    kickNotificationWorker();
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.post('/v1/payments/:id/simulate', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await simulatePaymentEvent({
      actor: req.actor,
      paymentId: safeText(req.params.id, 80),
      scenario: safeText(req.body?.scenario, 40),
      duplicate: req.body?.duplicate === true,
    });
    kickNotificationWorker();
    res.json(result);
  }));

  app.post('/v1/payments/:id/refunds', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    const result = await refundPayment({
      actor: req.actor,
      paymentId: safeText(req.params.id, 80),
      amountMinor: req.body?.amountMinor,
      reason: req.body?.reason,
      key: req.get('Idempotency-Key'),
    });
    kickNotificationWorker();
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.post('/v1/payments/:id/payout-release', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    const result = await releasePayout({
      actor: req.actor,
      paymentId: safeText(req.params.id, 80),
      key: req.get('Idempotency-Key'),
    });
    kickNotificationWorker();
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.post('/v1/auth/login', loginLimiter, asyncRoute(async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    const password = req.body?.password;
    if (!isValidEmail(email) || typeof password !== 'string') throw new HttpError(401, 'invalid_credentials');
    await reconcileExpiredAccountSuspension(email);
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
        await revokeSessionByRefreshToken(client, refreshToken);
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

  app.get('/v1/auth/phone-verification/status', requireAuth, requireActiveAccount, (_req, res) => {
    res.set('Cache-Control', 'no-store').json({
      available: config.phoneVerification.enabled,
      provider: config.phoneVerification.enabled ? 'firebase-phone' : null,
    });
  });

  app.post('/v1/auth/phone-verification/confirm', requireAuth, requireActiveAccount, phoneVerificationLimiter, asyncRoute(async (req, res) => {
    if (!config.phoneVerification.enabled) {
      throw new HttpError(503, 'phone_verification_unavailable');
    }
    const requestedPhone = normalizePhoneE164(req.body?.phoneNumber);
    if (!requestedPhone) throw new HttpError(400, 'invalid_phone');
    const verified = await verifyPhoneToken(req.body?.firebaseIdToken);
    // Phone authentication is used only as a possession proof. Consume the
    // provider identity before storing the result, and refuse to delete an
    // identity that is linked to any durable login provider.
    await deletePhoneIdentity(verified);
    if (verified.phoneNumber !== requestedPhone) {
      throw new HttpError(422, 'phone_verification_mismatch');
    }
    let outcome;
    try {
      outcome = await inTransaction(async (client) => {
        const current = await client.query(
          `SELECT * FROM users
           WHERE id = $1 AND deactivated_at IS NULL AND account_status = 'active'
           FOR UPDATE`,
          [req.auth.userId],
        );
        if (!current.rowCount) throw new HttpError(404, 'user_not_found');
        const conflict = await client.query(
          `SELECT 1 FROM users
           WHERE phone_e164 = $1 AND phone_verified_at IS NOT NULL AND id <> $2
           LIMIT 1`,
          [verified.phoneNumber, req.auth.userId],
        );
        if (conflict.rowCount) throw new HttpError(409, 'phone_already_verified');
        const updated = await client.query(
          `UPDATE users
           SET phone_e164 = $2,
               phone_verified_at = COALESCE(
                 CASE WHEN phone_e164 = $2 THEN phone_verified_at END,
                 now()
               ),
               profile = jsonb_set(
                 jsonb_set(profile, '{phone}', to_jsonb($2::text), true),
                 '{phoneVerified}', 'true'::jsonb, true
               )
           WHERE id = $1
           RETURNING *`,
          [req.auth.userId, verified.phoneNumber],
        );
        await writeAudit(client, {
          actor: req.actor,
          action: 'auth.phone_verified',
          resourceType: 'user',
          resourceId: req.auth.userId,
          requestId: req.requestId,
          metadata: { provider: 'firebase-phone' },
        });
        return updated.rows[0];
      });
    } catch (error) {
      if (error?.code === '23505' && error?.constraint === 'users_verified_phone_unique_idx') {
        throw new HttpError(409, 'phone_already_verified');
      }
      throw error;
    }
    publishToUsers([req.auth.userId], { type: 'changed', resource: 'profiles' });
    res.json({ verified: true, user: shapeUser(outcome) });
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

  app.delete('/v1/auth/devices/push/current', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const deletedCount = await inTransaction(async (client) => {
      const count = await deletePushDevicesForSession(client, {
        sessionId: req.auth.sessionId,
        userId: req.auth.userId,
      });
      await writeAudit(client, {
        actor: req.actor,
        action: 'push.current_session_devices_deleted',
        resourceType: 'auth_session',
        resourceId: req.auth.sessionId,
        metadata: { deletedCount: count },
      });
      return count;
    });
    res.json({ deletedCount });
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

  app.get('/v1/account/export', requireAuth, requireActiveAccount, exportLimiter, asyncRoute(async (req, res) => {
    const document = await inTransaction(async (client) => {
      await client.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
      await writeAudit(client, {
        actor: req.actor,
        action: 'account.data_exported',
        resourceType: 'user',
        resourceId: req.auth.userId,
        requestId: req.requestId,
      });
      const data = await buildAccountExport(client, req.auth.userId);
      if (!data) throw new HttpError(404, 'user_not_found');
      return {
        schemaVersion: '1.0',
        generatedAt: new Date().toISOString(),
        accountId: req.auth.userId,
        data,
      };
    });
    res.set({
      'Cache-Control': 'private, no-store',
      'Content-Disposition': 'attachment; filename="shareittoo-data-export.json"',
      'X-Content-Type-Options': 'nosniff',
    }).json(document);
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
    await attemptFirebaseIdentityDeletion(outcome.firebaseIdentityDeletionIds);
    res.json({ deleted: true });
  }));

  // The public store-facing information page is read-only and already covered
  // by the general limiter. Only actions that create or consume deletion
  // tokens use the stricter deletion limiter; otherwise three harmless page
  // views could lock an entire shared IP out of the required public page.
  app.get('/v1/account-deletion', (_req, res) => {
    sendHtml(res, 200, accountDeletionRequestForm({ submitted: false }));
  });

  app.get('/v1/public/compliance', (_req, res) => {
    res.set({
      'Cache-Control': 'no-store',
      'X-SIT-Compliance-Status': config.publicCompliance.approved ? 'approved' : 'draft',
    }).json(publicComplianceOverview());
  });

  app.get('/v1/public/support', (_req, res) => {
    const approved = config.publicCompliance.approved;
    res.set('X-SIT-Compliance-Status', approved ? 'approved' : 'draft');
    sendHtml(res, approved ? 200 : 503, publicSupportPage());
  });

  app.get('/v1/public/privacy', (_req, res) => {
    const approved = config.publicCompliance.approved;
    res.set('X-SIT-Compliance-Status', approved ? 'approved' : 'draft');
    sendHtml(res, approved ? 200 : 503, publicPrivacyPage());
  });

  app.get('/v1/public/imprint', (_req, res) => {
    const approved = config.publicCompliance.approved;
    res.set('X-SIT-Compliance-Status', approved ? 'approved' : 'draft');
    sendHtml(res, approved ? 200 : 503, publicImprintPage());
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
      await attemptFirebaseIdentityDeletion(outcome.firebaseIdentityDeletionIds);
      return sendHtml(res, 200, resultPage({
        success: true,
        title: 'Konto gelöscht',
        message: 'Dein ShareItToo-Konto wurde geschlossen und deine personenbezogenen Daten wurden gelöscht oder anonymisiert.',
      }));
    } catch (error) {
      if (error instanceof HttpError && error.code === 'account_deletion_blocked') {
        return sendHtml(res, 409, accountDeletionConfirmForm({
          token,
          error: 'Die Löschung ist aktuell wegen einer offenen Buchung, Zahlung, Auszahlung, eines Streitfalls, Moderationsfalls oder einer rechtlichen Aufbewahrungssperre blockiert. Bitte kläre den Vorgang zuerst in der App oder mit dem Support.',
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

  app.get('/v1/listings', asyncRoute(async (req, res) => {
    const search = parseCatalogQuery(req.query);
    const query = buildCatalogSearch(search);
    const result = await pool.query(query.text, query.values);
    const hasMore = result.rows.length > search.limit;
    const rows = hasMore ? result.rows.slice(0, search.limit) : result.rows;
    res.json({
      listings: rows.map(publicListingFromRow),
      page: {
        limit: search.limit,
        offset: search.offset,
        count: rows.length,
        hasMore,
      },
    });
  }));

  app.get('/v1/listings/mine', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await pool.query(
      `SELECT payload FROM listings WHERE owner_id = $1 ORDER BY created_at DESC LIMIT 500`,
      [req.auth.userId],
    );
    res.json({ listings: result.rows.map((row) => row.payload) });
  }));

  app.post('/v1/listings', requireAuth, requireActiveAccount, requireUnsuspendedScope('listing'), asyncRoute(async (req, res) => {
    const id = identifier(req.body?.id === 'new' ? '' : req.body?.id, 'listing');
    const payload = listingPayload(req.body, { id, ownerId: req.auth.userId });
    const financials = listingFinancials(payload);
    const projection = listingProjectionValues(payload);
    const result = await inTransaction(async (client) => {
      const inserted = await client.query(
        `INSERT INTO listings (
           id, owner_id, payload, currency, price_per_day_minor,
           security_deposit_minor, catalog_version, catalog_revision,
           status, is_active, title, description,
           category_id, subcategory, condition, location_text, city, country,
           latitude, longitude, min_days, max_days, handover_radius_km,
           protection_model, published_at, ended_at, created_at
         )
         VALUES (
           $1, $2, $3::jsonb, $4, $5, $6, 1, 1,
           $7, $8, $9, $10, $11, $12, $13, $14, $15, $16,
           $17, $18, $19, $20, $21, $22, $23::timestamptz,
           $24::timestamptz, $25::timestamptz
         )
         RETURNING payload`,
        [
          id,
          req.auth.userId,
          JSON.stringify(payload),
          financials.currency,
          financials.pricePerDayMinor,
          financials.securityDepositMinor,
          ...projection,
          payload.createdAt,
        ],
      );
      await bindListingUploads(client, {
        listingId: id,
        ownerId: req.auth.userId,
        photos: payload.photos,
        requirePhoto: payload.status === 'active',
      });
      if (config.privatePilotV4Enabled) {
        await client.query(
          'UPDATE listings SET private_status_confirmed_at = now() WHERE id = $1',
          [id],
        );
        await writePrivatePilotDeclaration(client, {
          userId: req.auth.userId,
          listingId: id,
          declarationType: 'listing_private',
        });
      }
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

  app.put('/v1/listings/:id', requireAuth, requireActiveAccount, requireUnsuspendedScope('listing'), asyncRoute(async (req, res) => {
    const id = safeText(req.params.id, 120);
    const existing = await pool.query('SELECT * FROM listings WHERE id = $1', [id]);
    if (!existing.rowCount) throw new HttpError(404, 'listing_not_found');
    if (existing.rows[0].owner_id !== req.auth.userId) throw new HttpError(403, 'listing_forbidden');
    if (existing.rows[0].moderation_status !== 'active') {
      throw new HttpError(409, 'listing_locked_by_moderation');
    }
    const payload = listingPayload(req.body, {
      id,
      ownerId: req.auth.userId,
      existingCreatedAt: new Date(existing.rows[0].created_at).toISOString(),
      existingPayload: ensureObject(existing.rows[0].payload, 'invalid_stored_listing'),
    });
    const financials = listingFinancials(payload);
    const projection = listingProjectionValues(payload);
    const result = await inTransaction(async (client) => {
      const updated = await client.query(
        `UPDATE listings
         SET payload = $2::jsonb, currency = $3,
             price_per_day_minor = $4, security_deposit_minor = $5,
             catalog_version = 1, catalog_revision = catalog_revision + 1,
             status = $6, is_active = $7, title = $8, description = $9,
             category_id = $10, subcategory = $11, condition = $12,
             location_text = $13, city = $14, country = $15,
             latitude = $16, longitude = $17, min_days = $18,
             max_days = $19, handover_radius_km = $20,
             protection_model = $21,
             published_at = CASE WHEN $6 = 'active' THEN COALESCE(published_at, $22::timestamptz) ELSE published_at END,
             ended_at = $23::timestamptz
         WHERE id = $1
         RETURNING payload`,
        [
          id,
          JSON.stringify(payload),
          financials.currency,
          financials.pricePerDayMinor,
          financials.securityDepositMinor,
          ...projection,
        ],
      );
      await bindListingUploads(client, {
        listingId: id,
        ownerId: req.auth.userId,
        photos: payload.photos,
        requirePhoto: payload.status === 'active',
      });
      if (config.privatePilotV4Enabled) {
        await client.query(
          'UPDATE listings SET private_status_confirmed_at = now() WHERE id = $1',
          [id],
        );
        await writePrivatePilotDeclaration(client, {
          userId: req.auth.userId,
          listingId: id,
          declarationType: 'listing_private',
        });
      }
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

  app.patch('/v1/listings/:id/status', requireAuth, requireActiveAccount, requireUnsuspendedScope('listing'), asyncRoute(async (req, res) => {
    const id = safeText(req.params.id, 120);
    const status = safeText(req.body?.status, 30);
    if (!['active', 'paused', 'ended'].includes(status)) throw new HttpError(400, 'invalid_listing_status');
    const isActive = status === 'active';
    const result = await inTransaction(async (client) => {
      if (isActive) {
        const media = await client.query(
          `SELECT 1 FROM uploads
           WHERE listing_id = $1 AND owner_id = $2
             AND purpose = 'listing_image'
             AND content_scan_status = 'passed'
           LIMIT 1`,
          [id, req.auth.userId],
        );
        if (!media.rowCount) throw new HttpError(400, 'listing_photo_required');
      }
      const updated = await client.query(
        `UPDATE listings
         SET is_active = $3,
             catalog_revision = catalog_revision + 1,
             status = $4,
             published_at = CASE WHEN $4 = 'active' THEN COALESCE(published_at, now()) ELSE published_at END,
             ended_at = CASE WHEN $4 = 'ended' THEN now() ELSE NULL END,
             payload = jsonb_set(
               jsonb_set(
                 jsonb_set(payload, '{isActive}', to_jsonb($3::boolean)),
                 '{status}', to_jsonb($4::text)
               ),
               '{endedAt}',
               CASE WHEN $4 = 'ended' THEN to_jsonb(now()::text) ELSE 'null'::jsonb END
             )
         WHERE id = $1 AND owner_id = $2 AND catalog_version = 1
           AND moderation_status = 'active'
         RETURNING payload`,
        [id, req.auth.userId, isActive, status],
      );
      if (updated.rowCount) {
        await writeAudit(client, {
          actor: req.actor,
          action: `listing.${status}`,
          resourceType: 'listing',
          resourceId: id,
        });
      }
      return updated;
    });
    if (!result.rowCount) throw new HttpError(404, 'listing_not_found');
    publishToAll({ type: 'changed', resource: 'listings' });
    res.json({ listing: result.rows[0].payload });
  }));

  app.delete('/v1/listings/:id', requireAuth, requireActiveAccount, requireUnsuspendedScope('listing'), asyncRoute(async (req, res) => {
    const id = safeText(req.params.id, 120);
    const result = await inTransaction(async (client) => {
      const updated = await client.query(
        `UPDATE listings
         SET is_active = false,
             catalog_revision = catalog_revision + 1,
             status = 'ended',
             ended_at = now(),
             payload = jsonb_set(
               jsonb_set(
                 jsonb_set(payload, '{isActive}', 'false'::jsonb),
                 '{status}', '"ended"'::jsonb
               ),
               '{endedAt}', to_jsonb(now()::text)
             )
         WHERE id = $1 AND owner_id = $2 AND status <> 'ended'
           AND moderation_status = 'active'
         RETURNING id`,
        [id, req.auth.userId],
      );
      if (updated.rowCount) {
        await writeAudit(client, {
          actor: req.actor,
          action: 'listing.ended',
          resourceType: 'listing',
          resourceId: id,
        });
      }
      return updated;
    });
    if (!result.rowCount) throw new HttpError(404, 'listing_not_found');
    publishToAll({ type: 'changed', resource: 'listings' });
    res.status(204).end();
  }));

  app.get('/v1/listings/:id/availability', asyncRoute(async (req, res) => {
    const now = new Date();
    const defaultFrom = now.toISOString().slice(0, 10);
    const defaultTo = new Date(Date.UTC(
      now.getUTCFullYear() + 1,
      now.getUTCMonth(),
      now.getUTCDate(),
    )).toISOString().slice(0, 10);
    const availability = await inTransaction((client) => getListingAvailability(client, {
      listingId: safeText(req.params.id, 120),
      fromDate: safeText(req.query.from, 10) || defaultFrom,
      toDate: safeText(req.query.to, 10) || defaultTo,
    }));
    res.json({ availability });
  }));

  app.post('/v1/listings/:id/availability/check', asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => checkListingAvailability(client, {
      listingId: safeText(req.params.id, 120),
      raw: req.body,
    }));
    res.status(result.available ? 200 : 409).json(result);
  }));

  app.put('/v1/listings/:id/availability', requireAuth, requireActiveAccount, requireUnsuspendedScope('listing'), asyncRoute(async (req, res) => {
    assertBookingPilot(config);
    const result = await inTransaction((client) => replaceListingAvailability(client, {
      actor: req.actor,
      listingId: safeText(req.params.id, 120),
      raw: req.body,
    }));
    publishToAll({ type: 'changed', resource: 'listing_availability', listingId: safeText(req.params.id, 120) });
    res.json(result);
  }));

  app.post('/v1/bookings/quote', requireAuth, requireActiveAccount, requireUnsuspendedScope('booking'), asyncRoute(async (req, res) => {
    const quote = await inTransaction((client) => quoteBooking(client, {
      actorId: req.auth.userId,
      raw: req.body,
      privatePilot: config.privatePilotV4Enabled,
    }));
    const contractDocumentsAvailable = config.payments.transport === 'stripe'
      ? (await inTransaction((client) => v51ContractDocumentReadiness(client))).ready
      : false;
    res.json({
      ...quote,
      contractDocumentsAvailable,
      paymentMethodAvailable: config.payments.transport === 'stripe'
        && contractDocumentsAvailable,
    });
  }));

  app.post('/v1/bookings', requireAuth, requireActiveAccount, requireUnsuspendedScope('booking'), asyncRoute(async (req, res) => {
    assertBookingPilot(config);
    const result = await inTransaction((client) => createBooking(client, {
      actor: req.actor,
      raw: req.body,
      key: req.get('Idempotency-Key'),
      privatePilot: config.privatePilotV4Enabled,
      appVersion: releaseMetadata.version,
    }), { deadlockRetries: 2 });
    publishToUsers([result.booking.ownerId, result.booking.renterId], {
      type: 'changed',
      resource: 'rental_requests',
    });
    kickNotificationWorker();
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.patch('/v1/bookings/:id', requireAuth, requireActiveAccount, requireUnsuspendedScope('booking'), asyncRoute(async (req, res) => {
    assertBookingPilot(config);
    const result = await inTransaction((client) => amendBooking(client, {
      actor: req.actor,
      bookingId: safeText(req.params.id, 120),
      raw: req.body,
      key: req.get('Idempotency-Key'),
    }), { deadlockRetries: 2 });
    publishToUsers([result.booking.ownerId, result.booking.renterId], {
      type: 'changed',
      resource: 'rental_requests',
    });
    kickNotificationWorker();
    res.json(result);
  }));

  app.get('/v1/bookings/:id/flow-time', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const state = await getBookingFlowTime(pool, {
      actorId: req.auth.userId,
      bookingId: safeText(req.params.id, 120),
    });
    res.json({ state });
  }));

  app.get('/v1/platform-contracts/:id/receipt', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    let receipt;
    try {
      receipt = await inTransaction((client) => getV51ContractReceipt(client, {
        userId: req.auth.userId,
        contractId: safeText(req.params.id, 160),
      }));
    } catch (error) {
      if (error instanceof V51ContractReceiptError) {
        const status = error.code === 'v51_receipt_not_found' ? 404 : 409;
        throw new HttpError(status, error.code);
      }
      throw error;
    }
    res.set({
      'Content-Type': 'text/html; charset=utf-8',
      'Content-Disposition': 'attachment; filename="shareittoo-plattformvertrag.html"',
      'Cache-Control': 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
      'X-SIT-Artifact-SHA256': receipt.artifactSha256,
    });
    res.send(receipt.contentHtml);
  }));

  app.get('/v1/financial-documents', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    try {
      const documents = await inTransaction((client) => listFinancialDocuments(client, {
        actorId: req.auth.userId,
        legalConfig: config.financialDocuments,
      }));
      res.json({ documents });
    } catch (error) {
      if (error instanceof FinancialDocumentError) {
        throw new HttpError(error.status, error.code);
      }
      throw error;
    }
  }));

  app.get('/v1/financial-documents/:id/artifact', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    let artifact;
    try {
      artifact = await inTransaction((client) => getFinancialDocumentArtifact(client, {
        actorId: req.auth.userId,
        documentId: safeText(req.params.id, 160),
      }));
    } catch (error) {
      if (error instanceof FinancialDocumentError) {
        throw new HttpError(error.status, error.code);
      }
      throw error;
    }
    res.set({
      'Content-Type': 'text/html; charset=utf-8',
      'Content-Disposition': `attachment; filename="${artifact.documentNumber}.html"`,
      'Cache-Control': 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
      'X-SIT-Artifact-SHA256': artifact.artifactSha256,
    });
    res.send(artifact.contentHtml);
  }));

  app.post('/v1/bookings/:id/flow-time', requireAuth, requireActiveAccount, requireUnsuspendedScope('booking'), asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => updateBookingFlowTime(client, {
      actor: req.actor,
      bookingId: safeText(req.params.id, 120),
      raw: req.body,
      idempotencyKey: req.get('Idempotency-Key'),
    }));
    publishToUsers(result.participantUserIds, {
      type: 'changed',
      resource: 'rental_requests',
    });
    res.status(result.replayed ? 200 : 201).json({ state: result.state, replayed: result.replayed });
  }));

  app.post('/v1/bookings/:id/confirmation-challenges', requireAuth, requireActiveAccount, requireUnsuspendedScope('booking'), confirmationLimiter, asyncRoute(async (req, res) => {
    assertBookingPilot(config);
    const challenge = await inTransaction((client) => issueBookingConfirmationChallenge(client, {
      actor: req.actor,
      bookingId: safeText(req.params.id, 120),
      raw: req.body,
      secret: config.jwtSecret,
    }));
    res.status(201).json({ challenge });
  }));

  app.get('/v1/bookings/:id/condition-evidence', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const summary = await inTransaction((client) => getConditionEvidenceSummary(client, {
      actor: req.actor,
      bookingId: safeText(req.params.id, 120),
      rawSegment: req.query.segment,
    }));
    res.json({ summary });
  }));

  app.post('/v1/bookings/:id/condition-confirmations', requireAuth, requireActiveAccount, requireUnsuspendedScope('booking'), asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => recordConditionConfirmation(client, {
      actor: req.actor,
      bookingId: safeText(req.params.id, 120),
      raw: req.body,
    }));
    publishToUsers(result.participantUserIds, {
      type: 'changed',
      resource: 'rental_requests',
    });
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.post('/v1/bookings/:id/confirmation-challenges/verify', requireAuth, requireActiveAccount, requireUnsuspendedScope('booking'), confirmationLimiter, asyncRoute(async (req, res) => {
    assertBookingPilot(config);
    const outcome = await inTransaction((client) => verifyBookingConfirmationChallenge(client, {
      actor: req.actor,
      bookingId: safeText(req.params.id, 120),
      raw: req.body,
      secret: config.jwtSecret,
    }));
    if (outcome.rejected) {
      throw new HttpError(400, outcome.code, {
        attemptsRemaining: outcome.attemptsRemaining,
      });
    }
    publishToUsers(outcome.participantUserIds, {
      type: 'changed',
      resource: 'rental_requests',
    });
    res.json(outcome);
  }));

  app.post('/v1/bookings/:id/transitions', requireAuth, requireActiveAccount, requireUnsuspendedScope('booking'), asyncRoute(async (req, res) => {
    assertBookingPilot(config);
    const result = await inTransaction((client) => transitionBooking(client, {
      actor: req.actor,
      bookingId: safeText(req.params.id, 120),
      raw: req.body,
      key: req.get('Idempotency-Key'),
      config,
    }), { deadlockRetries: 2 });
    publishToUsers([result.booking.ownerId, result.booking.renterId], {
      type: 'changed',
      resource: 'rental_requests',
    });
    kickNotificationWorker();
    res.json(result);
  }));

  app.post('/v1/platform-contracts/withdrawal', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => recordV51Withdrawal(client, {
      actor: req.actor,
      raw: { ...req.body, scope: 'account_contract' },
      idempotencyKey: req.get('Idempotency-Key'),
    }));
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.post('/v1/bookings/:id/withdrawal', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => recordV51Withdrawal(client, {
      actor: req.actor,
      bookingId: safeText(req.params.id, 120),
      raw: { ...req.body, scope: 'booking_contract' },
      idempotencyKey: req.get('Idempotency-Key'),
    }), { deadlockRetries: 2 });
    if (result.booking) {
      publishToUsers([result.booking.ownerId, result.booking.renterId], {
        type: 'changed',
        resource: 'rental_requests',
      });
      kickNotificationWorker();
    }
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.get('/v1/withdrawals/:id/receipt', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const receipt = await inTransaction((client) => getV51WithdrawalReceipt(client, {
      actorId: req.auth.userId,
      withdrawalId: safeText(req.params.id, 160),
    }));
    res.set({
      'Content-Type': 'text/html; charset=utf-8',
      'Content-Disposition': 'attachment; filename="shareittoo-widerrufsbestaetigung.html"',
      'Cache-Control': 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
      'X-SIT-Artifact-SHA256': receipt.artifactSha256,
    });
    res.send(receipt.contentHtml);
  }));

  app.get('/v1/rental-requests', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const requests = await inTransaction((client) => listRentalRequests(client, req.auth.userId));
    res.json({ requests });
  }));

  app.put('/v1/rental-requests/sync', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    if (!Array.isArray(req.body?.requests) || req.body.requests.length > 500) throw new HttpError(400, 'invalid_requests');
    const participants = new Set([req.auth.userId]);
    const requests = await inTransaction(async (client) => {
      for (const raw of req.body.requests) {
        const candidate = ensureObject(raw, 'invalid_request');
        const id = identifier(candidate.id, 'request');
        const existingResult = await client.query(
          `SELECT request.*, booking.status AS booking_status,
                  booking.workflow_version AS booking_workflow_version,
                  booking.workflow_revision AS booking_workflow_revision
           FROM rental_requests AS request
           LEFT JOIN bookings AS booking ON booking.id = request.id
           WHERE request.id = $1
           FOR UPDATE OF request`,
          [id],
        );
        if (!existingResult.rowCount) {
          if (config.bookingPilotEnabled) {
            throw new HttpError(409, 'booking_creation_requires_idempotent_endpoint');
          }
          const itemId = safeText(candidate.itemId, 120);
          const listingResult = await client.query(
            `SELECT owner_id, currency
             FROM listings
             WHERE id = $1 AND catalog_version = 1 AND is_active = true`,
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
              0,
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
        if (config.bookingPilotEnabled) {
          if (Number(existing.booking_workflow_version) !== 1) {
            throw new HttpError(409, 'booking_requires_b6_revalidation');
          }
          const storedPayload = ensureObject(existing.payload, 'invalid_stored_request');
          const opensReturnCase = config.privatePilotV4Enabled
            && payload.needsReview === true
            && storedPayload.needsReview !== true;
          const storedStart = new Date(storedPayload.start).toISOString();
          const storedEnd = new Date(storedPayload.end).toISOString();
          if (payload.status !== existing.status) {
            throw new HttpError(409, 'booking_transition_requires_idempotent_endpoint');
          }
          if (payload.start !== storedStart || payload.end !== storedEnd) {
            throw new HttpError(409, 'booking_amendment_requires_quote');
          }
          payload.workflowVersion = 1;
          payload.workflowRevision = Number(existing.booking_workflow_revision);
          await client.query(
            `UPDATE rental_requests SET payload = $2::jsonb WHERE id = $1`,
            [id, JSON.stringify(payload)],
          );
          if (config.privatePilotV4Enabled) {
            await client.query(
              `UPDATE bookings
               SET return_t0 = $2, return_state = $3,
                   return_report_deadline = $4,
                   return_clarification_deadline = $5,
                   payout_instruction_due_at = $6,
                   version = version + 1
               WHERE id = $1`,
              [
                id,
                payload.returnT0 ?? null,
                payload.returnState ?? 'not_started',
                payload.returnReportDeadline ?? null,
                payload.returnClarificationDeadline ?? null,
                payload.payoutInstructionDueAt ?? null,
              ],
            );
            if (opensReturnCase) {
              await client.query(
                `INSERT INTO booking_cases (
                   booking_id, opened_by, opened_at, reason, substantiated,
                   status, contested_authorized_minor,
                   undisputed_releasable_minor, response_due_at,
                   next_status_update_due_at, metadata
                 )
                 SELECT $1, $2, $3, $4, true, 'needsReview', $5, $6,
                        $3::timestamptz + interval '5 days',
                        $3::timestamptz + interval '7 days', $7::jsonb
                 WHERE NOT EXISTS (
                   SELECT 1 FROM booking_cases
                   WHERE booking_id = $1 AND status <> 'closed'
                 )`,
                [
                  id,
                  req.auth.userId,
                  payload.returnCaseOpenedAt,
                  payload.reviewReason,
                  payload.contestedAuthorizedMinor ?? 0,
                  Math.max(
                    0,
                    Number(payload.quotedTotalMinor ?? 0)
                      - Number(payload.contestedAuthorizedMinor ?? 0),
                  ),
                  JSON.stringify({
                    source: payload.reviewSource,
                    evidenceReferences: payload.reviewEvidenceReferences ?? [],
                  }),
                ],
              );
            }
          }
          await client.query(
            `INSERT INTO booking_events (
               booking_id, actor_id, event_type, from_status, to_status, metadata
             ) VALUES ($1, $2, 'booking.metadata_updated', $3, $3, '{}'::jsonb)`,
            [id, req.auth.userId, existing.status],
          );
          await writeAudit(client, {
            actor: req.actor,
            action: 'booking.metadata_updated',
            resourceType: 'booking',
            resourceId: id,
          });
          participants.add(existing.owner_id);
          participants.add(existing.renter_id);
          continue;
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
    res.json(await listCommunicationThreads(pool, {
      actorId: req.auth.userId,
      limit: req.query.limit,
      offset: req.query.offset,
      includeArchived: req.query.includeArchived === 'true',
    }));
  }));

  app.post('/v1/message-threads/booking/:bookingId', requireAuth, requireActiveAccount, requireUnsuspendedScope('messaging'), asyncRoute(async (req, res) => {
    const thread = await inTransaction((client) => ensureBookingThread(client, {
      bookingId: safeText(req.params.bookingId, 120),
      actorId: req.auth.userId,
    }));
    publishToUsers([thread.user1Id, thread.user2Id], { type: 'changed', resource: 'message_threads' });
    res.status(201).json({ thread });
  }));

  app.get('/v1/message-threads/:id/messages', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    res.json(await listThreadMessages(pool, {
      threadId: safeText(req.params.id, 120),
      actorId: req.auth.userId,
      limit: req.query.limit,
      before: req.query.before,
    }));
  }));

  app.post('/v1/message-threads/:id/messages', requireAuth, requireActiveAccount, requireUnsuspendedScope('messaging'), asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => sendThreadMessage(client, {
      threadId: safeText(req.params.id, 120),
      actor: req.actor,
      raw: req.body,
      idempotencyKey: req.get('Idempotency-Key'),
    }));
    publishToUsers([req.auth.userId, result.recipientId], { type: 'changed', resource: 'message_threads' });
    kickNotificationWorker();
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.post('/v1/message-threads/:id/read', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const count = await inTransaction((client) => markThreadRead(client, {
      threadId: safeText(req.params.id, 120),
      actorId: req.auth.userId,
    }));
    res.json({ readCount: count });
  }));

  app.patch('/v1/message-threads/:id', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    if (typeof req.body?.archived !== 'boolean') throw new HttpError(400, 'invalid_thread_update');
    const archivedForUserIds = await inTransaction((client) => setThreadArchived(client, {
      threadId: safeText(req.params.id, 120),
      actorId: req.auth.userId,
      archived: req.body.archived,
    }));
    res.json({ archivedForUserIds });
  }));

  app.post('/v1/reports', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => createReport(client, {
      actor: req.actor,
      raw: req.body,
      idempotencyKey: req.get('Idempotency-Key'),
    }));
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.get('/v1/reports/mine', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    res.json({ reports: await listMyReports(pool, req.auth.userId) });
  }));

  app.post('/v1/messages/:id/reports', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => createReport(client, {
      actor: req.actor,
      raw: {
        targetType: 'message',
        targetId: safeText(req.params.id, 120),
        reasonCode: req.body?.reasonCode,
        details: req.body?.details,
        evidenceUploadIds: req.body?.evidenceUploadIds,
      },
      idempotencyKey: req.get('Idempotency-Key'),
    }));
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.post('/v1/bookings/:id/reviews', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => createBookingReview(client, {
      actor: req.actor,
      bookingId: safeText(req.params.id, 120),
      raw: req.body,
    }));
    publishToUsers([result.review.reviewedUserId], { type: 'changed', resource: 'reviews' });
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.get('/v1/users/:id/reviews', asyncRoute(async (req, res) => {
    res.json({ reviews: await listPublishedReviews(pool, { revieweeId: safeText(req.params.id, 120) }) });
  }));

  app.get('/v1/listings/:id/reviews', asyncRoute(async (req, res) => {
    res.json({ reviews: await listPublishedReviews(pool, { listingId: safeText(req.params.id, 120) }) });
  }));

  app.get('/v1/bookings/:id/reviews', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const booking = await pool.query(
      'SELECT owner_id, renter_id FROM bookings WHERE id = $1',
      [safeText(req.params.id, 120)],
    );
    if (!booking.rowCount) throw new HttpError(404, 'booking_not_found');
    if (![booking.rows[0].owner_id, booking.rows[0].renter_id].includes(req.auth.userId)) {
      throw new HttpError(403, 'booking_forbidden');
    }
    res.json({ reviews: await listPublishedReviews(pool, { bookingId: safeText(req.params.id, 120) }) });
  }));

  app.get('/v1/user-blocks', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    res.json({ blocks: await listBlocks(pool, req.auth.userId) });
  }));

  app.put('/v1/user-blocks/:userId', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    await inTransaction((client) => blockUser(client, {
      actor: req.actor,
      blockedId: safeText(req.params.userId, 120),
      reasonCode: req.body?.reasonCode,
    }));
    res.status(204).end();
  }));

  app.delete('/v1/user-blocks/:userId', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    await inTransaction((client) => unblockUser(client, {
      actorId: req.auth.userId,
      blockedId: safeText(req.params.userId, 120),
    }));
    res.status(204).end();
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
        if (isNew && config.bookingPilotEnabled) {
          throw new HttpError(409, 'message_thread_requires_b7_endpoint');
        }
        if (!isNew && Number(existingResult.rows[0].communication_version ?? 0) === 1) {
          throw new HttpError(409, 'message_sync_requires_b7_endpoint');
        }
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

  app.get('/v1/notifications', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const limit = Math.min(100, Math.max(1, Number.parseInt(req.query.limit ?? '50', 10) || 50));
    const before = req.query.before && !Number.isNaN(Date.parse(req.query.before))
      ? new Date(req.query.before)
      : null;
    const includeArchived = req.query.includeArchived === 'true';
    const result = await pool.query(
      `SELECT * FROM notifications
       WHERE user_id = $1
         AND ($2::boolean OR archived_at IS NULL)
         AND ($3::timestamptz IS NULL OR created_at < $3)
       ORDER BY created_at DESC, id DESC
       LIMIT $4`,
      [req.auth.userId, includeArchived, before, limit],
    );
    const notifications = result.rows.map((row) => ({
      id: row.id,
      category: row.category,
      kind: row.kind,
      priority: row.priority,
      title: row.title,
      body: row.body,
      entityType: row.entity_type,
      entityId: row.entity_id,
      bookingId: row.booking_id,
      threadId: row.thread_id,
      requestId: row.payload?.requestId ?? row.booking_id,
      ctaLabel: row.payload?.ctaLabel ?? null,
      actionUrl: row.action_url,
      payload: row.payload ?? {},
      read: Boolean(row.read_at),
      archived: Boolean(row.archived_at),
      critical: row.priority === 3 && ['important', 'payments'].includes(row.category),
      ts: new Date(row.created_at).toISOString(),
    }));
    res.json({
      notifications,
      nextBefore: result.rowCount === limit ? notifications.at(-1)?.ts ?? null : null,
    });
  }));

  app.patch('/v1/notifications/:id', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    if (typeof req.body?.read !== 'boolean' && typeof req.body?.archived !== 'boolean') {
      throw new HttpError(400, 'invalid_notification_update');
    }
    const result = await pool.query(
      `UPDATE notifications
       SET read_at = CASE
             WHEN $3::boolean IS NULL THEN read_at
             WHEN $3::boolean THEN COALESCE(read_at, now())
             ELSE NULL
           END,
           archived_at = CASE
             WHEN $4::boolean IS NULL THEN archived_at
             WHEN $4::boolean AND NOT (priority = 3 AND category IN ('important', 'payments'))
               THEN COALESCE(archived_at, now())
             WHEN NOT $4::boolean THEN NULL
             ELSE archived_at
           END
       WHERE id::text = $1 AND user_id = $2
       RETURNING read_at, archived_at`,
      [safeText(req.params.id, 80), req.auth.userId, req.body.read ?? null, req.body.archived ?? null],
    );
    if (!result.rowCount) throw new HttpError(404, 'notification_not_found');
    res.json({ read: Boolean(result.rows[0].read_at), archived: Boolean(result.rows[0].archived_at) });
  }));

  app.post('/v1/notifications/read-all', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await pool.query(
      `UPDATE notifications SET read_at = COALESCE(read_at, now())
       WHERE user_id = $1 AND read_at IS NULL`,
      [req.auth.userId],
    );
    res.json({ readCount: result.rowCount });
  }));

  app.get('/v1/notification-preferences', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const result = await pool.query(
      `SELECT in_app_enabled, email_enabled, push_enabled,
              message_push_enabled, booking_push_enabled, locale
       FROM notification_preferences WHERE user_id = $1`,
      [req.auth.userId],
    );
    const row = result.rows[0] ?? {};
    res.json({
      preferences: {
        inAppEnabled: row.in_app_enabled ?? true,
        emailEnabled: row.email_enabled ?? true,
        pushEnabled: row.push_enabled ?? true,
        messagePushEnabled: row.message_push_enabled ?? true,
        bookingPushEnabled: row.booking_push_enabled ?? true,
        locale: row.locale ?? 'de-DE',
      },
    });
  }));

  app.put('/v1/notification-preferences', requireAuth, requireActiveAccount, asyncRoute(async (req, res) => {
    const locale = safeText(req.body?.locale, 20) || 'de-DE';
    const bool = (value, fallback = true) => typeof value === 'boolean' ? value : fallback;
    const values = {
      inApp: bool(req.body?.inAppEnabled),
      email: bool(req.body?.emailEnabled),
      push: bool(req.body?.pushEnabled),
      messagePush: bool(req.body?.messagePushEnabled),
      bookingPush: bool(req.body?.bookingPushEnabled),
    };
    const result = await pool.query(
      `INSERT INTO notification_preferences (
         user_id, in_app_enabled, email_enabled, push_enabled,
         message_push_enabled, booking_push_enabled, locale
       ) VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (user_id) DO UPDATE SET
         in_app_enabled = EXCLUDED.in_app_enabled,
         email_enabled = EXCLUDED.email_enabled,
         push_enabled = EXCLUDED.push_enabled,
         message_push_enabled = EXCLUDED.message_push_enabled,
         booking_push_enabled = EXCLUDED.booking_push_enabled,
         locale = EXCLUDED.locale,
         updated_at = now()
       RETURNING in_app_enabled, email_enabled, push_enabled,
                 message_push_enabled, booking_push_enabled, locale`,
      [req.auth.userId, values.inApp, values.email, values.push, values.messagePush, values.bookingPush, locale],
    );
    const row = result.rows[0];
    res.json({
      preferences: {
        inAppEnabled: row.in_app_enabled,
        emailEnabled: row.email_enabled,
        pushEnabled: row.push_enabled,
        messagePushEnabled: row.message_push_enabled,
        bookingPushEnabled: row.booking_push_enabled,
        locale: row.locale,
      },
    });
  }));

  app.get('/v1/admin/overview', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (_req, res) => {
    res.json({ overview: await staffOverview(pool) });
  }));

  app.get('/v1/admin/reports', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    res.json({ reports: await listStaffReports(pool, req.query) });
  }));

  app.get('/v1/admin/reports/:id', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    res.json({ report: await getStaffReport(pool, safeText(req.params.id, 80)) });
  }));

  app.patch('/v1/admin/reports/:id', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => updateStaffReport(client, {
      actor: req.actor,
      reportId: safeText(req.params.id, 80),
      raw: req.body,
      idempotencyKey: req.get('Idempotency-Key'),
    }));
    res.json(result);
  }));

  app.get('/v1/admin/users', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    res.json({ users: await listStaffUsers(pool, { ...req.query, role: req.actor.role }) });
  }));

  app.get('/v1/admin/listings', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    res.json({ listings: await listStaffListings(pool, req.query) });
  }));

  app.get('/v1/admin/bookings', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    res.json({ bookings: await listStaffBookings(pool, req.query) });
  }));

  app.get('/v1/admin/payments', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    res.json({ payments: await listStaffPayments(pool, req.query) });
  }));

  app.get('/v1/admin/audit', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    res.json({ audit: await listStaffAudit(pool, req.query) });
  }));

  app.get('/v1/admin/privacy/retention-inventory', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    const inventory = await inTransaction((client) => inspectRetentionInventory(client, { actor: req.actor }));
    res.json({ inventory });
  }));

  app.get('/v1/admin/legal-holds', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    res.json({ legalHolds: await listAccountLegalHolds(pool, { actor: req.actor, ...req.query }) });
  }));

  app.post('/v1/admin/users/:id/legal-holds', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => createAccountLegalHold(client, {
      actor: req.actor,
      userId: safeText(req.params.id, 120),
      raw: req.body,
      idempotencyKey: req.get('Idempotency-Key'),
    }));
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.post('/v1/admin/legal-holds/:id/release', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => releaseAccountLegalHold(client, {
      actor: req.actor,
      legalHoldId: safeText(req.params.id, 80),
      raw: req.body,
      idempotencyKey: req.get('Idempotency-Key'),
    }));
    res.json(result);
  }));

  app.post('/v1/admin/users/:id/suspensions', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => setUserSuspension(client, {
      actor: req.actor,
      userId: safeText(req.params.id, 120),
      raw: req.body,
      idempotencyKey: req.get('Idempotency-Key'),
    }));
    publishToUsers([safeText(req.params.id, 120)], { type: 'changed', resource: 'profiles' });
    res.status(result.replayed ? 200 : 201).json(result);
  }));

  app.post('/v1/admin/suspensions/:id/lift', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => liftUserSuspension(client, {
      actor: req.actor,
      suspensionId: safeText(req.params.id, 80),
      raw: req.body,
      idempotencyKey: req.get('Idempotency-Key'),
    }));
    publishToUsers([result.suspension.user_id], { type: 'changed', resource: 'profiles' });
    res.json(result);
  }));

  app.patch('/v1/admin/listings/:id/moderation', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    const result = await inTransaction((client) => setListingModeration(client, {
      actor: req.actor,
      listingId: safeText(req.params.id, 120),
      raw: req.body,
      idempotencyKey: req.get('Idempotency-Key'),
    }));
    publishToAll({ type: 'changed', resource: 'listings' });
    res.json(result);
  }));

  app.get('/v1/admin/evidence/:id', requireAuth, requireActiveAccount, requireStaffElevation, asyncRoute(async (req, res) => {
    const evidenceId = safeText(req.params.id, 80);
    const evidence = await inTransaction(async (client) => {
      const record = await getStaffEvidence(client, evidenceId);
      await writeAudit(client, {
        actor: req.actor,
        action: 'moderation.evidence_viewed',
        resourceType: 'upload',
        resourceId: evidenceId,
      });
      return record;
    });
    const contents = await fs.readFile(path.join(config.uploadDir, evidence.storage_name));
    res.set({
      'Content-Type': evidence.mime_type,
      'Content-Length': String(evidence.byte_size),
      'Cache-Control': 'private, no-store',
      'Content-Disposition': 'inline',
      'X-Content-Type-Options': 'nosniff',
    });
    res.send(contents);
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
      'report_evidence',
    ]);
    const purpose = safeText(req.body?.purpose, 40) || 'listing_image';
    if (!allowedPurposes.has(purpose)) throw new HttpError(400, 'invalid_upload_purpose');
    const listingId = safeText(req.body?.listingId, 120) || null;
    const threadId = safeText(req.body?.threadId, 120) || null;
    const visibility = purpose === 'profile_image' || (purpose === 'listing_image' && listingId)
      ? 'public'
      : 'private';

    if (listingId) {
      const listing = await pool.query(
        'SELECT owner_id FROM listings WHERE id = $1',
        [listingId],
      );
      if (!listing.rowCount) throw new HttpError(404, 'listing_not_found');
      if (listing.rows[0].owner_id !== req.auth.userId) throw new HttpError(403, 'upload_forbidden');
    }
    if (visibility === 'private' && !['listing_image', 'report_evidence'].includes(purpose)) {
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

    const processed = await sanitizeImage(req.file.buffer, { purpose });
    const storageStem = crypto.randomUUID();
    const storageName = `${storageStem}-full.${processed.extension}`;
    const thumbnailStorageName = `${storageStem}-thumb.${processed.extension}`;
    let uploadId = null;
    await fs.mkdir(config.uploadDir, { recursive: true });
    try {
      await Promise.all([
        fs.writeFile(path.join(config.uploadDir, storageName), processed.full, { flag: 'wx', mode: 0o640 }),
        fs.writeFile(path.join(config.uploadDir, thumbnailStorageName), processed.thumbnail, { flag: 'wx', mode: 0o640 }),
      ]);
      await inTransaction(async (client) => {
        const result = await client.query(
          `INSERT INTO uploads (
             owner_id, storage_name, mime_type, byte_size, purpose, visibility,
             listing_id, thread_id, thumbnail_storage_name,
             thumbnail_mime_type, thumbnail_byte_size, image_width, image_height,
             content_sha256, content_scan_status
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $3, $10, $11, $12, $13, 'passed')
           RETURNING id`,
          [
            req.auth.userId,
            storageName,
            processed.mimeType,
            processed.full.length,
            purpose,
            visibility,
            listingId,
            threadId,
            thumbnailStorageName,
            processed.thumbnail.length,
            processed.width,
            processed.height,
            processed.sha256,
          ],
        );
        uploadId = result.rows[0].id;
        await writeAudit(client, {
          actor: req.actor,
          action: 'upload.created',
          resourceType: 'upload',
          resourceId: result.rows[0].id,
          metadata: { purpose, visibility },
        });
      });
    } catch (error) {
      await Promise.all([
        fs.unlink(path.join(config.uploadDir, storageName)).catch(() => {}),
        fs.unlink(path.join(config.uploadDir, thumbnailStorageName)).catch(() => {}),
      ]);
      throw error;
    }
    res.status(201).json({
      id: uploadId,
      storageName,
      url: `${config.publicBaseUrl}/uploads/${storageName}`,
      thumbnailUrl: `${config.publicBaseUrl}/uploads/${thumbnailStorageName}`,
      width: processed.width,
      height: processed.height,
    });
  }));

  app.get('/v1/uploads/:storageName', asyncRoute(async (req, res) => {
    const storageName = safeText(req.params.storageName, 160);
    const result = await pool.query(
      `SELECT upload.*, thread.user1_id, thread.user2_id,
              listing.status AS listing_status,
              listing.is_active AS listing_is_active,
              listing.catalog_version AS listing_catalog_version
       FROM uploads AS upload
       LEFT JOIN message_threads AS thread ON thread.id = upload.thread_id
       LEFT JOIN listings AS listing ON listing.id = upload.listing_id
       WHERE upload.storage_name = $1 OR upload.thumbnail_storage_name = $1`,
      [storageName],
    );
    const uploadRecord = result.rows[0];
    if (!uploadRecord) throw new HttpError(404, 'upload_not_found');

    const publiclyReadable = uploadRecord.visibility === 'public'
      && (
        uploadRecord.purpose !== 'listing_image'
        || (
          uploadRecord.listing_catalog_version === 1
          && uploadRecord.listing_status === 'active'
          && uploadRecord.listing_is_active === true
        )
      );
    if (!publiclyReadable) {
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

    const isThumbnail = storageName === uploadRecord.thumbnail_storage_name;
    const requestedStorageName = isThumbnail ? uploadRecord.thumbnail_storage_name : uploadRecord.storage_name;
    const requestedMimeType = isThumbnail ? uploadRecord.thumbnail_mime_type : uploadRecord.mime_type;
    const requestedByteSize = isThumbnail ? uploadRecord.thumbnail_byte_size : uploadRecord.byte_size;
    const contents = await fs.readFile(path.join(config.uploadDir, requestedStorageName));
    res.set({
      'Content-Type': requestedMimeType,
      'Content-Length': String(requestedByteSize),
      'Cache-Control': publiclyReadable
        ? 'public, max-age=31536000, immutable'
        : 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    res.send(contents);
  }));

  app.use((req, res) => res.status(404).json(errorPayload(req, 'not_found')));
  app.use((error, req, res, _next) => {
    const uploadTooLarge = error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE';
    const invalidProcessedImage = error instanceof ImageProcessingError;
    const bookingConflict = error?.code === '23P01';
    const workflowError = error instanceof BookingWorkflowError;
    const flowTimeError = error instanceof BookingFlowTimeError;
    const messageWorkflowError = error instanceof MessageWorkflowError;
    const paymentWorkflowError = error instanceof PaymentDomainError;
    const moderationWorkflowError = error instanceof ModerationDomainError;
    const retentionInventoryError = error instanceof RetentionInventoryError;
    const mapsProxyError = error instanceof MapsProxyError;
    const bookingConfirmationError = error instanceof BookingConfirmationError;
    const v51WithdrawalError = error instanceof V51WithdrawalError;
    const status = bookingConflict
      ? 409
      : (uploadTooLarge
          ? 413
          : (invalidProcessedImage ? 422 : ((error instanceof HttpError || workflowError || flowTimeError || messageWorkflowError || paymentWorkflowError || moderationWorkflowError || retentionInventoryError || mapsProxyError || bookingConfirmationError || v51WithdrawalError || error instanceof PhoneVerificationError) ? error.status : (error?.status ?? 500))));
    const code = uploadTooLarge
      ? 'image_too_large'
      : (invalidProcessedImage
          ? error.code
          : (bookingConflict
          ? 'booking_period_unavailable'
          : ((error instanceof HttpError || workflowError || flowTimeError || messageWorkflowError || paymentWorkflowError || moderationWorkflowError || retentionInventoryError || mapsProxyError || bookingConfirmationError || v51WithdrawalError || error instanceof PhoneVerificationError) ? error.code : (status === 500 ? 'internal_error' : 'request_failed'))));
    if (status >= 500) console.error(safeErrorLog(req, status, code, error));
    res.status(status).json(errorPayload(req, code, error?.details));
  });

  return app;
}
