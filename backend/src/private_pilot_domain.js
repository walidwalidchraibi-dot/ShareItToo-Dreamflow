import {
  validateV51CheckoutDeclarations,
  v51CheckoutDeclarations,
  v51ContractDocument,
  V51ContractWorkflowError,
} from './v51_contract_workflow.js';

export const privatePilotDocument = Object.freeze({
  name: 'ShareItToo Rechtsmappe Privat-Pilot',
  version: 'V4-2026-08-14',
  language: 'de',
});

export const privatePilotInterimPolicy = Object.freeze({
  version: 'V4-INTERIM-2026-08-15',
  scope: 'internal-and-closed-testing-only',
  active: true,
  realPaymentsEnabled: false,
  replaceOnUserInstruction: true,
});

export const privatePilotOpenDecisions = Object.freeze([
  Object.freeze({
    id: 'platform_contract_and_withdrawal_timing',
    status: 'open',
    interimRule: 'versioned_separate_declarations_at_booking_request',
    updateAuthority: 'legal_review_question_1',
    blocksLiveActivation: true,
    activeForInternalTesting: true,
  }),
  Object.freeze({
    id: 'withdrawal_effect_on_private_rental',
    status: 'open',
    interimRule: 'record_and_confirm_without_automatic_booking_or_money_effect',
    updateAuthority: 'legal_review_question_2',
    blocksLiveActivation: true,
    activeForInternalTesting: true,
  }),
  Object.freeze({
    id: 'cancellation_50_100_or_30_50',
    status: 'open',
    interimRule: 'retain_50_percent_under_24h_and_100_percent_after_start',
    updateAuthority: 'legal_and_product_question_3',
    blocksLiveActivation: true,
    activeForInternalTesting: true,
  }),
  Object.freeze({
    id: 'marketplace_psp_mechanics',
    status: 'open',
    interimRule: 'test_and_mock_only_no_real_money_movement',
    updateAuthority: 'psp_contract_and_payment_legal_review_question_4',
    blocksLiveActivation: true,
    activeForInternalTesting: true,
  }),
  Object.freeze({
    id: 'missing_return_confirmation_window',
    status: 'open',
    interimRule: 'awaiting_return_confirmation_until_t0_plus_5_calendar_days',
    updateAuthority: 'product_and_psp',
    blocksLiveActivation: false,
    activeForInternalTesting: true,
  }),
  Object.freeze({
    id: 'handover_photo_workflow',
    status: 'open',
    interimRule: 'four_photos_each_direction_counter_confirmation_or_deviation_photo',
    updateAuthority: 'pilot_usability_test',
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

export const privatePilotCheckoutDocument = v51ContractDocument;
export const privatePilotRequiredCheckoutDeclarations = v51CheckoutDeclarations;

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
      validateV51CheckoutDeclarations(raw?.legalDeclarations);
    } catch (error) {
      if (error instanceof V51ContractWorkflowError) {
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
