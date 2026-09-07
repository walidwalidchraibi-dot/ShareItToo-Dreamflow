import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

import {
  reviewBlueOceanListingDraft,
} from '../src/blue_ocean_listing_workflow.js';
import { persistBlueOceanReview } from '../src/blue_ocean_listing_store.js';
import {
  createListingAiDraftRevision,
  listingAiDraftSchemaVersion,
  listingAiPromptVersion,
} from '../src/listing_ai_draft_domain.js';

const draftId = 'listing_ai_draft_12345678-1234-4123-8123-123456789abc';
const ownerId = 'owner_12345678';

function generationKey(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function field(value) {
  return {
    value,
    confidence: 'HIGH',
    source: {
      type: 'owner_input',
      imageReference: null,
      detail: 'store_test',
    },
    confirmationRequired: false,
    reasonCode: 'store_test',
    ownerConfirmed: false,
  };
}

function previousRevision() {
  return createListingAiDraftRevision({
    draftId,
    ownerId,
    imageReferences: ['listing_image_12345678'],
    fields: {
      title: field('Akku-Bohrschrauber'),
      category: field('cat8'),
      subcategory: field('Bohrmaschinen'),
      brand: field('Testmarke'),
      model: field('M-18'),
      description: field('Bearbeitbarer Testentwurf.'),
      condition: field('good'),
      accessories: field(['Ladegerät']),
      projectTags: field(['renovation']),
      useCases: field(['bohren']),
      safetyNotes: field('Nur bestimmungsgemäß verwenden.'),
      replacementValueMinor: field(17_500),
      pickupRegion: field('heilbronn_wave0'),
    },
    ownerConfirmations: {},
    generatedAt: new Date('2026-09-05T03:00:00.000Z'),
  });
}

function confirmations() {
  return Object.fromEntries([
    'ownership', 'item_identity', 'allowed_category', 'functionality',
    'condition', 'accessories', 'owner_price', 'duration_discounts',
    'availability', 'pickup_region', 'final_publication',
  ].map((id) => [id, id !== 'final_publication']));
}

function editedFields({ category = 'cat8', subcategory = 'Bohrmaschinen' } = {}) {
  return {
    title: category === 'cat3' ? 'Systemkamera' : 'Akku-Bohrschrauber',
    category,
    subcategory,
    brand: 'Testmarke',
    model: 'M-18',
    description: 'Vollständig durch den Eigentümer geprüfter Testentwurf.',
    condition: 'good',
    accessories: ['Ladegerät'],
    projectTags: ['renovation'],
    useCases: ['bohren'],
    safetyNotes: 'Nur bestimmungsgemäß verwenden.',
    replacementValueMinor: 17_500,
    pickupRegion: 'heilbronn_wave0',
  };
}

function review({ category, subcategory } = {}) {
  return reviewBlueOceanListingDraft({
    previousRevision: previousRevision(),
    generationKey: generationKey(`${category ?? 'cat8'}-${subcategory ?? 'Bohrmaschinen'}`),
    editedFields: editedFields({ category, subcategory }),
    answeredClarificationIds: [],
    ownerConfirmations: confirmations(),
    pricing: {
      replacementValueBand: 'eur_100_250',
      ownerConfirmedReplacementValueBand: true,
      ownerConfirmedReplacementValueMinor: null,
      ownerDailyPriceMinor: 1_600,
      durationPricingEnabled: true,
    },
    previewDays: [1, 7],
    imagePreflightPassed: true,
    consentValid: true,
    generatedAt: new Date('2026-09-05T03:01:00.000Z'),
  });
}

function storedRow(previous) {
  return {
    draft_id: previous.draftId,
    owner_id: previous.ownerId,
    status: 'editing',
    current_revision: previous.revision,
    schema_version: listingAiDraftSchemaVersion,
    prompt_version: listingAiPromptVersion,
    disclosure_version: 'listing-ai-image-disclosure-v1',
    disclosure_accepted_at: new Date('2026-09-05T03:00:00.000Z'),
    image_preflight_status: 'consumed',
    published_listing_id: null,
    draft_version_id: '11111111-1111-4111-8111-111111111111',
    revision: previous.revision,
    generation_key: generationKey('previous'),
    generation_mode: previous.generationMode,
    input_image_refs: previous.imageReferences,
    fields: previous.fields,
    clarification_questions: previous.clarificationQuestions,
    owner_confirmations: previous.ownerConfirmations,
    payload_sha256: previous.payloadSha256,
    review_metadata: {},
    version_created_at: previous.generatedAt,
  };
}

function recordingClient(previous) {
  const calls = [];
  return {
    calls,
    async query(sql, params = []) {
      const text = String(sql);
      calls.push({ text, params });
      if (text.includes('LEFT JOIN LATERAL')) {
        return { rowCount: 1, rows: [storedRow(previous)] };
      }
      if (text.includes('WHERE draft_id = $1 AND generation_key = $2')) {
        return { rowCount: 0, rows: [] };
      }
      if (text.includes('INSERT INTO listing_ai_draft_versions')) {
        return {
          rowCount: 1,
          rows: [{ id: '22222222-2222-4222-8222-222222222222' }],
        };
      }
      if (text.includes('UPDATE listing_ai_drafts')) {
        return { rowCount: 1, rows: [] };
      }
      if (text.includes('INSERT INTO regional_price_engine_snapshots')) {
        return { rowCount: 1, rows: [] };
      }
      throw new Error(`unexpected_store_query:${text}`);
    },
  };
}

test('manual owner price is append-only review metadata, never a fabricated regional snapshot', async () => {
  const previous = previousRevision();
  const value = review({ category: 'cat3', subcategory: 'Kameras' });
  const client = recordingClient(previous);
  const persisted = await persistBlueOceanReview(client, { ownerId, review: value });
  assert.equal(persisted.replayed, false);
  assert.equal(
    client.calls.some(({ text }) => text.includes('INSERT INTO regional_price_engine_snapshots')),
    false,
  );
  const versionInsert = client.calls.find(
    ({ text }) => text.includes('INSERT INTO listing_ai_draft_versions'),
  );
  const metadata = JSON.parse(versionInsert.params[9]);
  assert.equal(metadata.priceMode, 'owner_manual_no_recommendation');
  assert.match(metadata.priceInputSha256, /^[a-f0-9]{64}$/u);
  assert.equal(metadata.recommendation, null);
  assert.equal(metadata.selection.ownerSelectedDailyMinor, 1_600);
  assert.equal(metadata.selection.publicationPriceReady, true);
  assert.equal(metadata.autoPublishAllowed, false);
});

test('an exact supported catalog pair still persists its regional recommendation snapshot', async () => {
  const previous = previousRevision();
  const value = review();
  const client = recordingClient(previous);
  await persistBlueOceanReview(client, { ownerId, review: value });
  assert.equal(value.priceMode, 'regional_recommendation');
  assert.equal(value.recommendation.engineAuthority, 'SIT_REGIONAL_PRICE_ENGINE_V2');
  assert.equal(
    client.calls.some(({ text }) => text.includes('INSERT INTO regional_price_engine_snapshots')),
    true,
  );
});
