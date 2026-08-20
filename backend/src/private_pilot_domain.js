import {
  validateV52CheckoutDeclarations,
  v52CheckoutDeclarations,
  v52ContractDocument,
  V52ContractWorkflowError,
} from './v52_contract_workflow.js';

export const privatePilotDocument = Object.freeze({
  name: 'ShareItToo Rechtsmappe Privat-Launch',
  version: 'V5.1-2026-08-16',
  language: 'de',
});

export const privatePilotInterimPolicy = Object.freeze({
  version: 'V5.1-2026-08-16',
  scope: 'internal-and-closed-testing-only',
  active: true,
  realPaymentsEnabled: false,
  replaceOnUserInstruction: true,
});

export const privatePilotOpenDecisions = Object.freeze([
  Object.freeze({
    id: 'platform_contract_and_withdrawal_timing',
    status: 'superseded_by_v51',
    interimRule: 'v51_exact_two_declarations_at_binding_booking_request',
    updateAuthority: 'v51_part_a_11_13_and_implementation_2_5',
    blocksLiveActivation: true,
    activeForInternalTesting: true,
  }),
  Object.freeze({
    id: 'withdrawal_effect_on_private_rental',
    status: 'superseded_by_v51',
    interimRule: 'v51_14_day_before_after_handover_effects_later_rights_review',
    updateAuthority: 'v51_part_a_13_and_implementation_5',
    blocksLiveActivation: true,
    activeForInternalTesting: true,
  }),
  Object.freeze({
    id: 'cancellation_50_100_or_30_50',
    status: 'superseded_by_v51',
    interimRule: 'v51_24h_50_percent_60min_and_actual_loss_after_start',
    updateAuthority: 'v51_part_c_and_implementation_6',
    blocksLiveActivation: true,
    activeForInternalTesting: true,
  }),
  Object.freeze({
    id: 'marketplace_psp_mechanics',
    status: 'superseded_by_v51',
    interimRule: 'licensed_marketplace_psp_test_only_until_evidenced',
    updateAuthority: 'v51_part_e_and_psp_contract_acceptance',
    blocksLiveActivation: true,
    activeForInternalTesting: true,
  }),
  Object.freeze({
    id: 'missing_return_confirmation_window',
    status: 'superseded_by_v51',
    interimRule: 'awaiting_return_confirmation_until_t0_plus_5_calendar_days',
    updateAuthority: 'v51_part_e_2',
    blocksLiveActivation: false,
    activeForInternalTesting: true,
  }),
  Object.freeze({
    id: 'handover_photo_workflow',
    status: 'superseded_by_v51',
    interimRule: 'four_handover_party_photos_plus_counterparty_confirmation_or_deviation_photo',
    updateAuthority: 'v51_part_d_2_and_implementation_9',
    blocksLiveActivation: false,
    activeForInternalTesting: true,
  }),
]);

export const privatePilotDeclarations = Object.freeze({
  account: 'Ich bin mindestens 18 Jahre alt, handle als natuerliche Person und nutze ShareItToo im Privat-Pilot ausschliesslich privat.',
  listing: 'Ich biete diesen Gegenstand als Privatperson an, bin zur Vermietung berechtigt und handle weder gewerblich noch beruflich.',
  booking: 'Ich buche als Privatperson fuer private Zwecke und akzeptiere, dass ShareItToo keine Kaution, Versicherung oder Schadengarantie anbietet.',
  bindingBookingRequest: 'Ich gebe eine verbindliche zahlungspflichtige Buchungsanfrage zu den angezeigten Daten, Preisen und Dokumentversionen ab.',
  platformTerms: 'Ich akzeptiere die Plattform-Nutzungsbedingungen und den angezeigten Plattformbeitrag.',
  earlyPerformance: 'Ich verlange, dass ShareItToo vor Ablauf der Widerrufsfrist mit der Vermittlung und technischen Buchungsbestätigung beginnt.',
  withdrawalKnowledge: 'Mir ist bekannt, dass mein Widerrufsrecht bei vollständiger Vertragserfüllung unter den gesetzlichen Voraussetzungen erlöschen kann.',
  ownerAcceptance: 'Ich nehme die zahlungspflichtige Buchungsanfrage zu den angezeigten Bedingungen und Dokumentversionen an.',
  platformWithdrawal: 'Ich widerrufe die kostenpflichtige Plattformleistung von ShareItToo für die ausgewählte Buchung.',
});

