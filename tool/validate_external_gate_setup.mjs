#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  validateSupportTestMatrixTraceability,
} from './validate_support_test_matrix_traceability.mjs';

const root = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
const manifestPath = 'docs/evidence/external-gates/technical-setup-manifest.json';
const supportTraceabilityPath =
  'docs/evidence/support/support-test-matrix-v1-traceability.json';

const expectedGates = Object.freeze([
  ['legal_and_operator_approval', 'prepared-external-review-required'],
  ['operations_roles_and_absence', 'prepared-external-assignments-required'],
  ['ios_apple_signing_and_device', 'android-ready-ios-external-setup-required'],
  ['firebase_owner_terms_and_controls', 'owner-console-confirmation-required'],
  ['psp_contract_and_sandbox_e2e', 'provider-contract-and-sandbox-required'],
  ['privacy_retention_and_legal_hold', 'prepared-owner-and-legal-decisions-required'],
  ['store_submission_and_closed_testing', 'google-account-ready-submission-gates-open'],
  ['economics_and_cost_inputs', 'external-cost-inputs-required'],
  ['pilot_region_roster_and_scope', 'prepared-prerequisites-open'],
  ['explicit_activation_decision', 'hold-explicit-decision-required'],
]);
const supportTraceabilityConsumers = new Set([
  'legal_and_operator_approval',
  'psp_contract_and_sandbox_e2e',
  'privacy_retention_and_legal_hold',
  'store_submission_and_closed_testing',
  'explicit_activation_decision',
]);

function readJson(relativePath, overrides) {
  if (overrides?.[relativePath] !== undefined) return overrides[relativePath];
  return JSON.parse(readFileSync(path.join(root, relativePath), 'utf8'));
}

function assertCondition(condition, code) {
  if (!condition) throw new Error(code);
}

function inspectSensitiveKeys(value, trail = []) {
  if (Array.isArray(value)) {
    value.forEach((entry, index) => inspectSensitiveKeys(entry, [...trail, index]));
    return;
  }
  if (value === null || typeof value !== 'object') return;
  for (const [key, entry] of Object.entries(value)) {
    assertCondition(
      !/^(password|secret|token|email|accountid|credential|personname|principalref)$/iu.test(key),
      `credential_shaped_field:${[...trail, key].join('.')}`,
    );
    inspectSensitiveKeys(entry, [...trail, key]);
  }
}

function allFalse(object) {
  return Object.values(object).every((value) => value === false);
}

