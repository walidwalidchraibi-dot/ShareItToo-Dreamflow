import { hashRefreshToken } from './security.js';

export async function deletePushDevicesForSession(client, { sessionId, userId = null }) {
  const result = await client.query(
    `DELETE FROM push_devices
     WHERE session_id = $1
       AND ($2::uuid IS NULL OR user_id = $2::uuid)
     RETURNING id`,
    [sessionId, userId],
  );
  return result.rowCount;
}

export async function revokeSessionByRefreshToken(client, refreshToken) {
  const found = await client.query(
    `SELECT session_id FROM refresh_tokens WHERE token_hash = $1 FOR UPDATE`,
    [hashRefreshToken(refreshToken)],
  );
  const row = found.rows[0];
  if (!row) return false;

  await client.query(
    `UPDATE auth_sessions
     SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'logout')
     WHERE id = $1`,
    [row.session_id],
  );
  await client.query(
    `UPDATE refresh_tokens
     SET revoked_at = COALESCE(revoked_at, now()), revoked_reason = COALESCE(revoked_reason, 'logout')
     WHERE session_id = $1`,
    [row.session_id],
  );
  await deletePushDevicesForSession(client, { sessionId: row.session_id });
  return true;
}
