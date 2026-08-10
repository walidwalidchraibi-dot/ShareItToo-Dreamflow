import assert from 'node:assert/strict';
import test from 'node:test';

process.env.DATABASE_URL ??= 'postgres://example:example@localhost:5432/example';
process.env.JWT_SECRET ??= 'test-secret-that-is-longer-than-thirty-two-characters';

const { revokeSessionByRefreshToken } = await import('../src/auth_session_actions.js');

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
  assert.match(calls[3].sql, /DELETE FROM push_devices WHERE session_id = \$1/);
  assert.deepEqual(calls.slice(1).map((call) => call.parameters), [
    ['session-1'],
    ['session-1'],
    ['session-1'],
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
