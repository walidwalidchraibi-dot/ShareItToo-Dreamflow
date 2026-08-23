#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { validatePilotLaunchTiers } from './validate_pilot_launch_tiers.mjs';
import {
  validatePf14bCurrentHeadAndroidTouchTarget,
} from './validate_pf14b_current_head_android_touch_target.mjs';
import {
  validatePf16CurrentCandidateReadOnly,
} from './validate_pf16_current_candidate_read_only.mjs';

const root = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
const boardPath =
  'docs/evidence/external-gates/external-gate-execution-board.json';
const runbookPath = 'docs/operations/EXTERNAL_GATE_EXECUTION_BOARD.md';
const canonicalPath =
  'docs/evidence/external-gates/technical-setup-manifest.json';
const pf14bEvidencePath =
  'docs/evidence/external-gates/current-head-android-touch-target-remediation-2026082302.json';
const pf16EvidencePath =
  'docs/evidence/external-gates/current-candidate-read-only-regression-2026082302.json';
const supersededAndroidCandidatePath =
  'docs/evidence/external-gates/current-head-android-candidate-2026082301.json';

const stageABlockers = Object.freeze([
  'legal_and_operator_approval',
  'operations_roles_and_absence',
  'firebase_owner_terms_and_controls',
  'privacy_retention_and_legal_hold',
  'store_submission_and_closed_testing',
  'pilot_region_roster_and_scope',
  'explicit_activation_decision',
]);

const expectedGates = Object.freeze([
  ['legal_and_operator_approval', 'BLOCKIERT STUFE A', ['stage_a', 'stage_b', 'stage_c'], 'prepared-external-review-required'],
  ['operations_roles_and_absence', 'BLOCKIERT STUFE A', ['stage_a', 'stage_b', 'stage_c'], 'prepared-external-assignments-required'],
  ['ios_apple_signing_and_device', 'KANN FÜR STUFE A ZURÜCKGESTELLT WERDEN', [], 'android-ready-ios-external-setup-required'],
  ['firebase_owner_terms_and_controls', 'BLOCKIERT STUFE A', ['stage_a', 'stage_b', 'stage_c'], 'owner-console-confirmation-required'],
  ['support_evidence_scanner_and_upload_policy', 'KANN FÜR STUFE A ZURÜCKGESTELLT WERDEN', ['stage_b', 'stage_c'], 'intake-disabled-external-scanner-and-policy-required'],
  ['psp_contract_and_sandbox_e2e', 'BLOCKIERT NUR STUFE B', ['stage_b', 'stage_c'], 'provider-contract-and-sandbox-required'],
  ['privacy_retention_and_legal_hold', 'BLOCKIERT STUFE A', ['stage_a', 'stage_b', 'stage_c'], 'prepared-owner-and-legal-decisions-required'],
  ['store_submission_and_closed_testing', 'BLOCKIERT STUFE A', ['stage_a', 'stage_b', 'stage_c'], 'google-account-ready-submission-gates-open'],
  ['economics_and_cost_inputs', 'BLOCKIERT NUR STUFE C', ['stage_c'], 'external-cost-inputs-required'],
  ['pilot_region_roster_and_scope', 'BLOCKIERT STUFE A', ['stage_a', 'stage_b', 'stage_c'], 'prepared-prerequisites-open'],
  ['explicit_activation_decision', 'BLOCKIERT STUFE A', ['stage_a', 'stage_b', 'stage_c'], 'hold-explicit-decision-required'],
]);

function assertCondition(condition, code) {
  if (!condition) throw new Error(code);
}

function same(value, expected) {
  return JSON.stringify(value) === JSON.stringify(expected);
}

function allFalse(value) {
  return value !== null
    && typeof value === 'object'
    && Object.values(value).every((entry) => entry === false);
}

function readJson(relativePath) {
  return JSON.parse(readFileSync(path.join(root, relativePath), 'utf8'));
}