export const privatePilotCheckoutDocument = v52ContractDocument;
export const privatePilotRequiredCheckoutDeclarations = v52CheckoutDeclarations;

export const privatePilotAllowedCategoryIds = Object.freeze(new Set([
  'cat1', 'cat2', 'cat3', 'cat4', 'cat5', 'cat6', 'cat7', 'cat8',
  'cat12', 'cat14', 'cat15', 'cat16', 'cat17', 'cat20', 'cat22', 'cat23',
]));

export class PrivatePilotValidationError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

export function assertPrivatePilotListing(raw) {
  if (raw?.privateStatusConfirmed !== true) {
    throw new PrivatePilotValidationError('private_status_confirmation_required');
  }
  const categoryId = String(raw?.categoryId ?? '').trim();
  if (!privatePilotAllowedCategoryIds.has(categoryId)) {
    throw new PrivatePilotValidationError('private_pilot_category_not_allowed');
  }
  const country = String(raw?.country ?? '').trim().toLowerCase();
  if (!['de', 'deutschland', 'germany'].includes(country)) {
    throw new PrivatePilotValidationError('private_pilot_country_not_allowed');
  }
  if (raw?.offersDeliveryAtDropoff === true
      || raw?.offersPickupAtReturn === true
      || raw?.offersExpressAtDropoff === true
      || raw?.maxDeliveryKmAtDropoff != null
      || raw?.maxPickupKmAtReturn != null) {
    throw new PrivatePilotValidationError('private_pilot_delivery_disabled');
  }
  return true;
}

export function privatePilotListingFields(raw) {
  return Object.freeze({
    privateStatusConfirmed: raw?.privateStatusConfirmed === true,
    offersDeliveryAtDropoff: false,
    offersPickupAtReturn: false,
    offersExpressAtDropoff: false,
    maxDeliveryKmAtDropoff: null,
    maxPickupKmAtReturn: null,
    handoverRadiusKm: null,
  });
}

export function assertPrivatePilotBooking(raw, { requireDeclaration = true } = {}) {
  if (requireDeclaration && raw?.privateStatusConfirmed !== true) {
    throw new PrivatePilotValidationError('private_status_confirmation_required');
  }
  if (raw?.ownerDeliversAtDropoffChosen === true
      || raw?.ownerPicksUpAtReturnChosen === true
      || raw?.expressRequested === true
      || raw?.deliveryAddressLine != null
      || raw?.returnAddressLine != null) {
    throw new PrivatePilotValidationError('private_pilot_delivery_disabled');
  }
  if (requireDeclaration) {
    try {
      validateV52CheckoutDeclarations(raw?.legalDeclarations);
    } catch (error) {
      if (error instanceof V52ContractWorkflowError) {
        throw new PrivatePilotValidationError(error.code);
      }
      throw error;
    }
  }
  return true;
}

export function assertPrivatePilotOwnerAcceptance(raw) {
  const declarations = Array.isArray(raw?.legalDeclarations)
    ? raw.legalDeclarations
    : [];
  const match = declarations.find((entry) => (
    entry?.type === 'owner_booking_acceptance'
    && entry?.exactWording === privatePilotDeclarations.ownerAcceptance
    && entry?.documentName === privatePilotDocument.name
    && entry?.documentVersion === privatePilotDocument.version
    && entry?.language === privatePilotDocument.language
    && entry?.accepted === true
    && Number.isFinite(Date.parse(entry?.acceptedAt))
  ));
  if (!match) {
    throw new PrivatePilotValidationError(
      'private_pilot_declaration_missing:owner_booking_acceptance',
    );
  }
  return match;
}
