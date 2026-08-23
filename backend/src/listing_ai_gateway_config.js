import {
  listingAiDraftSchemaVersion,
  listingAiPromptVersion,
} from './listing_ai_draft_domain.js';

export const listingAiGatewayVersion = 'N3-2026-08-23.1';
export const listingAiMockModel = 'listing-ai-mock-v1';

export class ListingAiGatewayConfigurationError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

function fail(code) {
  throw new ListingAiGatewayConfigurationError(code);
}

function integer(value, fallback, { minimum, maximum, code }) {
  const candidate = value == null || String(value).trim() === ''
    ? fallback
    : Number(value);
  if (!Number.isSafeInteger(candidate) || candidate < minimum || candidate > maximum) {
    fail(code);
  }
  return candidate;
}

export function readListingAiGatewayConfiguration(
  env = {},
  { deploymentEnvironment = 'development' } = {},
) {
  const provider = String(env.SIT_LISTING_AI_PROVIDER ?? 'disabled').trim().toLowerCase();
  if (!['disabled', 'mock', 'openai'].includes(provider)) {
    fail('SIT_LISTING_AI_PROVIDER must be disabled, mock, or openai');
  }
  const normalizedEnvironment = String(deploymentEnvironment).trim().toLowerCase();
  if (normalizedEnvironment === 'production' && provider !== 'disabled') {
    fail('listing AI cannot be enabled in production before the release gate');
  }

  const promptVersion = String(
    env.SIT_LISTING_AI_PROMPT_VERSION ?? listingAiPromptVersion,
  ).trim();
  if (promptVersion !== listingAiPromptVersion) {
    fail('SIT_LISTING_AI_PROMPT_VERSION is not supported');
  }
  const schemaVersion = String(
    env.SIT_LISTING_AI_SCHEMA_VERSION ?? listingAiDraftSchemaVersion,
  ).trim();
  if (schemaVersion !== listingAiDraftSchemaVersion) {
    fail('SIT_LISTING_AI_SCHEMA_VERSION is not supported');
  }

  const budgetCents = integer(env.SIT_LISTING_AI_BUDGET_CENTS, 0, {
    minimum: 0,
    maximum: 1_000_000,
    code: 'SIT_LISTING_AI_BUDGET_CENTS must be a bounded non-negative integer',
  });
  const timeoutMs = integer(env.SIT_LISTING_AI_TIMEOUT_MS, 10_000, {
    minimum: 250,
    maximum: 30_000,
    code: 'SIT_LISTING_AI_TIMEOUT_MS must be between 250 and 30000',
  });
  const rateLimitWindowMs = integer(env.SIT_LISTING_AI_RATE_WINDOW_MS, 15 * 60_000, {
    minimum: 60_000,
    maximum: 24 * 60 * 60_000,
    code: 'SIT_LISTING_AI_RATE_WINDOW_MS must be between 60000 and 86400000',
  });
  const rateLimitMaxRequests = integer(env.SIT_LISTING_AI_RATE_MAX_REQUESTS, 5, {
    minimum: 1,
    maximum: 100,
    code: 'SIT_LISTING_AI_RATE_MAX_REQUESTS must be between 1 and 100',
  });

  const configuredModel = String(env.SIT_LISTING_AI_MODEL ?? '').trim();
  const model = provider === 'mock'
    ? (configuredModel || listingAiMockModel)
    : configuredModel;
  if (provider === 'mock' && model !== listingAiMockModel) {
    fail('mock listing AI must use listing-ai-mock-v1');
  }
  if (provider === 'openai' && (model.length < 1 || model.length > 120)) {
    fail('SIT_LISTING_AI_MODEL is required for the openai adapter boundary');
  }
  if (provider !== 'openai' && budgetCents !== 0) {
    fail('non-paid listing AI providers must have a zero-cent budget');
  }

  return Object.freeze({
    gatewayVersion: listingAiGatewayVersion,
    provider,
    model: model || null,
    promptVersion,
    schemaVersion,
    budgetCents,
    timeoutMs,
    rateLimitWindowMs,
    rateLimitMaxRequests,
    enabled: provider === 'mock',
    providerExecutionAllowed: provider === 'mock',
    externalProviderExecutionAllowed: false,
    providerToolsAllowed: false,
    providerDatabaseWriteAllowed: false,
    providerPublicationAllowed: false,
    authoritativeProviderPriceAllowed: false,
    automaticRetryAllowed: false,
    secretConfiguredInClient: false,
  });
}
