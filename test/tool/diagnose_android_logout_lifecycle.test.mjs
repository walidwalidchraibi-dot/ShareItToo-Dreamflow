import assert from 'node:assert/strict';
import test from 'node:test';

import { sendOppositeRoleMessage } from '../../tool/diagnose_android_logout_lifecycle.mjs';

test('logout push suppression sends only from the opposite synthetic role', async () => {
  const calls = [];
  const sender = async (options) => {
    calls.push(options);
    return {
      status: 'synthetic-booking-diagnostic-message-sent',
      paymentEndpointCalled: false,
      stripeLivemode: false,
    };
  };

  await sendOppositeRoleMessage('/private/vault.json', 'owner', sender);
  await sendOppositeRoleMessage('/private/vault.json', 'renter', sender);

  assert.deepEqual(calls, [
    {
      vaultFile: '/private/vault.json',
      senderRole: 'renter',
      diagnosticKind: 'logout',
    },
    {
      vaultFile: '/private/vault.json',
      senderRole: 'owner',
      diagnosticKind: 'logout',
    },
  ]);
});

test('logout push suppression rejects an unknown signed-in role', async () => {
  await assert.rejects(
    () => sendOppositeRoleMessage('/private/vault.json', 'admin', async () => null),
    /signed-in synthetic role is invalid/,
  );
});