export function validateExternalGateSetup({
  requireReady = false,
  manifestOverride,
  sourceOverrides,
} = {}) {
  const manifest = manifestOverride ?? readJson(manifestPath, sourceOverrides);
  inspectSensitiveKeys(manifest);

  assertCondition(manifest.schemaVersion === 1, 'schema_version_invalid');
  assertCondition(manifest.kind === 'sit-external-gate-technical-setup', 'kind_invalid');
  assertCondition(
    manifest.state === 'technically-prepared-external-inputs-required',
    'state_invalid',
  );
  assertCondition(manifest.releaseDecision === 'hold-no-go', 'release_decision_invalid');
  assertCondition(Array.isArray(manifest.gates), 'gates_missing');
  assertCondition(manifest.gates.length === expectedGates.length, 'gate_count_invalid');
  assertCondition(
    JSON.stringify(manifest.setupOrder) === JSON.stringify(expectedGates.map(([id]) => id)),
    'setup_order_invalid',
  );

  const supportTraceability = readJson(supportTraceabilityPath, sourceOverrides);
  const supportTraceabilityResult = validateSupportTestMatrixTraceability({
    manifestOverride: supportTraceability,
  });
  assertCondition(
    JSON.stringify(manifest.supportMatrixTraceability) === JSON.stringify({
      ref: supportTraceabilityPath,
      scenarioCount: 167,
      externalEvidenceRequiredCount: 47,
      externalEvidencePresentCount: 0,
      strictReleaseReady: false,
    }),
    'support_traceability_summary_invalid',
  );
  assertCondition(
    supportTraceabilityResult.scenarioCount === 167
      && supportTraceabilityResult.externalEvidenceRequiredCount === 47
      && supportTraceabilityResult.externalEvidencePresentCount === 0
      && supportTraceabilityResult.strictReleaseReady === false,
    'support_traceability_state_invalid',
  );

  for (let index = 0; index < expectedGates.length; index += 1) {
    const gate = manifest.gates[index];
    const [expectedId, expectedState] = expectedGates[index];
    assertCondition(gate.id === expectedId, `gate_id_invalid:${expectedId}`);
    assertCondition(gate.state === expectedState, `gate_state_invalid:${expectedId}`);
    assertCondition(
      gate.technicalPreparation === 'complete',
      `technical_preparation_incomplete:${expectedId}`,
    );
    assertCondition(gate.ready === false, `manifest_ready_without_current_source:${expectedId}`);
    assertCondition(gate.externalEvidenceRef === null, `external_evidence_must_be_absent:${expectedId}`);
    assertCondition(
      Array.isArray(gate.currentEvidenceRefs) && gate.currentEvidenceRefs.length >= 2,
      `current_evidence_refs_missing:${expectedId}`,
    );
    for (const reference of gate.currentEvidenceRefs) {
      assertCondition(typeof reference === 'string', `evidence_ref_invalid:${expectedId}`);
      assertCondition(
        !path.isAbsolute(reference) && !reference.includes('..'),
        `evidence_ref_unsafe:${expectedId}`,
      );
      assertCondition(existsSync(path.join(root, reference)), `evidence_ref_missing:${reference}`);
    }
    assertCondition(
      gate.currentEvidenceRefs.includes(supportTraceabilityPath)
        === supportTraceabilityConsumers.has(expectedId),
      `support_traceability_ref_invalid:${expectedId}`,
    );
  }

  assertCondition(
    JSON.stringify(manifest.summary) === JSON.stringify({
      requiredGateCount: 10,
      technicallyPreparedGateCount: 10,
      externallyReadyGateCount: 0,
      openGateCount: 10,
      supportScenarioCount: 167,
      supportExternalEvidenceRequiredCount: 47,
      supportExternalEvidencePresentCount: 0,
      strictReady: false,
    }),
    'summary_invalid',
  );
  assertCondition(allFalse(manifest.boundaries), 'external_mutation_boundary_invalid');

  const legal = readJson(
    'assets/legal/de/legal_review_intake_p0b_20260821.json',
    sourceOverrides,
  );
  assertCondition(
    legal.status === 'prepared-awaiting-independent-professional-review',
    'legal_state_drift',
  );
  assertCondition(legal.professionallyReviewed === false, 'legal_approval_drift');
  assertCondition(legal.openDecisionKeys?.length === 18, 'legal_decision_count_drift');

  const operations = readJson(
    'docs/operations/p0b-ops-role-delegate-absence-gate.json',
    sourceOverrides,
  );
  assertCondition(operations.evaluation?.requiredRoleCount === 6, 'operations_role_count_drift');
  assertCondition(operations.evaluation?.assignedRoleCount === 0, 'operations_assignment_drift');
  assertCondition(operations.evaluation?.technicalRehearsalsPassed === 4, 'operations_rehearsal_drift');
  assertCondition(operations.evaluation?.humanAbsenceTestsPassed === 0, 'operations_absence_drift');
  assertCondition(operations.evaluation?.operationsReady === false, 'operations_ready_drift');

  const devices = readJson(
    'docs/evidence/p0b-next/signed-device-evidence.json',
    sourceOverrides,
  );
  assertCondition(devices.releaseGate?.androidCurrentSourceSignedCandidate === true, 'android_candidate_drift');
  assertCondition(devices.releaseGate?.androidCurrentSourcePhysicalEvidence === true, 'android_device_drift');
  assertCondition(devices.releaseGate?.iosCurrentSourceSignedCandidate === false, 'ios_candidate_drift');
  assertCondition(devices.releaseGate?.iosCurrentSourcePhysicalEvidence === false, 'ios_device_drift');

  const accounts = readJson('store/platform-account-readiness.json', sourceOverrides);
  assertCondition(accounts.googlePlay?.status === 'ready', 'google_play_account_drift');
  assertCondition(accounts.apple?.membershipActive === false, 'apple_membership_drift');
  assertCondition(accounts.firebase?.ownerTermsAccepted === false, 'firebase_terms_drift');

  const psp = readJson(
    'docs/evidence/p0b-next/psp-sandbox-e2e-evidence.json',
    sourceOverrides,
  );
  assertCondition(psp.scenarios?.length === 8, 'psp_scenario_count_drift');
  assertCondition(psp.evaluation?.passedScenarioCount === 0, 'psp_scenario_state_drift');
  assertCondition(psp.evaluation?.sandboxE2ePassed === false, 'psp_ready_drift');
  assertCondition(allFalse(psp.boundaries), 'psp_external_mutation_drift');

  const privacy = readJson('store/privacy-disclosures.json', sourceOverrides);
  const retention = readJson('store/retention-deletion-readiness.json', sourceOverrides);
  assertCondition(privacy.approvalAllowed === false, 'privacy_approval_drift');
  assertCondition(
    Object.values(privacy.requiredDecisions ?? {}).every(({ status }) => status === 'open'),
    'privacy_decision_drift',
  );
  assertCondition(retention.approvalAllowed === false, 'retention_approval_drift');
  assertCondition(
    Object.keys(retention.requiredDecisions ?? {}).length === 10,
    'retention_decision_count_drift',
  );
  assertCondition(
    Object.values(retention.requiredDecisions ?? {}).every(({ status }) => status === 'open'),
    'retention_decision_drift',
  );

  const submission = readJson('store/submission.json', sourceOverrides);
  assertCondition(submission.submissionAllowed === false, 'store_submission_drift');
  assertCondition(
    submission.blockingGates?.googlePlayAccountAndFee === 'closed',
    'google_play_gate_drift',
  );
  assertCondition(
    submission.blockingGates?.googlePlayClosedTestingRequirement === 'open',
    'closed_testing_drift',
  );
  assertCondition(
    submission.blockingGates?.appleAccountXcodeAndSigning === 'open',
    'apple_store_gate_drift',
  );

  const dossier = readJson(
    'docs/evidence/p0b/pilot-go-no-go-dossier.json',
    sourceOverrides,
  );
  assertCondition(
    dossier.economicsAndFounderIndependence?.state === 'unavailable',
    'economics_state_drift',
  );
  assertCondition(
    dossier.economicsAndFounderIndependence?.profitability === 'undetermined',
    'profitability_drift',
  );
  assertCondition(dossier.finalGate?.goNow === false, 'p0b_go_drift');
  assertCondition(dossier.finalGate?.autoContinue === false, 'p0b_autocontinue_drift');

  const pilot = readJson(
    'docs/evidence/p0b-next/invited-synthetic-pilot-spiegelberg-cat8-readiness.json',
    sourceOverrides,
  );
  assertCondition(pilot.evaluation?.passedPrerequisiteCount === 0, 'pilot_prerequisite_drift');
  assertCondition(pilot.evaluation?.controlledPilotEligible === false, 'pilot_eligibility_drift');
  assertCondition(pilot.boundaries?.regionOrCatalogConfigured === false, 'pilot_region_drift');
  assertCondition(allFalse(pilot.boundaries), 'pilot_external_mutation_drift');

  if (requireReady) {
    throw new Error(`external_gates_not_ready:${expectedGates.map(([id]) => id).join(',')}`);
  }

  return Object.freeze({
    status: 'prepared-hold',
    requiredGateCount: expectedGates.length,
    technicallyPreparedGateCount: expectedGates.length,
    externallyReadyGateCount: 0,
    supportScenarioCount: 167,
    supportExternalEvidenceRequiredCount: 47,
    supportExternalEvidencePresentCount: 0,
    releaseDecision: 'hold-no-go',
  });
}

function runCli() {
  const args = process.argv.slice(2);
  const allowed = new Set(['--require-ready']);
  const unknown = args.find((argument) => !allowed.has(argument));
  if (unknown !== undefined) throw new Error(`unknown_argument:${unknown}`);
  const result = validateExternalGateSetup({
    requireReady: args.includes('--require-ready'),
  });
  process.stdout.write(`${JSON.stringify(result)}\n`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    runCli();
  } catch (error) {
    process.stderr.write(`ERROR: ${error.message}\n`);
    process.exitCode = 1;
  }
}
