const allowedWorkflowStatuses = Object.freeze([
  'accepted',
  'payment_pending',
  'confirmed',
  'active',
  'returned',
]);

export class BookingFlowTimeError extends Error {
  constructor(status, code, details = undefined) {
    super(code);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function safeText(value, maxLength = 200) {
  const text = typeof value === 'string' ? value.trim() : '';
  return text.length <= maxLength ? text : '';
}

function prefixForSegment(segment) {
  if (segment === 'pickup') return 'handover';
  if (segment === 'return') return 'return';
  throw new BookingFlowTimeError(400, 'invalid_flow_time_segment');
}

function assertParticipant({ actorId, ownerId, renterId }) {
  if (actorId !== ownerId && actorId !== renterId) {
    throw new BookingFlowTimeError(403, 'booking_flow_time_forbidden');
  }
}

function assertWorkflowStatus(status) {
  if (!allowedWorkflowStatuses.includes(status)) {
    throw new BookingFlowTimeError(409, 'booking_flow_time_unavailable', { status });
  }
}

export function normalizeBookingFlowTimeState(payload) {
  const source = payload && typeof payload === 'object' && !Array.isArray(payload)
    ? payload
    : {};
  return {
    handoverTimeRequested: safeText(source.handoverTimeRequested, 120),
    returnTimeRequested: safeText(source.returnTimeRequested, 120),
    handoverTimeIso: safeText(source.handoverTimeIso, 80),
    returnTimeIso: safeText(source.returnTimeIso, 80),
    handoverTimeRequestedByUserId: safeText(source.handoverTimeRequestedByUserId, 120),
    returnTimeRequestedByUserId: safeText(source.returnTimeRequestedByUserId, 120),
    handoverTimeConfirmed: source.handoverTimeConfirmed === true,
    returnTimeConfirmed: source.returnTimeConfirmed === true,
    handoverTimeConfirmedByUserId: safeText(source.handoverTimeConfirmedByUserId, 120),
    returnTimeConfirmedByUserId: safeText(source.returnTimeConfirmedByUserId, 120),
    handoverTimeConfirmedAt: safeText(source.handoverTimeConfirmedAt, 80),
    returnTimeConfirmedAt: safeText(source.returnTimeConfirmedAt, 80),
    flowTimeRevision: Number.isSafeInteger(Number(source.flowTimeRevision))
      ? Number(source.flowTimeRevision)
      : 0,
  };
}

export function applyBookingFlowTimeAction({
  payload,
  actorId,
  ownerId,
  renterId,
  workflowStatus,
  raw,
  now = new Date(),
}) {
  assertParticipant({ actorId, ownerId, renterId });
  assertWorkflowStatus(workflowStatus);
  const input = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
  const action = safeText(input.action, 32);
  const segment = safeText(input.segment, 16);
  const prefix = prefixForSegment(segment);
  const state = normalizeBookingFlowTimeState(payload);

  if (action === 'propose') {
    const label = safeText(input.label, 120);
    const timeIso = safeText(input.timeIso, 80);
    const parsed = Date.parse(timeIso);
    if (!label || !Number.isFinite(parsed)) {
      throw new BookingFlowTimeError(400, 'invalid_flow_time_proposal');
    }
    state[`${prefix}TimeRequested`] = label;
    state[`${prefix}TimeIso`] = new Date(parsed).toISOString();
    state[`${prefix}TimeRequestedByUserId`] = actorId;
    state[`${prefix}TimeConfirmed`] = false;
    state[`${prefix}TimeConfirmedByUserId`] = '';
    state[`${prefix}TimeConfirmedAt`] = '';
  } else if (action === 'confirm') {
    const requested = safeText(state[`${prefix}TimeRequested`], 120);
    const requestedBy = safeText(state[`${prefix}TimeRequestedByUserId`], 120);
    if (!requested || !requestedBy) {
      throw new BookingFlowTimeError(409, 'flow_time_proposal_missing');
    }
    if (requestedBy === actorId) {
      throw new BookingFlowTimeError(409, 'flow_time_counterparty_confirmation_required');
    }
    state[`${prefix}TimeConfirmed`] = true;
    state[`${prefix}TimeConfirmedByUserId`] = actorId;
    state[`${prefix}TimeConfirmedAt`] = now.toISOString();
  } else {
    throw new BookingFlowTimeError(400, 'invalid_flow_time_action');
  }

  state.flowTimeRevision += 1;
  return {
    payload: { ...(payload ?? {}), ...state },
    state,
    eventType: `booking.flow_time.${action}`,
    eventMetadata: { segment, action, flowTimeRevision: state.flowTimeRevision },
  };
}

async function lockedBooking(client, bookingId) {
  const result = await client.query(
    `SELECT booking.id, booking.owner_id, booking.renter_id,
            booking.workflow_status, booking.workflow_version, request.payload
     FROM bookings AS booking
     JOIN rental_requests AS request ON request.id = booking.id
     WHERE booking.id = $1
     FOR UPDATE OF booking, request`,
    [bookingId],
  );
  if (!result.rowCount) throw new BookingFlowTimeError(404, 'booking_not_found');
  const row = result.rows[0];
  if (Number(row.workflow_version) !== 1) {
    throw new BookingFlowTimeError(409, 'booking_requires_b6_revalidation');
  }
  return row;
}

export async function getBookingFlowTime(client, { actorId, bookingId }) {
  const result = await client.query(
    `SELECT booking.owner_id, booking.renter_id, booking.workflow_status,
            booking.workflow_version, request.payload
     FROM bookings AS booking
     JOIN rental_requests AS request ON request.id = booking.id
     WHERE booking.id = $1`,
    [bookingId],
  );
  if (!result.rowCount) throw new BookingFlowTimeError(404, 'booking_not_found');
  const row = result.rows[0];
  assertParticipant({ actorId, ownerId: row.owner_id, renterId: row.renter_id });
  if (Number(row.workflow_version) !== 1) {
    throw new BookingFlowTimeError(409, 'booking_requires_b6_revalidation');
  }
  assertWorkflowStatus(row.workflow_status);
  return normalizeBookingFlowTimeState(row.payload);
}

export async function updateBookingFlowTime(client, {
  actor,
  bookingId,
  raw,
  idempotencyKey,
}) {
  const eventKey = safeText(idempotencyKey, 160);
  if (!eventKey || !/^[A-Za-z0-9_.:-]{8,160}$/.test(eventKey)) {
    throw new BookingFlowTimeError(400, 'invalid_idempotency_key');
  }
  const row = await lockedBooking(client, bookingId);
  assertParticipant({ actorId: actor.id, ownerId: row.owner_id, renterId: row.renter_id });

  const existingEvent = await client.query(
    'SELECT booking_id, actor_id, metadata FROM booking_events WHERE idempotency_key = $1',
    [eventKey],
  );
  if (existingEvent.rowCount) {
    const event = existingEvent.rows[0];
    if (event.booking_id !== bookingId || event.actor_id !== actor.id) {
      throw new BookingFlowTimeError(409, 'idempotency_key_reused');
    }
    return { state: normalizeBookingFlowTimeState(row.payload), replayed: true, participantUserIds: [row.owner_id, row.renter_id] };
  }

  const applied = applyBookingFlowTimeAction({
    payload: row.payload,
    actorId: actor.id,
    ownerId: row.owner_id,
    renterId: row.renter_id,
    workflowStatus: row.workflow_status,
    raw,
  });
  await client.query(
    'UPDATE rental_requests SET payload = $2::jsonb WHERE id = $1',
    [bookingId, JSON.stringify(applied.payload)],
  );
  await client.query(
    `INSERT INTO booking_events (
       booking_id, actor_id, event_type, idempotency_key, metadata
     ) VALUES ($1, $2, $3, $4, $5::jsonb)`,
    [bookingId, actor.id, applied.eventType, eventKey, JSON.stringify(applied.eventMetadata)],
  );
  return {
    state: applied.state,
    replayed: false,
    participantUserIds: [row.owner_id, row.renter_id],
  };
}
