import {
  ModerationDomainError,
  moderationIdempotencyKey,
  moderationReviewDeadline,
  normalizeModerationDecisionInput,
  normalizeModerationReviewRequestInput,
} from './moderation_domain.js';

export class ModerationDecisionError extends ModerationDomainError {}

function text(value, maximum = 8000) {
  return typeof value === 'string' ? value.trim().slice(0, maximum) : '';
}

function decisionShape(row) {
  return Object.freeze({
    id: row.id,
    targetType: row.target_type,
    targetId: row.target_id,
    measureType: row.measure_type,
    measureState: row.measure_state,
    facts: row.facts,
    basis: row.basis,
    reasoning: row.reasoning,
    detectionMethod: row.detection_method,
    automatedMeans: row.automated_means ?? null,
    reviewAvailable: row.review_available === true,
    reviewDeadlineAt: row.review_deadline_at
      ? new Date(row.review_deadline_at).toISOString()
      : null,
    createdAt: new Date(row.created_at).toISOString(),
    reviewRequest: row.review_request_id
      ? Object.freeze({
          id: row.review_request_id,
          status: row.review_request_status,
          submittedAt: new Date(row.review_submitted_at).toISOString(),
          resolvedAt: row.review_resolved_at
            ? new Date(row.review_resolved_at).toISOString()
            : null,
          resolution: row.review_resolution ?? null,
        })
      : null,
  });
}

function reviewShape(row) {
  return Object.freeze({
    id: row.id,
    decisionId: row.decision_id,
    status: row.status,
    reason: row.reason,
    resolution: row.resolution ?? null,
    submittedAt: new Date(row.submitted_at).toISOString(),
    resolvedAt: row.resolved_at ? new Date(row.resolved_at).toISOString() : null,
  });
}

