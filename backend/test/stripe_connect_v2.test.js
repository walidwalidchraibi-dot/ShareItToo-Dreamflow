import assert from 'node:assert/strict';
import test from 'node:test';

import {
  connectedAccountSnapshot,
  isConnectedAccountProviderEvent,
} from '../src/payment_workflow.js';

function account(status = 'active') {
  return {
    id: 'acct_test',
    object: 'v2.core.account',
    applied_configurations: ['recipient'],
    configuration: {
      recipient: {
        applied: true,
        capabilities: {
          stripe_balance: {
            stripe_transfers: {
              status,
              status_details: status === 'active' ? [] : [{ code: 'requirements_past_due' }],
            },
          },
        },
      },
    },
    dashboard: 'express',
    defaults: {
      currency: 'eur',
      responsibilities: {
        fees_collector: 'application',
        losses_collector: 'application',
      },
    },
    identity: { country: 'DE', entity_type: 'individual' },
    requirements: { entries: [] },
    future_requirements: { entries: [] },
  };
}

test('Accounts v2 active recipient capability is the only ready snapshot', () => {
  assert.deepEqual(connectedAccountSnapshot(account()), {
    apiVersion: 'v2',
    country: 'DE',
    currency: 'EUR',
    dashboard: 'express',
    feesCollector: 'application',
    lossesCollector: 'application',
    transfersStatus: 'active',
    detailsSubmitted: true,
    chargesEnabled: false,
    payoutsEnabled: true,
    requirements: { entries: [] },
    futureRequirements: { entries: [] },
    disabledReason: null,
  });
});

test('pending or restricted Accounts v2 capability remains not ready', () => {
  const snapshot = connectedAccountSnapshot(account('restricted'));
  assert.equal(snapshot.transfersStatus, 'restricted');
  assert.equal(snapshot.detailsSubmitted, false);
  assert.equal(snapshot.payoutsEnabled, false);
  assert.equal(snapshot.disabledReason, 'requirements_past_due');
});

test('active capability still fails closed when platform responsibility drifts', () => {
  const drifted = account();
  drifted.defaults.responsibilities.losses_collector = 'stripe';
  const snapshot = connectedAccountSnapshot(drifted);
  assert.equal(snapshot.transfersStatus, 'active');
  assert.equal(snapshot.detailsSubmitted, false);
  assert.equal(snapshot.payoutsEnabled, false);
});

test('closed or unapplied recipient accounts cannot remain payout-ready', () => {
  const closed = account();
  closed.closed = true;
  assert.equal(connectedAccountSnapshot(closed).transfersStatus, 'restricted');
  assert.equal(connectedAccountSnapshot(closed).payoutsEnabled, false);

  const unapplied = account();
  unapplied.configuration.recipient.applied = false;
  assert.equal(connectedAccountSnapshot(unapplied).transfersStatus, 'restricted');
  assert.equal(connectedAccountSnapshot(unapplied).payoutsEnabled, false);
});

test('legacy Accounts v1 fields cannot be promoted into Accounts v2 truth', () => {
  const snapshot = connectedAccountSnapshot({
    id: 'acct_legacy',
    object: 'account',
    details_submitted: true,
    payouts_enabled: true,
    capabilities: { transfers: 'active' },
    requirements: {},
  });
  assert.equal(snapshot.apiVersion, 'v1');
  assert.equal(snapshot.transfersStatus, 'active');
  assert.equal(snapshot.detailsSubmitted, false);
  assert.equal(snapshot.payoutsEnabled, false);
});

test('all readiness-affecting Accounts v2 thin events are recognized', () => {
  for (const type of [
    'v2.core.account.created',
    'v2.core.account.updated',
    'v2.core.account.closed',
    'v2.core.account[configuration.recipient].capability_status_updated',
    'v2.core.account[configuration.recipient].updated',
    'v2.core.account[defaults].updated',
    'v2.core.account[future_requirements].updated',
    'v2.core.account[identity].updated',
    'v2.core.account[requirements].updated',
  ]) {
    assert.equal(isConnectedAccountProviderEvent(type), true, type);
  }
  assert.equal(
    isConnectedAccountProviderEvent('v2.core.account[configuration.merchant].updated'),
    false,
  );
});
