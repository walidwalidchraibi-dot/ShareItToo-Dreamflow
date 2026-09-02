import assert from 'node:assert/strict';
import test from 'node:test';

process.env.DATABASE_URL ??= 'postgres://example:example@localhost:5432/example';
process.env.JWT_SECRET ??= 'test-secret-that-is-longer-than-thirty-two-characters';

const {
  deletePushDevicesForSession,
  revokeAllSessionsForCredentialChange,
  revokeSessionByRefreshToken,
} = await import('../src/auth_session_actions.js');

test('logout revokes the session and removes its push devices', async () => {
  const calls = [];
  const client = {
    async query(sql, parameters) {
      calls.push({ sql, parameters });
      if (calls.length === 1) return { rows: [{ session_id: 'session-1' }], rowCount: 1 };
      return { rows: [], rowCount: 1 };
    },
  };

  const revoked = await revokeSessionByRefreshToken(client, 'refresh-token');

  assert.equal(revoked, true);
  assert.equal(calls.length, 4);
  assert.match(calls[0].sql, /SELECT session_id FROM refresh_tokens/);
  assert.match(calls[1].sql, /UPDATE auth_sessions/);
  assert.match(calls[2].sql, /UPDATE refresh_tokens/);
  assert.match(calls[3].sql, /DELETE FROM push_devices[\s\S]*session_id = \$1/);
  assert.deepEqual(calls.slice(1).map((call) => call.parameters), [
    ['session-1'],
    ['session-1'],
    ['session-1', null],
  ]);
});

test('current-session cleanup is user-bound and idempotent', async () => {
  const calls = [];
  const client = {
    async query(sql, parameters) {
      calls.push({ sql, parameters });
      return { rows: [], rowCount: 0 };
    },
  };

  const deleted = await deletePushDevicesForSession(client, {
    sessionId: 'session-1',
    userId: '11111111-1111-1111-1111-111111111111',
  });

  assert.equal(deleted, 0);
  assert.equal(calls.length, 1);
  assert.match(calls[0].sql, /session_id = \$1/);
  assert.match(calls[0].sql, /\$2::text IS NULL/);
  assert.match(calls[0].sql, /user_id = \$2::text/);
  assert.doesNotMatch(calls[0].sql, /user_id = \$2::uuid/);
  assert.match(calls[0].sql, /RETURNING id/);
  assert.deepEqual(calls[0].parameters, [
    'session-1',
    '11111111-1111-1111-1111-111111111111',
  ]);
});

test('unknown refresh tokens stay enumeration-safe and do not delete devices', async () => {
  const calls = [];
  const client = {
    async query(sql, parameters) {
      calls.push({ sql, parameters });
      return { rows: [], rowCount: 0 };
    },
  };

  const revoked = await revokeSessionByRefreshToken(client, 'unknown-refresh-token');

  assert.equal(revoked, false);
  assert.equal(calls.length, 1);
  assert.match(calls[0].sql, /FOR UPDATE/);
});

test('credential recovery revokes only the target account and removes its push devices', async () => {
  const calls = [];
  const client = {
    async query(sql, parameters) {
      calls.push({ sql, parameters });
      return { rows: [], rowCount: calls.length };
    },
  };

  const result = await revokeAllSessionsForCredentialChange(client, {
    userId: 'target-user',
    reason: 'password_reset',
  });

  assert.deepEqual(result, {
    userId: 'target-user',
    reason: 'password_reset',
    revokedSessionCount: 1,
    revokedRefreshTokenCount: 2,
    deletedPushDeviceCount: 3,
  });
  assert.equal(calls.length, 3);
  assert.match(calls[0].sql, /UPDATE auth_sessions[\s\S]*WHERE user_id = \$1 AND revoked_at IS NULL/u);
  assert.match(calls[1].sql, /UPDATE refresh_tokens[\s\S]*WHERE user_id = \$1 AND revoked_at IS NULL/u);
  assert.match(calls[2].sql, /DELETE FROM push_devices[\s\S]*WHERE user_id = \$1/u);
  assert.deepEqual(calls.map((call) => call.parameters), [
    ['target-user', 'password_reset'],
    ['target-user', 'password_reset'],
    ['target-user'],
  ]);
  assert.ok(calls.every((call) => !call.sql.includes('email')));
});

test('credential recovery rejects caller-selected revocation reasons', async () => {
  await assert.rejects(
    revokeAllSessionsForCredentialChange({ query: async () => assert.fail() }, {
      userId: 'target-user',
      reason: 'support_override',
    }),
    /invalid_account_credential_change_scope/u,
  );
});
