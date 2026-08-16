import assert from 'node:assert/strict';
import test from 'node:test';

process.env.DATABASE_URL ??= 'postgres://example:example@localhost:5432/example';
process.env.JWT_SECRET ??= 'test-secret-that-is-longer-than-thirty-two-characters';

const {
  deletePushDevicesForSession,
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
  assert.match(calls[0].sql, /user_id = \$2::uuid/);
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
