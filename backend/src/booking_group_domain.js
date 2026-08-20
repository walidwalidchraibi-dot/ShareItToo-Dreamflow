import crypto from 'node:crypto';

import { parseBookingPeriod, parseRentalDates } from './booking_domain.js';

export const bookingGroupSchemaVersion = 1;
export const bookingGroupPositionVersion = 1;
export const maximumBookingGroupPositions = 20;

export class BookingGroupDomainError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

function text(value, code, maximum = 120) {
  const candidate = typeof value === 'string' ? value.trim() : '';
  if (!candidate || candidate.length > maximum) throw new BookingGroupDomainError(code);
  return candidate;
}

function token(value, code) {
  const candidate = text(value, code);
  if (!/^[A-Za-z0-9_.:-]+$/u.test(candidate)) throw new BookingGroupDomainError(code);
  return candidate;
}

function currency(value) {
  const candidate = text(value, 'invalid_booking_group_currency', 3).toUpperCase();
  if (!/^[A-Z]{3}$/u.test(candidate)) {
    throw new BookingGroupDomainError('invalid_booking_group_currency');
  }
  return candidate;
}

function country(value) {
  const candidate = text(value, 'invalid_booking_group_country', 40).toLowerCase();
  if (!['de', 'deutschland', 'germany'].includes(candidate)) {
    throw new BookingGroupDomainError('booking_group_country_not_allowed');
  }
  return 'DE';
}

function hash(value, code) {
  const candidate = text(value, code, 64).toLowerCase();
  if (!/^[0-9a-f]{64}$/u.test(candidate)) throw new BookingGroupDomainError(code);
  return candidate;
}

function uuid(value, code) {
  const candidate = value();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/u
    .test(candidate)) {
    throw new BookingGroupDomainError(code);
  }
  return candidate;
}

function compatibilityHash(parts) {
  return crypto.createHash('sha256').update(parts.join('\n'), 'utf8').digest('hex');
}

export function buildBookingGroupFoundation(raw, { idFactory = crypto.randomUUID } = {}) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new BookingGroupDomainError('invalid_booking_group_payload');
  }
  const ownerId = token(raw.ownerId, 'invalid_booking_group_owner');
  const renterId = token(raw.renterId, 'invalid_booking_group_renter');
  if (ownerId === renterId) throw new BookingGroupDomainError('cannot_rent_own_booking_group');
  const marketplaceContext = token(
    raw.marketplaceContext ?? 'private_c2c',
    'invalid_booking_group_marketplace_context',
  );
  if (marketplaceContext !== 'private_c2c') {
    throw new BookingGroupDomainError('booking_group_marketplace_context_not_allowed');
  }
  const countryCode = country(raw.countryCode);
  const currencyCode = currency(raw.currency);
  const period = parseRentalDates(raw.startDate, raw.endDate);
  if (!period) throw new BookingGroupDomainError('invalid_booking_group_rental_dates');
  const instants = parseBookingPeriod(raw.startsAt, raw.endsAt);
  if (!instants) throw new BookingGroupDomainError('invalid_booking_group_period');
  const timezone = text(raw.timezone, 'invalid_booking_group_timezone');
  const handoverLocationKey = hash(
    raw.handoverLocationKey,
    'invalid_booking_group_handover_location_key',
  );
  const handoverPolicyVersion = token(
    raw.handoverPolicyVersion,
    'invalid_booking_group_handover_policy',
  );
  const legalDocumentSetVersion = token(
    raw.legalDocumentSetVersion,
    'invalid_booking_group_legal_document_set',
  );
  const cancellationPolicyVersion = token(
    raw.cancellationPolicyVersion,
    'invalid_booking_group_cancellation_policy',
  );
  const paymentConfigurationKey = token(
    raw.paymentConfigurationKey,
    'invalid_booking_group_payment_configuration',
  );
  if (!Array.isArray(raw.items)
    || raw.items.length < 2
    || raw.items.length > maximumBookingGroupPositions) {
    throw new BookingGroupDomainError('invalid_booking_group_item_count');
  }

  const seenListings = new Set();
  const positions = raw.items.map((item, index) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      throw new BookingGroupDomainError('invalid_booking_group_item');
    }
    const listingId = token(item.listingId, 'invalid_booking_group_listing');
    if (seenListings.has(listingId)) {
      throw new BookingGroupDomainError('duplicate_booking_group_listing');
    }
    seenListings.add(listingId);
    if (token(item.ownerId, 'invalid_booking_group_item_owner') !== ownerId) {
      throw new BookingGroupDomainError('booking_group_item_owner_mismatch');
    }
    if (country(item.countryCode) !== countryCode) {
      throw new BookingGroupDomainError('booking_group_item_country_mismatch');
    }
    if (currency(item.currency) !== currencyCode) {
      throw new BookingGroupDomainError('booking_group_item_currency_mismatch');
    }
    return Object.freeze({
      id: `booking_group_position_${uuid(
        idFactory,
        'invalid_booking_group_position_identifier',
      )}`,
      positionVersion: bookingGroupPositionVersion,
      listingId,
      sortOrder: index,
    });
  });

  const group = Object.freeze({
    id: `booking_group_${uuid(idFactory, 'invalid_booking_group_identifier')}`,
    aggregateVersion: bookingGroupSchemaVersion,
    ownerId,
    renterId,
    marketplaceContext,
    countryCode,
    currency: currencyCode,
    startDate: period.startDate,
    endDate: period.endDate,
    timezone,
    startsAt: instants.startsAt.toISOString(),
    endsAt: instants.endsAt.toISOString(),
    handoverLocationKey,
    handoverPolicyVersion,
    legalDocumentSetVersion,
    cancellationPolicyVersion,
    paymentConfigurationKey,
    compatibilityHash: compatibilityHash([
      ownerId,
      renterId,
      marketplaceContext,
      countryCode,
      currencyCode,
      period.startDate,
      period.endDate,
      timezone,
      handoverLocationKey,
      handoverPolicyVersion,
      legalDocumentSetVersion,
      cancellationPolicyVersion,
      paymentConfigurationKey,
    ]),
    positions: Object.freeze(positions),
  });
  return group;
}
