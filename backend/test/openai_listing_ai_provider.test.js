import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { chmod, mkdtemp, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  buildListingAiProviderRequest,
  deterministicListingAiMockOutput,
  ListingAiGatewayError,
} from '../src/listing_ai_gateway.js';
import {
  listingAiOpenAiModel,
  readListingAiGatewayConfiguration,
} from '../src/listing_ai_gateway_config.js';
import {
  createOpenAiListingAiProvider,
  readOpenAiListingAiApiKey,
} from '../src/openai_listing_ai_provider.js';

const secretFixture = `sk-test-${'x'.repeat(32)}`;
const imageReference = 'analysis_image_00000001';

function configuration(budgetCents = 5) {
  return readListingAiGatewayConfiguration({
    SIT_LISTING_AI_PROVIDER: 'openai',
    SIT_LISTING_AI_MODEL: listingAiOpenAiModel,
    SIT_LISTING_AI_BUDGET_CENTS: String(budgetCents),
    SIT_LISTING_AI_EXTERNAL_EXECUTION_APPROVED: '1',
  }, { deploymentEnvironment: 'staging' });
}

function derivative() {
  return {
    imageReference,
    mimeType: 'image/webp',
    bytes: Buffer.from('safe-stripped-webp-fixture'),
  };
}

function apiResponse(output, usage = { input_tokens: 100, output_tokens: 50 }) {
  return {
    ok: true,
    status: 200,
    async json() {
      return {
        status: 'completed',
        output: [{
          type: 'message',
          content: [{ type: 'output_text', text: JSON.stringify(output) }],
        }],
        usage,
      };
    },
  };
}

function providerOutput() {
  const output = structuredClone(deterministicListingAiMockOutput([imageReference]));
  for (const field of Object.values(output.fields)) field.source.type = 'provider_output';
  return output;
}

function request() {
  return buildListingAiProviderRequest({
    draftId: 'listing_ai_draft_12345678-1234-4123-8123-123456789abc',
    ownerId: 'owner_12345678',
    generationKey: crypto.createHash('sha256').update('openai-test').digest('hex'),
    revision: 1,
    imageReferences: [imageReference],
    untrustedOcr: [],
    manualInputPresent: true,
  }, configuration());
}

test('OpenAI listing-AI credential loader supports an exact private file without fallback leakage', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'sit-openai-provider-secret-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const secretPath = join(directory, 'openai-api-key');
  const linkPath = join(directory, 'openai-api-key-link');
  await writeFile(secretPath, `${secretFixture}\n`, { mode: 0o600 });
  await chmod(secretPath, 0o600);

  assert.equal(
    readOpenAiListingAiApiKey({ OPENAI_API_KEY_FILE: secretPath }),
    secretFixture,
  );
  assert.throws(
    () => readOpenAiListingAiApiKey({
      OPENAI_API_KEY: secretFixture,
      OPENAI_API_KEY_FILE: secretPath,
    }),
    (error) => error instanceof ListingAiGatewayError
      && error.code === 'listing_ai_provider_credentials_conflicting',
  );

  await symlink(secretPath, linkPath);
  assert.throws(
    () => readOpenAiListingAiApiKey({ OPENAI_API_KEY_FILE: linkPath }),
    (error) => error instanceof ListingAiGatewayError
      && error.code === 'listing_ai_provider_credentials_unavailable',
  );
  assert.throws(
    () => readOpenAiListingAiApiKey({ OPENAI_API_KEY_FILE: 'relative-secret' }),
    (error) => error instanceof ListingAiGatewayError
      && error.code === 'listing_ai_provider_credentials_unavailable',
  );
});

test('openai adapter sends stripped data URLs with strict schemas and no tools or storage', async () => {
  const calls = [];
  const outputs = [
    { visualScanCompleted: true, visualSignals: [] },
    providerOutput(),
  ];
  const provider = createOpenAiListingAiProvider({
    configuration: configuration(),
    apiKey: secretFixture,
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      return apiResponse(outputs.shift());
    },
  });
  const image = derivative();
  const screening = await provider.screenDerivative(image);
  const result = await provider.generate(request(), { analysisImages: [image] });

  assert.equal(screening.visualScanCompleted, true);
  assert.deepEqual(screening.visualSignals, []);
  assert.equal(result.output.fields.title.source.type, 'provider_output');
  assert.equal(result.usage.estimatedCostCents, 1);
  assert.equal(result.usage.billedCostCents, null);
  assert.equal(calls.length, 2);
  for (const call of calls) {
    assert.equal(call.url, 'https://api.openai.com/v1/responses');
    const body = JSON.parse(call.options.body);
    assert.equal(body.model, listingAiOpenAiModel);
    assert.equal(body.store, false);
    assert.equal(body.text.format.type, 'json_schema');
    assert.equal(body.text.format.strict, true);
    assert.equal('tools' in body, false);
    assert.match(call.options.body, /data:image\/webp;base64,/u);
    assert.equal(call.options.body.includes(secretFixture), false);
  }
});

test('openai adapter fails closed on credentials, HTTP errors and process budget exhaustion', async () => {
  assert.throws(
    () => createOpenAiListingAiProvider({
      configuration: configuration(),
      apiKey: 'short',
    }),
    (error) => error instanceof ListingAiGatewayError
      && error.code === 'listing_ai_provider_credentials_unavailable',
  );

  const failed = createOpenAiListingAiProvider({
    configuration: configuration(),
    apiKey: secretFixture,
    fetchImpl: async () => ({ ok: false, status: 500 }),
  });
  await assert.rejects(
    failed.screenDerivative(derivative()),
    (error) => error instanceof ListingAiGatewayError
      && error.code === 'listing_ai_provider_http_failed',
  );

  let calls = 0;
  const bounded = createOpenAiListingAiProvider({
    configuration: configuration(2),
    apiKey: secretFixture,
    fetchImpl: async () => {
      calls += 1;
      return apiResponse({ visualScanCompleted: true, visualSignals: [] });
    },
  });
  await bounded.screenDerivative(derivative());
  await assert.rejects(
    bounded.screenDerivative(derivative()),
    (error) => error instanceof ListingAiGatewayError
      && error.code === 'listing_ai_budget_exhausted'
      && error.details.providerCallCount === 0,
  );
  assert.equal(calls, 1);
});

test('openai adapter reduces refusal and malformed responses to typed safe errors', async () => {
  const refusal = createOpenAiListingAiProvider({
    configuration: configuration(),
    apiKey: secretFixture,
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      async json() {
        return {
          status: 'completed',
          output: [{ type: 'message', content: [{ type: 'refusal', refusal: 'private detail' }] }],
          usage: { input_tokens: 10, output_tokens: 1 },
        };
      },
    }),
  });
  await assert.rejects(
    refusal.screenDerivative(derivative()),
    (error) => error instanceof ListingAiGatewayError
      && error.code === 'listing_ai_provider_refused'
      && !error.message.includes('private detail'),
  );
});
