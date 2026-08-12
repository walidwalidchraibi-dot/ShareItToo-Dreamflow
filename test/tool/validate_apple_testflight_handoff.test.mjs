import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateAppleTestFlightHandoff } from '../../tool/validate_apple_testflight_handoff.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const canonical = JSON.parse(await readFile(
  new URL('../../store/apple/testflight-handoff.json', import.meta.url), 'utf8'));
const firebasePlist = `<?xml version="1.0"?><plist><dict>
  <key>BUNDLE_ID</key><string>com.shareittoo.app</string>
  <key>IS_ANALYTICS_ENABLED</key><false/>
  <key>IS_ADS_ENABLED</key><false/>
</dict></plist>`;
const configuredSources = {
  'ios/Runner/GoogleService-Info.plist': firebasePlist,
};

test('accepts the truthful static Apple handoff with account and tooling gates open', () => {
  const result = validateAppleTestFlightHandoff({ root, sourceOverrides: configuredSources });
  assert.deepEqual(result, { bundleId: 'com.shareittoo.app', buildNumber: '2026081116' });
});

test('rejects a premature Apple membership or upload claim', () => {
  const handoff = structuredClone(canonical);
  handoff.accountGates.developerProgramMembership = 'passed';
  assert.throws(() => validateAppleTestFlightHandoff({
    root,
    handoffOverride: handoff,
    sourceOverrides: configuredSources,
  }),
    /developerProgramMembership/);
});

test('rejects bundle identifier drift', async () => {
  const project = await readFile(
    new URL('../../ios/Runner.xcodeproj/project.pbxproj', import.meta.url), 'utf8');
  assert.throws(() => validateAppleTestFlightHandoff({
    root,
    sourceOverrides: {
      ...configuredSources,
      'ios/Runner.xcodeproj/project.pbxproj': project.replace(
        'PRODUCT_BUNDLE_IDENTIFIER = com.shareittoo.app;',
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.wrong;',
      ),
    },
  }), /bundle ID/);
});

test('rejects Firebase analytics activation', () => {
  assert.throws(() => validateAppleTestFlightHandoff({
    root,
    sourceOverrides: {
      'ios/Runner/GoogleService-Info.plist': firebasePlist.replace(
        '<key>IS_ANALYTICS_ENABLED</key><false/>',
        '<key>IS_ANALYTICS_ENABLED</key><true/>',
      ),
    },
  }), /Analytics and ads/);
});

test('rejects credential-shaped fields', () => {
  const handoff = structuredClone(canonical);
  handoff.applePassword = 'forbidden';
  assert.throws(() => validateAppleTestFlightHandoff({
    root,
    handoffOverride: handoff,
    sourceOverrides: configuredSources,
  }),
    /forbidden credential-shaped field/);
});