async function audit(client, { actor, action, resourceType, resourceId, metadata = {} }) {
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

export async function persistModerationDecision(client, {
  actor,
  recipientUserId,
  reportId = null,
  targetType,
  targetId,
  measureType,
  measureState,
  raw,
  idempotencyKey,
  issuedAt = new Date(),
}) {
  const decision = normalizeModerationDecisionInput(raw);
  const key = moderationIdempotencyKey(idempotencyKey, 'moderation.decision');
  const existing = await client.query(
    'SELECT * FROM moderation_decisions WHERE idempotency_key = $1',
    [key],
  );
  if (existing.rowCount) return { decision: decisionShape(existing.rows[0]), replayed: true };
  if (!['user', 'listing', 'review', 'message', 'report'].includes(targetType)) {
    throw new ModerationDecisionError(400, 'moderation_decision_target_invalid');
  }
  if (![
    'account_suspension',
    'scope_suspension',
    'listing_restriction',
    'private_marketplace_review',
    'report_resolution',
    'measure_reversal',
  ].includes(measureType)) {
    throw new ModerationDecisionError(400, 'moderation_decision_measure_invalid');
  }
  const recipient = await client.query(
    'SELECT id FROM users WHERE id = $1 AND deactivated_at IS NULL',
    [recipientUserId],
  );
  if (!recipient.rowCount) throw new ModerationDecisionError(404, 'moderation_decision_recipient_not_found');
  if (reportId) {
    const report = await client.query('SELECT id FROM reports WHERE id::text = $1', [reportId]);
    if (!report.rowCount) throw new ModerationDecisionError(404, 'report_not_found');
  }
  const deadline = moderationReviewDeadline(issuedAt);
  const inserted = await client.query(
    `INSERT INTO moderation_decisions (
       report_id, recipient_user_id, target_type, target_id,
       measure_type, measure_state, facts, basis, reasoning,
       detection_method, automated_means, review_available,
       review_deadline_at, issued_by, idempotency_key, created_at
     ) VALUES (
       $1::uuid, $2, $3, $4, $5, $6, $7, $8, $9,
       $10, $11, true, $12, $13, $14, $15
     ) RETURNING *`,
    [
      reportId,
      recipientUserId,
      targetType,
      targetId,
      measureType,
      text(measureState, 120),
      decision.facts,
      decision.basis,
      decision.reasoning,
      decision.detectionMethod,
      decision.automatedMeans,
      deadline,
      actor?.id ?? null,
      key,
      issuedAt,
    ],
  );
  await audit(client, {
    actor,
    action: 'moderation.decision_issued',
    resourceType: 'moderation_decision',
    resourceId: inserted.rows[0].id,
    metadata: { recipientUserId, targetType, targetId, measureType, measureState },
  });
  return { decision: decisionShape(inserted.rows[0]), replayed: false };
}

export async function listMyModerationDecisions(client, actorId) {
  const result = await client.query(
    `SELECT decision.*,
            review.id AS review_request_id,
            review.status AS review_request_status,
            review.submitted_at AS review_submitted_at,
            review.resolved_at AS review_resolved_at,
            review.resolution AS review_resolution
       FROM moderation_decisions AS decision
       LEFT JOIN moderation_review_requests AS review
         ON review.decision_id = decision.id AND review.requester_id = $1
      WHERE decision.recipient_user_id = $1
      ORDER BY decision.created_at DESC, decision.id DESC
      LIMIT 200`,
    [actorId],
  );
  return result.rows.map(decisionShape);
}

export async function submitModerationReviewRequest(client, {
  actor,
  decisionId,
  raw,
  idempotencyKey,
}) {
  const review = normalizeModerationReviewRequestInput(raw);
  const key = moderationIdempotencyKey(idempotencyKey, 'moderation.review.request');
  const replay = await client.query(
    'SELECT * FROM moderation_review_requests WHERE idempotency_key = $1',
    [key],
  );
  if (replay.rowCount) return { reviewRequest: reviewShape(replay.rows[0]), replayed: true };
  const decision = await client.query(
    `SELECT * FROM moderation_decisions WHERE id::text = $1 FOR UPDATE`,
    [decisionId],
  );
  if (!decision.rowCount) throw new ModerationDecisionError(404, 'moderation_decision_not_found');
  const row = decision.rows[0];
  if (row.recipient_user_id !== actor.id) {
    throw new ModerationDecisionError(403, 'moderation_decision_forbidden');
  }
  if (!row.review_available || !row.review_deadline_at || new Date(row.review_deadline_at) <= new Date()) {
    throw new ModerationDecisionError(409, 'moderation_review_window_closed');
  }
  const prior = await client.query(
    'SELECT * FROM moderation_review_requests WHERE decision_id = $1 AND requester_id = $2',
    [row.id, actor.id],
  );
  if (prior.rowCount) throw new ModerationDecisionError(409, 'moderation_review_already_requested');
  const inserted = await client.query(
    `INSERT INTO moderation_review_requests (
       decision_id, requester_id, reason, idempotency_key
     ) VALUES ($1, $2, $3, $4) RETURNING *`,
    [row.id, actor.id, review.reason, key],
  );
  await client.query(
    `INSERT INTO moderation_review_events (
       review_request_id, actor_id, actor_role, event_type,
       to_status, note, idempotency_key
     ) VALUES ($1, $2, $3, 'submitted', 'submitted', $4, $5)`,
    [inserted.rows[0].id, actor.id, actor.role, review.reason, `${key}:event`],
  );
  await audit(client, {
    actor,
    action: 'moderation.review_requested',
    resourceType: 'moderation_review_request',
    resourceId: inserted.rows[0].id,
    metadata: { decisionId: row.id },
  });
  return { reviewRequest: reviewShape(inserted.rows[0]), replayed: false };
}

export async function listStaffModerationReviewRequests(client, { status = null } = {}) {
  const normalizedStatus = text(status, 30) || null;
  const result = await client.query(
    `SELECT review.*
       FROM moderation_review_requests AS review
      WHERE ($1::text IS NULL OR review.status = $1)
      ORDER BY review.submitted_at, review.id
      LIMIT 200`,
    [normalizedStatus],
  );
  return result.rows.map(reviewShape);
}

export async function resolveModerationReviewRequest(client, {
  actor,
  reviewRequestId,
  raw,
  idempotencyKey,
}) {
  if (actor.role !== 'admin') throw new ModerationDecisionError(403, 'admin_role_required');
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new ModerationDecisionError(400, 'moderation_review_resolution_invalid');
  }
  const status = text(raw.status, 30);
  if (!['upheld', 'modified', 'reversed'].includes(status)) {
    throw new ModerationDecisionError(400, 'moderation_review_resolution_status_invalid');
  }
  const resolution = text(raw.resolution, 8000);
  if (resolution.length < 3) {
    throw new ModerationDecisionError(400, 'moderation_review_resolution_required');
  }
  const key = moderationIdempotencyKey(idempotencyKey, 'moderation.review.resolve');
  const event = await client.query(
    'SELECT review_request_id FROM moderation_review_events WHERE idempotency_key = $1',
    [`${key}:event`],
  );
  const locked = await client.query(
    'SELECT * FROM moderation_review_requests WHERE id::text = $1 FOR UPDATE',
    [reviewRequestId],
  );
  if (!locked.rowCount) throw new ModerationDecisionError(404, 'moderation_review_request_not_found');
  if (event.rowCount) return { reviewRequest: reviewShape(locked.rows[0]), replayed: true, measureChanged: false };
  if (!['submitted', 'in_review'].includes(locked.rows[0].status)) {
    throw new ModerationDecisionError(409, 'moderation_review_already_resolved');
  }
  const updated = await client.query(
    `UPDATE moderation_review_requests
        SET status = $2, resolution = $3, resolved_by = $4,
            resolved_at = now(), updated_at = now()
      WHERE id = $1 RETURNING *`,
    [locked.rows[0].id, status, resolution, actor.id],
  );
  await client.query(
    `INSERT INTO moderation_review_events (
       review_request_id, actor_id, actor_role, event_type,
       from_status, to_status, note, idempotency_key
     ) VALUES ($1, $2, $3, 'resolved', $4, $5, $6, $7)`,
    [
      locked.rows[0].id,
      actor.id,
      actor.role,
      locked.rows[0].status,
      status,
      resolution,
      `${key}:event`,
    ],
  );
  await audit(client, {
    actor,
    action: 'moderation.review_resolved',
    resourceType: 'moderation_review_request',
    resourceId: locked.rows[0].id,
    metadata: { status, measureChanged: false },
  });
  return { reviewRequest: reviewShape(updated.rows[0]), replayed: false, measureChanged: false };
}

