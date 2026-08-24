import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const screen = readFileSync('lib/screens/create_listing_screen.dart', 'utf8');
const config = readFileSync('lib/config/private_pilot_config.dart', 'utf8');
const repository = readFileSync('lib/services/backend_repository.dart', 'utf8');
const dataService = readFileSync('lib/services/data_service.dart', 'utf8');
const app = readFileSync('backend/src/app.js', 'utf8');

test('Flutter gate is default-off while the complete manual editor remains present', () => {
  assert.match(config, /SIT_BLUE_OCEAN_LISTING_ASSISTANT/u);
  assert.match(config, /defaultValue:\s*false/u);
  assert.match(screen, /PrivatePilotConfig\.blueOceanListingAssistantEnabled/u);
  assert.match(screen, /Für später speichern/u);
  assert.match(screen, /Der manuelle Editor bleibt vollständig verfügbar/u);
});

test('UI requires exact disclosure, opt-in, explicit initiation and never promises auto-publication', () => {
  assert.match(screen, /listing-ai-image-disclosure-v1/u);
  assert.match(screen, /SIT analysiert deine ausgewählten Bilder/u);
  assert.match(screen, /_blueOceanConsentAccepted/u);
  assert.match(screen, /Ausgewählte Fotos analysieren/u);
  assert.match(screen, /Es wird nie automatisch veröffentlicht/u);
});

test('UI exposes progress, editable fields, confidence text and at most three clarifications', () => {
  assert.match(screen, /LinearProgressIndicator/u);
  assert.match(screen, /liveRegion:\s*true/u);
  assert.match(screen, /Bearbeitbarer KI-Entwurf/u);
  assert.match(screen, /hoch – bearbeitbar/u);
  assert.match(screen, /bitte prüfen/u);
  assert.match(screen, /Angabe fehlt/u);
  assert.match(screen, /Rückfragen \(höchstens drei\)/u);
  for (const label of [
    'Marke', 'Modell', 'Zubehör', 'Projekt-Tags', 'Einsatzmöglichkeiten',
    'Sicherheits- und Nutzungshinweise', 'Grobe Abholregion',
  ]) {
    assert.match(screen, new RegExp(label, 'u'));
  }
});

test('all eleven owner confirmations and hard functionality/final gates are visible', () => {
  for (const id of [
    'ownership', 'item_identity', 'allowed_category', 'functionality',
    'condition', 'accessories', 'owner_price', 'duration_discounts',
    'availability', 'pickup_region', 'final_publication',
  ]) {
    assert.match(screen, new RegExp(`'${id}': false`, 'u'));
  }
  assert.match(screen, /Funktionalität.*abschließende Publikationsprüfung/su);
  assert.match(screen, /READY_TO_PUBLISH/u);
  assert.match(screen, /NEEDS_REVIEW/u);
});

test('regional price, duration and V5.2 fee preview stay editable and simulation-only', () => {
  assert.match(screen, /Unverbindliche SIT-Preisempfehlung/u);
  assert.match(screen, /Du entscheidest über deinen Mietpreis/u);
  assert.match(screen, /Mietdauer- und V5\.2-Gebührenvorschau/u);
  assert.match(screen, /Vermieter-Miete/u);
  assert.match(screen, /SIT-Beitrag/u);
  assert.match(screen, /Mieter gesamt/u);
  assert.match(screen, /Reine Simulation ohne Zahlung/u);
});

test('every automatic or manual daily-price change invalidates owner confirmation', () => {
  const invalidations = screen.match(
    /_blueOceanConfirmations\['owner_price'\] = false;/gu,
  ) ?? [];
  assert.ok(invalidations.length >= 4);
  assert.match(
    screen,
    /recommendedDailyMinor[\s\S]*_priceCtrl\.text =[\s\S]*_blueOceanConfirmations\['owner_price'\] = false;/u,
  );
  assert.match(
    screen,
    /_PricePerDayInput\([\s\S]*onChanged:[\s\S]*_blueOceanConfirmations\['owner_price'\] = false;/u,
  );
});

test('client and server use separate authenticated review and exact publication actions', () => {
  assert.match(repository, /\/blue-ocean\/listing-drafts\/analyze/u);
  assert.match(repository, /\/blue-ocean\/listing-drafts\/\$\{Uri\.encodeComponent\(draftId\)\}\/review/u);
  assert.match(repository, /explicitAction': 'Anzeige veröffentlichen'/u);
  assert.match(dataService, /blueOceanDraftId != null && blueOceanReview != null/u);
  assert.match(dataService, /BackendRepository\.createListing/u);
  assert.match(app, /assertBlueOceanListingTechnicalAccess\(\)/u);
  assert.match(app, /requireAuth, requireActiveAccount, requireUnsuspendedScope\('listing'\)/u);
  assert.match(app, /req\.body\?\.explicitAction !== 'Anzeige veröffentlichen'/u);
  assert.match(app, /blue_ocean\.listing\.published_by_owner/u);
  assert.match(app, /autoPublishAllowed: false/u);
});

test('accessibility and recovery do not rely on color alone', () => {
  assert.match(screen, /Semantics\(/u);
  assert.match(screen, /selected: selected/u);
  assert.match(screen, /Icons\.check_circle_outline/u);
  assert.match(screen, /Icons\.rate_review_outlined/u);
  assert.match(screen, /Icons\.help_outline/u);
  assert.match(screen, /Scrollable\.ensureVisible/u);
  assert.match(screen, /_blueOceanErrorFocus\.requestFocus/u);
});
