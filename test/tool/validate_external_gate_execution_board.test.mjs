import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { validateExternalGateExecutionBoard } from '../../tool/validate_external_gate_execution_board.mjs';

const board = JSON.parse(readFileSync(
  new URL(
    '../../docs/evidence/external-gates/external-gate-execution-board.json',
    import.meta.url,
  ),
  'utf8',
));
const canonical = JSON.parse(readFileSync(
  new URL(
    '../../docs/evidence/external-gates/technical-setup-manifest.json',
    import.meta.url,
  ),
  'utf8',
));
const regression = readFileSync(
  new URL('../../scripts/technical_regression_check.sh', import.meta.url),
  'utf8',
);

function copy(value) {
  return structuredClone(value);
}

test('accepts eleven prepared gates with exact tier classifications and zero release tokens', () => {
  assert.deepEqual(validateExternalGateExecutionBoard(), {
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
});

test('strict Stage A mode lists every still-open Stage A gate', () => {
  assert.throws(
    () => validateExternalGateExecutionBoard({ requireStageAReady: true }),
    /stage_a_external_gates_not_ready:legal_and_operator_approval.*explicit_activation_decision/u,
  );
});

test('rejects canonical gate state drift', () => {
  const changed = copy(canonical);
  changed.gates[0].state = 'ready';
  assert.throws(
    () => validateExternalGateExecutionBoard({ canonicalOverride: changed }),
    /canonical_gate_state_drift:legal_and_operator_approval/u,
  );
});

test('rejects tier-classification drift', () => {
  const changed = copy(board);
  changed.gates[5].tierClassification = 'BLOCKIERT STUFE A';
  assert.throws(
    () => validateExternalGateExecutionBoard({ boardOverride: changed }),
    /tier_classification_invalid:psp_contract_and_sandbox_e2e/u,
  );
});

test('requires both Stage A deferrals to remain fail closed', () => {
  const changedIos = copy(board);
  changedIos.gates[2].stageADeferralCondition = 'Defer for now.';
  assert.throws(
    () => validateExternalGateExecutionBoard({ boardOverride: changedIos }),
    /ios_deferral_boundary_invalid/u,
  );

  const changedScanner = copy(board);
  changedScanner.gates[4].stageADeferralCondition = 'Scanner later.';
  assert.throws(
    () => validateExternalGateExecutionBoard({ boardOverride: changedScanner }),
    /scanner_deferral_boundary_invalid/u,
  );
});

test('rejects cyclic gate dependencies', () => {
  const changed = copy(board);
  changed.gates[0].dependencies = ['explicit_activation_decision'];
  assert.throws(
    () => validateExternalGateExecutionBoard({ boardOverride: changed }),
    /dependency_cycle:/u,
  );
});

test('rejects secret-shaped fields, issued tokens and external mutations', () => {
  const changedSecret = copy(board);
  changedSecret.password = 'forbidden';
  assert.throws(
    () => validateExternalGateExecutionBoard({ boardOverride: changedSecret }),
    /sensitive_field_forbidden:password/u,
  );

  const changedToken = copy(board);
  changedToken.gates[0].releaseTokenState = 'issued';
  assert.throws(
    () => validateExternalGateExecutionBoard({ boardOverride: changedToken }),
    /release_token_invalid:legal_and_operator_approval/u,
  );

  const changedBoundary = copy(board);
  changedBoundary.boundaries.storeChanged = true;
  assert.throws(
    () => validateExternalGateExecutionBoard({ boardOverride: changedBoundary }),
    /external_boundary_invalid/u,
  );
});

test('complete regression permanently executes the external gate board validator', () => {
  assert.match(
    regression,
    /node --check tool\/validate_external_gate_execution_board\.mjs/u,
  );
  assert.match(
    regression,
    /node --test test\/tool\/validate_external_gate_execution_board\.test\.mjs/u,
  );
  assert.match(
    regression,
    /node tool\/validate_external_gate_execution_board\.mjs/u,
  );
});