export async function setPrivateMarketplaceReviewStatus(client, {
  actor,
  userId,
  raw,
  idempotencyKey,
}) {
  if (actor.role !== 'admin') throw new ModerationDecisionError(403, 'admin_role_required');
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new ModerationDecisionError(400, 'private_marketplace_review_invalid');
  }
  const status = text(raw.status, 30);
  if (!['clear', 'review_required', 'blocked'].includes(status)) {
    throw new ModerationDecisionError(400, 'private_marketplace_review_status_invalid');
  }
  const reasonCode = text(raw.reasonCode, 120).toLowerCase();
  if (!/^[a-z0-9_.:-]{3,120}$/u.test(reasonCode)) {
    throw new ModerationDecisionError(400, 'private_marketplace_review_reason_required');
  }
  const key = moderationIdempotencyKey(idempotencyKey, 'private.marketplace.review');
  const replay = await client.query(
    `SELECT user_id, to_status
       FROM private_marketplace_review_events
      WHERE idempotency_key = $1`,
    [key],
  );
  const target = await client.query(
    `SELECT id, role, private_marketplace_review_status
       FROM users WHERE id = $1 AND deactivated_at IS NULL FOR UPDATE`,
    [userId],
  );
  if (!target.rowCount) throw new ModerationDecisionError(404, 'user_not_found');
  if (target.rows[0].role !== 'user') {
    throw new ModerationDecisionError(409, 'staff_private_marketplace_review_forbidden');
  }
  if (replay.rowCount) {
    return {
      userId: replay.rows[0].user_id,
      status: replay.rows[0].to_status,
      replayed: true,
    };
  }
  if (target.rows[0].private_marketplace_review_status === status) {
    throw new ModerationDecisionError(409, 'private_marketplace_review_status_unchanged');
  }
  await client.query(
    'UPDATE users SET private_marketplace_review_status = $2 WHERE id = $1',
    [userId, status],
  );
  await client.query(
    `INSERT INTO private_marketplace_review_events (
       user_id, actor_id, actor_role, from_status, to_status,
       reason_code, note, idempotency_key
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
    [
      userId,
      actor.id,
      actor.role,
      target.rows[0].private_marketplace_review_status,
      status,
      reasonCode,
      text(raw.note, 8000) || null,
      key,
    ],
  );
  const decision = await persistModerationDecision(client, {
    actor,
    recipientUserId: userId,
    reportId: text(raw.reportId, 80) || null,
    targetType: 'user',
    targetId: userId,
    measureType: status === 'clear' ? 'measure_reversal' : 'private_marketplace_review',
    measureState: status,
    raw: raw.decision,
    idempotencyKey: `${key}:decision`,
  });
  await audit(client, {
    actor,
    action: 'moderation.private_marketplace_review_changed',
    resourceType: 'user',
    resourceId: userId,
    metadata: {
      from: target.rows[0].private_marketplace_review_status,
      to: status,
      reasonCode,
    },
  });
  return { userId, status, decision: decision.decision, replayed: false };
}
