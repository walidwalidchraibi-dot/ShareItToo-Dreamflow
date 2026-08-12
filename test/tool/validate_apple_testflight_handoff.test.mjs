import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateAppleTestFlightHandoff } from '../../tool/validate_apple_testflight_handoff.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const canonical = JSON.parse(await readFile(
  new URL('../../store/apple/testflight-handoff.json', import.meta.url), 'utf8'));

test('accepts the truthful static Apple handoff with account and tooling gates open', () => {
  const result = validateAppleTestFlightHandoff({ root });
  assert.deepEqual(result, { bundleId: 'com.shareittoo.app', buildNumber: '2026081116' });
});

test('rejects a premature Apple membership or upload claim', () => {
  const handoff = structuredClone(canonical);
  handoff.accountGates.developerProgramMembership = 'passed';
  assert.throws(() => validateAppleTestFlightHandoff({ root, handoffOverride: handoff }),
    /developerProgramMembership/);
});

test('rejects bundle identifier drift', async () => {
  const project = await readFile(
    new URL('../../ios/Runner.xcodeproj/project.pbxproj', import.meta.url), 'utf8');
  assert.throws(() => validateAppleTestFlightHandoff({
    root,
    sourceOverrides: {
      'ios/Runner.xcodeproj/project.pbxproj': project.replace(
        'PRODUCT_BUNDLE_IDENTIFIER = com.shareittoo.app;',
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.wrong;',
      ),
    },
  }), /bundle ID/);
});

test('rejects Firebase analytics activation', async () => {
  const firebase = await readFile(
    new URL('../../ios/Runner/GoogleService-Info.plist', import.meta.url), 'utf8');
  assert.throws(() => validateAppleTestFlightHandoff({
    root,
    sourceOverrides: {
      'ios/Runner/GoogleService-Info.plist': firebase.replace(
        '<key>IS_ANALYTICS_ENABLED</key>\n\t<false/>',
        '<key>IS_ANALYTICS_ENABLED</key>\n\t<true/>',
      ),
    },
  }), /Analytics and ads/);
});

test('rejects credential-shaped fields', () => {
  const handoff = structuredClone(canonical);
  handoff.applePassword = 'forbidden';
  assert.throws(() => validateAppleTestFlightHandoff({ root, handoffOverride: handoff }),
    /forbidden credential-shaped field/);
});
