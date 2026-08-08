export const bookingStatuses = Object.freeze([
  'pending',
  'accepted',
  'declined',
  'cancelled',
  'running',
  'completed',
]);

const bookingStatusSet = new Set(bookingStatuses);

export function normalizeBookingStatus(value, fallback = 'pending') {
  return bookingStatusSet.has(value) ? value : fallback;
}

export function parseBookingPeriod(startValue, endValue) {
  const startsAt = new Date(startValue);
  const endsAt = new Date(endValue);
  if (!Number.isFinite(startsAt.getTime()) || !Number.isFinite(endsAt.getTime())) return null;
  if (startsAt >= endsAt) return null;
  return { startsAt, endsAt };
}

export function normalizeCurrency(value, fallback = 'EUR') {
  const currency = typeof value === 'string' ? value.trim().toUpperCase() : '';
  return /^[A-Z]{3}$/.test(currency) ? currency : fallback;
}

export function amountToMinor(value, { nullable = true } = {}) {
  if (value === null || value === undefined || value === '') return nullable ? null : 0;
  const amount = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(amount) || amount < 0) return null;
  const minor = Math.round((amount + Number.EPSILON) * 100);
  return Number.isSafeInteger(minor) ? minor : null;
}

export function canTransitionBooking({ current, next, actorId, ownerId, renterId }) {
  if (current === next) return true;
  if (current === 'pending' && (next === 'accepted' || next === 'declined')) return actorId === ownerId;
  if (current === 'pending' && next === 'cancelled') return actorId === renterId;
  if (current === 'accepted' && next === 'running') return actorId === renterId;
  if (current === 'accepted' && next === 'cancelled') return actorId === ownerId || actorId === renterId;
  if (current === 'running' && next === 'completed') return actorId === ownerId;
  return false;
}
