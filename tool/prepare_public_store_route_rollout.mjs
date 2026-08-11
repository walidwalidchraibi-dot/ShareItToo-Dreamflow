#!/usr/bin/env node

import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const caddyPath = path.join(root, 'backend', 'ops', 'Caddyfile');
const routeSpecs = [
  {
    id: 'support',
    path: '/support',
    matcher: 'public_support',
    upstreamPath: '/v1/public/support',
    expectedStatus: 503,
    complianceStatus: 'draft',
  },
  {
    id: 'privacy',
    path: '/privacy',
    matcher: 'public_privacy',
    upstreamPath: '/v1/public/privacy',
    expectedStatus: 503,
    complianceStatus: 'draft',
  },
  {
    id: 'account-deletion',
    path: '/account-deletion',
    matcher: 'public_account_deletion',
    upstreamPath: '/v1/account-deletion',
    expectedStatus: 200,
    complianceStatus: 'operational',
  },
];

function fail(message) {
  throw new Error(message);
}

export function extractSiteBlock(caddyfile, label) {
  const lines = caddyfile.split(/\r?\n/u);
  const start = lines.findIndex((line) => line.trim() === `${label} {`);
  if (start < 0) fail(`Missing Caddy site block: ${label}`);
  let depth = 0;
  for (let index = start; index < lines.length; index += 1) {
    depth += (lines[index].match(/\{/gu) ?? []).length;
    depth -= (lines[index].match(/\}/gu) ?? []).length;
    if (depth === 0) return lines.slice(start, index + 1).join('\n');
  }
  fail(`Unclosed Caddy site block: ${label}`);
}

function requireRoute(block, spec, prefix = '') {
  const matcher = `${prefix}${spec.matcher}`;
  const expected = new RegExp(
    `@${matcher}\\s+path\\s+${spec.path.replaceAll('/', '\\/')}[\\s\\S]*?` +
      `handle\\s+@${matcher}\\s*\\{[\\s\\S]*?` +
      `rewrite\\s+\\*\\s+${spec.upstreamPath.replaceAll('/', '\\/')}[\\s\\S]*?` +
      'reverse_proxy\\s+[^\\s]+:8080[\\s\\S]*?\\}',
    'u',
  );
  if (!expected.test(block)) fail(`Missing or unsafe Caddy route: ${spec.id}`);
}

export function validateCanonicalCaddy(caddyfile) {
  const production = extractSiteBlock(caddyfile, 'shareittoo.com, srv1580960.hstgr.cloud');
  const staging = extractSiteBlock(caddyfile, 'staging.shareittoo.com');
  for (const spec of routeSpecs) {
    requireRoute(production, spec);
    requireRoute(staging, spec, 'staging_');
  }
  const productionFallback = production.lastIndexOf('import shareittoo_app');
  const lastProductionRoute = Math.max(
    ...routeSpecs.map((spec) => production.indexOf(`handle @${spec.matcher}`)),
  );
  if (productionFallback < lastProductionRoute) {
    fail('Production app-shell fallback appears before the public route handlers.');
  }
  if (!/handle_path\s+\/api\/\*/u.test(production) ||
      !/handle_path\s+\/api\/\*/u.test(staging)) {
    fail('Existing API routing must remain present in both site blocks.');
  }
  return {
    productionRoutes: routeSpecs.map((spec) => spec.id),
    stagingRoutes: routeSpecs.map((spec) => spec.id),
    appShellFallbackAfterRoutes: true,
    apiRoutingPreserved: true,
  };
}

export function classifyPublicRouteResults(results) {
  if (!Array.isArray(results) || results.length !== routeSpecs.length) {
    fail('Exactly three public route results are required.');
  }
  const byId = new Map(results.map((result) => [result.id, result]));
  const allActive = routeSpecs.every((spec) => {
    const result = byId.get(spec.id);
    return result?.httpStatus === spec.expectedStatus &&
      result?.pageMarkerPresent === true &&
      result?.complianceStatus === spec.complianceStatus;
  });
  if (allActive) return 'routes-active';

  const allAppShell = routeSpecs.every((spec) => {
    const result = byId.get(spec.id);
    return result?.httpStatus === 200 &&
      result?.pageMarkerPresent === false &&
      result?.complianceStatus === null;
  });
  if (allAppShell) return 'deployed-config-out-of-date';
  return 'unexpected-partial-state';
}

async function inspectRoute(origin, spec) {
  const target = new URL(spec.path, origin);
  const response = await fetch(target, {
    redirect: 'error',
    headers: { 'User-Agent': 'ShareItToo-Route-Rollout-Readiness/1.0' },
    signal: AbortSignal.timeout(10_000),
  });
  const body = await response.text();
  const compliance = /data-sit-compliance-status="([^"]+)"/u.exec(body)?.[1] ?? null;
  return {
    id: spec.id,
    path: spec.path,
    httpStatus: response.status,
    pageMarkerPresent: body.includes(`data-sit-public-page="${spec.id}"`),
    complianceStatus: compliance,
  };
}

async function run() {
  const args = process.argv.slice(2);
  const requireActive = args.includes('--require-active');
  const unknown = args.filter((value) => value !== '--require-active');
  if (unknown.length > 0) fail(`Unknown arguments: ${unknown.join(', ')}`);

  const caddyfile = fs.readFileSync(caddyPath, 'utf8');
  const canonical = validateCanonicalCaddy(caddyfile);
  const results = await Promise.all(
    routeSpecs.map((spec) => inspectRoute('https://shareittoo.com', spec)),
  );
  const deployedState = classifyPublicRouteResults(results);
  const report = {
    schemaVersion: 1,
    kind: 'public-store-route-rollout-readiness',
    status: deployedState === 'routes-active'
      ? 'already-active'
      : deployedState === 'deployed-config-out-of-date'
        ? 'ready-awaiting-explicit-production-route-approval'
        : 'halt-unexpected-partial-state',
    localCaddySha256: createHash('sha256').update(caddyfile).digest('hex'),
    canonical,
    deployedState,
    checks: results,
    requiredRolloutSequence: [
      'capture deployed Caddyfile hash and create an owner-only backup',
      'compare the deployed file with the validated canonical Caddyfile',
      'validate the candidate configuration before reload',
      'obtain explicit production-route approval',
      'reload Caddy without changing API containers, DNS, mail, cron, Stripe, or app images',
      'verify all three public routes and the unchanged API health endpoints',
      'restore the backup immediately on any mismatch',
    ],
    boundaries: {
      readOnly: true,
      caddyReloaded: false,
      productionChanged: false,
      stagingChanged: false,
      containsSecrets: false,
    },
  };
  console.log(JSON.stringify(report, null, 2));
  if (deployedState === 'unexpected-partial-state' ||
      (requireActive && deployedState !== 'routes-active')) {
    process.exitCode = 2;
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  run().catch((error) => {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  });
}
