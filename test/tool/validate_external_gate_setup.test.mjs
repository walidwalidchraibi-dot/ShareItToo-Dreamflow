import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { validateExternalGateSetup } from '../../tool/validate_external_gate_setup.mjs';

const manifest = JSON.parse(readFileSync(
  new URL('../../docs/evidence/external-gates/technical-setup-manifest.json', import.meta.url),
  'utf8',
));
const regression = readFileSync(
  new URL('../../scripts/technical_regression_check.sh', import.meta.url),
  'utf8',
);
const storeReadme = readFileSync(
  new URL('../../store/README.md', import.meta.url),
  'utf8',
);
const supportTraceability = JSON.parse(readFileSync(
  new URL(
    '../../docs/evidence/support/support-test-matrix-v1-traceability.json',
    import.meta.url,
  ),
  'utf8',
));
const supportEvidenceReadiness = JSON.parse(readFileSync(
  new URL(
    '../../docs/evidence/external-gates/support-evidence-scanner-readiness.json',
    import.meta.url,
  ),
  'utf8',
));

function copy(value) {
  return structuredClone(value);
}

test('accepts exactly eleven technically prepared and externally open gates', () => {
  assert.deepEqual(validateExternalGateSetup(), {
    status: 'prepared-hold',
    requiredGateCount: 11,
    technicallyPreparedGateCount: 11,
    externallyReadyGateCount: 0,
    supportScenarioCount: 167,
    supportExternalEvidenceRequiredCount: 47,
    supportExternalEvidencePresentCount: 0,
    supportEvidenceRequiredDecisionCount: 8,
    supportEvidenceCompletedDecisionCount: 0,
    releaseDecision: 'hold-no-go',
  });
});

test('strict mode fails closed with every unresolved external gate', () => {
  assert.throws(
    () => validateExternalGateSetup({ requireReady: true }),
    /external_gates_not_ready:legal_and_operator_approval/u,
  );
});

test('cannot mark a gate ready without changing its canonical source truth', () => {
  const changed = copy(manifest);
  changed.gates[2].ready = true;
  changed.gates[2].externalEvidenceRef = 'docs/evidence/example.json';
  assert.throws(
    () => validateExternalGateSetup({ manifestOverride: changed }),
    /manifest_ready_without_current_source:ios_apple_signing_and_device/u,
  );
});

test('rejects credential-shaped or personal fields anywhere in the manifest', () => {
  const changed = copy(manifest);
  changed.gates[0].password = 'not-allowed';
  assert.throws(
    () => validateExternalGateSetup({ manifestOverride: changed }),
    /credential_shaped_field:gates.0.password/u,
  );
});

test('external setup is bound to the exact support matrix hold', () => {
  const changed = copy(supportTraceability);
  changed.summary.externalEvidenceRequiredCount = 46;
  assert.throws(
    () => validateExternalGateSetup({
      sourceOverrides: {
        'docs/evidence/support/support-test-matrix-v1-traceability.json': changed,
      },
    }),
    /summary_invalid/u,
  );
});

test('every support-matrix consumer retains the common evidence reference', () => {
  const changed = copy(manifest);
  const pspGate = changed.gates.find(({ id }) => id === 'psp_contract_and_sandbox_e2e');
  pspGate.currentEvidenceRefs = pspGate.currentEvidenceRefs.filter(
    (reference) => !reference.includes('support-test-matrix-v1-traceability'),
  );
  assert.throws(
    () => validateExternalGateSetup({ manifestOverride: changed }),
    /support_traceability_ref_invalid:psp_contract_and_sandbox_e2e/u,
  );
});

test('aggregate setup is bound to the disabled scanner readiness gate', () => {
  const changed = copy(supportEvidenceReadiness);
  changed.evaluation.requiredDecisionCount = 7;
  assert.throws(
    () => validateExternalGateSetup({
      sourceOverrides: {
        'docs/evidence/external-gates/support-evidence-scanner-readiness.json': changed,
      },
    }),
    /evaluation_invalid/u,
  );
});

test('current Store documentation reflects the machine-readable Google state', () => {
  assert.match(storeReadme, /Google-Play-Konto ist aktuell `ready`/u);
  assert.doesNotMatch(
    storeReadme,
    /Offen bleiben\s+die persönliche Identitätsprüfung, Geräte- und Telefonnummernbestätigung sowie\s+der erste App-Datensatz/u,
  );
});

test('complete regression permanently retains draft and strict validators', () => {
  assert.match(
    regression,
    /node --test test\/tool\/validate_external_gate_setup\.test\.mjs/u,
  );
  assert.match(regression, /node tool\/validate_external_gate_setup\.mjs/u);
});
