import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  classifyPublicRouteResults,
  extractSiteBlock,
  validateCanonicalCaddy,
} from '../../tool/prepare_public_store_route_rollout.mjs';

const root = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))));
const caddyfile = fs.readFileSync(path.join(root, 'backend', 'ops', 'Caddyfile'), 'utf8');
const evidence = JSON.parse(fs.readFileSync(
  path.join(root, 'docs', 'evidence', 'b11', 'public-store-route-rollout-readiness-20260811.json'),
  'utf8',
));

test('canonical Caddyfile preserves API routing and places all public routes before the app shell', () => {
  assert.deepEqual(validateCanonicalCaddy(caddyfile), {
    productionRoutes: ['support', 'privacy', 'account-deletion'],
    stagingRoutes: ['support', 'privacy', 'account-deletion'],
    appShellFallbackAfterRoutes: true,
    apiRoutingPreserved: true,
  });
});

test('site extraction stops at the matching outer brace', () => {
  const production = extractSiteBlock(caddyfile, 'shareittoo.com, srv1580960.hstgr.cloud');
  assert.match(production, /@public_support/u);
  assert.doesNotMatch(production, /@staging_public_support/u);
});

test('current app-shell responses are classified as an outdated deployed config', () => {
  const results = ['support', 'privacy', 'account-deletion'].map((id) => ({
    id,
    httpStatus: 200,
    pageMarkerPresent: false,
    complianceStatus: null,
  }));
  assert.equal(classifyPublicRouteResults(results), 'deployed-config-out-of-date');
});

test('expected draft and operational responses prove active routes', () => {
  assert.equal(classifyPublicRouteResults([
    { id: 'support', httpStatus: 503, pageMarkerPresent: true, complianceStatus: 'draft' },
    { id: 'privacy', httpStatus: 503, pageMarkerPresent: true, complianceStatus: 'draft' },
    { id: 'account-deletion', httpStatus: 200, pageMarkerPresent: true, complianceStatus: 'operational' },
  ]), 'routes-active');
});

test('mixed or partially routed responses halt the rollout', () => {
  assert.equal(classifyPublicRouteResults([
    { id: 'support', httpStatus: 503, pageMarkerPresent: true, complianceStatus: 'draft' },
    { id: 'privacy', httpStatus: 200, pageMarkerPresent: false, complianceStatus: null },
    { id: 'account-deletion', httpStatus: 200, pageMarkerPresent: true, complianceStatus: 'operational' },
  ]), 'unexpected-partial-state');
});

test('saved readiness evidence is bound to the canonical Caddyfile and records no change', () => {
  assert.equal(
    evidence.localCaddySha256,
    createHash('sha256').update(caddyfile).digest('hex'),
  );
  assert.equal(evidence.deployedState, 'deployed-config-out-of-date');
  assert.deepEqual(evidence.boundaries, {
    readOnly: true,
    caddyReloaded: false,
    productionChanged: false,
    stagingChanged: false,
    legalContentApproved: false,
    containsSecrets: false,
    containsPersonalAccountData: false,
    containsRawDeviceIdentifiers: false,
  });
});