function inspectSensitiveKeys(value, trail = []) {
  if (Array.isArray(value)) {
    value.forEach((entry, index) => inspectSensitiveKeys(entry, [...trail, index]));
    return;
  }
  if (value === null || typeof value !== 'object') return;
  for (const [key, entry] of Object.entries(value)) {
    assertCondition(
      !/^(password|secret|email|accountid|credential|personname|deviceid)$/iu.test(key),
      `sensitive_field_forbidden:${[...trail, key].join('.')}`,
    );
    inspectSensitiveKeys(entry, [...trail, key]);
  }
}

function validateDependencies(gates) {
  const ids = new Set(gates.map((gate) => gate.id));
  const state = new Map();
  const visit = (id) => {
    if (state.get(id) === 'active') throw new Error(`dependency_cycle:${id}`);
    if (state.get(id) === 'done') return;
    state.set(id, 'active');
    const gate = gates.find((entry) => entry.id === id);
    for (const dependency of gate.dependencies) {
      assertCondition(ids.has(dependency), `dependency_unknown:${id}:${dependency}`);
      assertCondition(dependency !== id, `dependency_self:${id}`);
      visit(dependency);
    }
    state.set(id, 'done');
  };
  gates.forEach((gate) => visit(gate.id));
}

export function validateExternalGateExecutionBoard({
  boardOverride,
  canonicalOverride,
  requireStageAReady = false,
} = {}) {
  validatePilotLaunchTiers();
  const board = boardOverride ?? readJson(boardPath);
  const canonical = canonicalOverride ?? readJson(canonicalPath);
  inspectSensitiveKeys(board);

  assertCondition(board.schemaVersion === 1, 'schema_version_invalid');
  assertCondition(board.kind === 'sit-external-gate-execution-board', 'kind_invalid');
  assertCondition(
    board.state === 'pilot-freeze-external-evidence-required',
    'state_invalid',
  );
  assertCondition(board.releaseDecision === 'hold-no-go', 'release_decision_invalid');
  assertCondition(
    board.tierMatrixRef === 'docs/evidence/external-gates/pilot-launch-tier-matrix.json',
    'tier_matrix_ref_invalid',
  );
  assertCondition(board.canonicalGateManifestRef === canonicalPath, 'canonical_ref_invalid');
  assertCondition(
    Object.keys(board.classificationMeaning ?? {}).length === 5,
    'classification_meaning_invalid',
  );
  assertCondition(
    Array.isArray(board.gates) && board.gates.length === expectedGates.length,
    'gate_count_invalid',
  );

  const releaseTokens = new Set();
  board.gates.forEach((gate, index) => {
    const [id, classification, blocksTiers, currentStatus] = expectedGates[index];
    assertCondition(gate.ordinal === index + 1 && gate.id === id, `gate_identity_invalid:${id}`);
    assertCondition(gate.tierClassification === classification, `tier_classification_invalid:${id}`);
    assertCondition(
      gate.readinessClassification === 'TECHNISCH BEREIT, EXTERNE EVIDENZ FEHLT',
      `readiness_classification_invalid:${id}`,
    );
    assertCondition(same(gate.blocksTiers, blocksTiers), `blocks_tiers_invalid:${id}`);
    assertCondition(gate.currentStatus === currentStatus, `gate_status_invalid:${id}`);
    assertCondition(typeof gate.goal === 'string' && gate.goal.length >= 25, `goal_missing:${id}`);
    assertCondition(
      Array.isArray(gate.technicalEvidenceRefs) && gate.technicalEvidenceRefs.length >= 2,
      `technical_evidence_missing:${id}`,
    );
    for (const reference of gate.technicalEvidenceRefs) {
      assertCondition(
        typeof reference === 'string'
          && !path.isAbsolute(reference)
          && !reference.includes('..')
          && existsSync(path.join(root, reference)),
        `technical_evidence_ref_invalid:${id}:${reference}`,
      );
    }
    assertCondition(
      typeof gate.technicalEvidenceSummary === 'string'
        && gate.technicalEvidenceSummary.length >= 40,
      `technical_evidence_summary_missing:${id}`,
    );
    assertCondition(
      Array.isArray(gate.missingExternalEvidence)
        && gate.missingExternalEvidence.length >= 3,
      `missing_external_evidence_invalid:${id}`,
    );
    assertCondition(
      typeof gate.requiredResponsibleRole === 'string'
        && gate.requiredResponsibleRole.length >= 10,
      `responsible_role_missing:${id}`,
    );
    assertCondition(
      typeof gate.cost?.state === 'string'
        && gate.cost.estimatedAmountEur === null
        && gate.cost.approvalRequiredBeforeCost === true,
      `cost_boundary_invalid:${id}`,
    );
    assertCondition(
      typeof gate.contractRequirement === 'string'
        && gate.contractRequirement.length >= 10,
      `contract_requirement_missing:${id}`,
    );
    assertCondition(gate.walidPresenceRequired === true, `walid_presence_invalid:${id}`);
    assertCondition(
      typeof gate.exactNextAction === 'string' && gate.exactNextAction.length >= 50,
      `next_action_missing:${id}`,
    );
    assertCondition(Array.isArray(gate.dependencies), `dependencies_invalid:${id}`);
    assertCondition(
      typeof gate.stopCondition === 'string' && gate.stopCondition.length >= 40,
      `stop_condition_missing:${id}`,
    );
    assertCondition(
      /^[A-Z0-9_]+$/u.test(gate.releaseToken ?? '')
        && gate.releaseTokenState === 'not-issued'
        && !releaseTokens.has(gate.releaseToken),
      `release_token_invalid:${id}`,
    );
    releaseTokens.add(gate.releaseToken);
    assertCondition(
      gate.codexCanContinueIndependentLane === true,
      `independent_lane_invalid:${id}`,
    );
  });

  const ios = board.gates[2];
  assertCondition(
    /android-only/iu.test(ios.stageADeferralCondition ?? '')
      && /no ios\/testflight claim/iu.test(ios.stageADeferralCondition ?? '')
      && same(ios.blocksCapabilities, ['ios-testflight', 'ios-public-distribution']),
    'ios_deferral_boundary_invalid',
  );
  const scanner = board.gates[4];
  assertCondition(
    /upload remains disabled/iu.test(scanner.stageADeferralCondition ?? '')
      && /text/iu.test(scanner.stageADeferralCondition ?? ''),
    'scanner_deferral_boundary_invalid',
  );
  const storeGate = board.gates[7];
  assertCondition(
    storeGate.technicalEvidenceRefs.includes(pf14bEvidencePath)
      && storeGate.technicalEvidenceRefs.includes(pf16EvidencePath)
      && !storeGate.technicalEvidenceRefs.includes(supersededAndroidCandidatePath)
      && /2026082302/u.test(storeGate.technicalEvidenceSummary)
      && /two authenticated cold starts/iu.test(storeGate.technicalEvidenceSummary)
      && /offline recovery/iu.test(storeGate.technicalEvidenceSummary)
      && /manual visual review/iu.test(storeGate.technicalEvidenceSummary)
      && /TalkBack/iu.test(storeGate.technicalEvidenceSummary),
    'store_candidate_evidence_invalid',
  );
  const pf14bResult = validatePf14bCurrentHeadAndroidTouchTarget({
    root,
    evidence: readJson(pf14bEvidencePath),
    checkGitCommit: false,
  });
  assertCondition(
    pf14bResult.buildNumber === '2026082302'
      && pf14bResult.dataPreservingDirectUpdate === true
      && pf14bResult.minimumWidthDp >= 48
      && pf14bResult.minimumHeightDp >= 48
      && pf14bResult.manualVisualReview === false
      && pf14bResult.manualTalkBackTraversal === false
      && pf14bResult.stageAReady === false
      && pf14bResult.decision === 'hold-no-go',
    'store_candidate_gate_state_invalid',
  );
  const pf16Result = validatePf16CurrentCandidateReadOnly({
    root,
    evidence: readJson(pf16EvidencePath),
    pf14bEvidence: readJson(pf14bEvidencePath),
    checkGitCommit: false,
  });
  assertCondition(
    pf16Result.buildNumber === '2026082302'
      && pf16Result.exactInstalledApkVerified === true
      && pf16Result.processRestartPassed === true
      && pf16Result.authenticatedColdStartCycleCount === 2
      && pf16Result.offlineRecoveryPassed === true
      && pf16Result.mainNavigationDestinationCount === 5
      && pf16Result.legalRouteCount === 7
      && pf16Result.largeTextDestinationCount === 5
      && pf16Result.exactPreviousFontScaleRestored === true
      && pf16Result.manualVisualReview === false
      && pf16Result.manualTalkBackTraversal === false
      && pf16Result.completeDeviceMatrix === false
      && pf16Result.stageAReady === false
      && pf16Result.decision === 'hold-no-go',
    'store_candidate_read_only_gate_state_invalid',
  );
  validateDependencies(board.gates);

  assertCondition(
    same(board.summary, {
      requiredGateCount: 11,
      technicallyPreparedGateCount: 11,
      externallyReadyGateCount: 0,
      stageABlockerCount: 7,
      stageBOnlyBlockerCount: 1,
      stageCOnlyBlockerCount: 1,
      stageADeferredCount: 2,
      issuedReleaseTokenCount: 0,
      releaseDecision: 'hold-no-go',
    }),
    'summary_invalid',
  );
  assertCondition(allFalse(board.boundaries), 'external_boundary_invalid');

  assertCondition(canonical.summary?.requiredGateCount === 11, 'canonical_gate_count_drift');
  assertCondition(canonical.summary?.technicallyPreparedGateCount === 11, 'canonical_preparation_drift');
  assertCondition(canonical.summary?.externallyReadyGateCount === 0, 'canonical_readiness_drift');
  assertCondition(canonical.releaseDecision === 'hold-no-go', 'canonical_decision_drift');
  assertCondition(Array.isArray(canonical.gates) && canonical.gates.length === 11, 'canonical_gates_invalid');
  board.gates.forEach((gate, index) => {
    const source = canonical.gates[index];
    assertCondition(source.id === gate.id, `canonical_gate_identity_drift:${gate.id}`);
    assertCondition(source.state === gate.currentStatus, `canonical_gate_state_drift:${gate.id}`);
    assertCondition(source.technicalPreparation === 'complete', `canonical_gate_preparation_drift:${gate.id}`);
    assertCondition(source.ready === false, `canonical_gate_ready_drift:${gate.id}`);
  });

  const legal = readJson('assets/legal/de/legal_review_intake_p0b_20260821.json');
  assertCondition(
    legal.professionallyReviewed === false && legal.openDecisionKeys?.length === 18,
    'legal_external_state_drift',
  );
  const operations = readJson('docs/operations/p0b-ops-role-delegate-absence-gate.json');
  assertCondition(
    operations.evaluation?.assignedRoleCount === 0
      && operations.evaluation?.humanAbsenceTestsPassed === 0,
    'operations_external_state_drift',
  );
  const signing = readJson('docs/evidence/p0b-next/signed-device-evidence.json');
  assertCondition(
    signing.releaseGate?.androidCurrentSourceSignedCandidate === true
      && signing.releaseGate?.androidCurrentSourcePhysicalEvidence === true
      && signing.releaseGate?.iosCurrentSourceSignedCandidate === false
      && signing.releaseGate?.iosCurrentSourcePhysicalEvidence === false,
    'signed_device_state_drift',
  );
  const scannerState = readJson('docs/evidence/external-gates/support-evidence-scanner-readiness.json');
  assertCondition(
    scannerState.evaluation?.requiredDecisionCount === 8
      && scannerState.evaluation?.completedDecisionCount === 0
      && scannerState.evaluation?.intakeActivationAllowed === false,
    'scanner_external_state_drift',
  );
  const psp = readJson('docs/evidence/p0b-next/psp-sandbox-e2e-evidence.json');
  assertCondition(
    psp.evaluation?.requiredScenarioCount === 8
      && psp.evaluation?.passedScenarioCount === 0
      && psp.evaluation?.realMoneyReady === false,
    'psp_external_state_drift',
  );
  const privacy = readJson('store/privacy-disclosures.json');
  const retention = readJson('store/retention-deletion-readiness.json');
  assertCondition(
    privacy.approvalAllowed === false
      && Object.keys(privacy.requiredDecisions ?? {}).length === 6
      && retention.approvalAllowed === false
      && Object.keys(retention.requiredDecisions ?? {}).length === 10,
    'privacy_retention_state_drift',
  );
  const store = readJson('store/submission.json');
  assertCondition(
    store.submissionAllowed === false
      && store.blockingGates?.googlePlayAccountAndFee === 'closed'
      && Object.values(store.blockingGates ?? {}).filter((value) => value === 'open').length === 11,
    'store_external_state_drift',
  );
  const dossier = readJson('docs/evidence/p0b/pilot-go-no-go-dossier.json');
  assertCondition(
    dossier.economicsAndFounderIndependence?.state === 'unavailable'
      && dossier.economicsAndFounderIndependence?.profitability === 'undetermined'
      && dossier.finalGate?.goNow === false,
    'economics_or_activation_state_drift',
  );
  const pilot = readJson('docs/evidence/p0b-next/invited-synthetic-pilot-spiegelberg-cat8-readiness.json');
  assertCondition(
    pilot.evaluation?.requiredPrerequisiteCount === 4
      && pilot.evaluation?.passedPrerequisiteCount === 0
      && pilot.evaluation?.controlledPilotEligible === false
      && allFalse(pilot.boundaries),
    'pilot_external_state_drift',
  );

  const runbook = readFileSync(path.join(root, runbookPath), 'utf8');
  for (const gate of board.gates) {
    assertCondition(runbook.includes(`\`${gate.id}\``), `runbook_gate_missing:${gate.id}`);
    assertCondition(runbook.includes(`\`${gate.releaseToken}\``), `runbook_token_missing:${gate.id}`);
  }
  for (const marker of [
    'BLOCKIERT STUFE A',
    'BLOCKIERT NUR STUFE B',
    'BLOCKIERT NUR STUFE C',
    'KANN FÜR STUFE A ZURÜCKGESTELLT WERDEN',
    'TECHNISCH BEREIT, EXTERNE EVIDENZ FEHLT',
  ]) {
    assertCondition(runbook.includes(marker), `runbook_classification_missing:${marker}`);
  }

  if (requireStageAReady) {
    throw new Error(`stage_a_external_gates_not_ready:${stageABlockers.join(',')}`);
  }

  return Object.freeze({
    status: 'pilot-freeze-external-evidence-required',
    gateCount: 11,
    technicallyPreparedGateCount: 11,
    externallyReadyGateCount: 0,
    stageABlockerCount: 7,
    stageBOnlyBlockerCount: 1,
    stageCOnlyBlockerCount: 1,
    stageADeferredCount: 2,
    issuedReleaseTokenCount: 0,
    releaseDecision: 'hold-no-go',
  });
}

function runCli() {
  const args = process.argv.slice(2);
  const allowed = new Set(['--require-stage-a-ready']);
  const unknown = args.find((argument) => !allowed.has(argument));
  if (unknown !== undefined) throw new Error(`unknown_argument:${unknown}`);
  const result = validateExternalGateExecutionBoard({
    requireStageAReady: args.includes('--require-stage-a-ready'),
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
