import crypto from 'node:crypto';

import { config } from './config.js';

function pushError(code, cause = undefined) {
  const error = new Error(code, cause ? { cause } : undefined);
  error.code = code;
  return error;
}

function safePushText(value, maxLength) {
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized || normalized.length > maxLength) throw pushError('push_payload_invalid');
  return normalized;
}

export async function sendPushToUser(client, {
  userId,
  eventKey,
  title,
  body,
  actionUrl,
  data = {},
}) {
  const devices = await client.query(
    `SELECT id, platform, token, token_hash, locale
     FROM push_devices
     WHERE user_id = $1 AND enabled = true
     ORDER BY last_seen_at DESC`,
    [userId],
  );
  if (config.push.transport === 'disabled') {
    return { outcome: 'suppressed', provider: 'disabled', deviceCount: devices.rowCount };
  }
  if (!devices.rowCount) {
    return { outcome: 'suppressed', provider: config.push.transport, deviceCount: 0 };
  }

  const payload = {
    eventKey: safePushText(eventKey, 240),
    title: safePushText(title, 240),
    body: safePushText(body, 2000),
    actionUrl: safePushText(actionUrl, 2000),
    data: data && typeof data === 'object' && !Array.isArray(data) ? data : {},
  };

  if (config.push.transport === 'memory') {
    return {
      outcome: 'sent',
      provider: 'memory',
      deviceCount: devices.rowCount,
      providerMessageId: `memory:${crypto.createHash('sha256').update(eventKey).digest('hex').slice(0, 24)}`,
    };
  }

  let response;
  try {
    response = await fetch(config.push.webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(config.push.webhookToken
          ? { Authorization: `Bearer ${config.push.webhookToken}` }
          : {}),
      },
      body: JSON.stringify({
        ...payload,
        devices: devices.rows.map((device) => ({
          platform: device.platform,
          token: device.token,
          tokenHash: device.token_hash,
          locale: device.locale,
        })),
      }),
      signal: AbortSignal.timeout(15_000),
    });
  } catch (error) {
    throw pushError('push_webhook_unavailable', error);
  }
  if (!response.ok) throw pushError(`push_webhook_http_${response.status}`);

  let result = {};
  try {
    result = await response.json();
  } catch {
    result = {};
  }
  const invalidHashes = Array.isArray(result.invalidTokenHashes)
    ? result.invalidTokenHashes.filter((value) => /^[0-9a-f]{64}$/.test(String(value)))
    : [];
  if (invalidHashes.length) {
    await client.query(
      `UPDATE push_devices SET enabled = false
       WHERE user_id = $1 AND token_hash = ANY($2::text[])`,
      [userId, invalidHashes],
    );
  }
  return {
    outcome: 'sent',
    provider: 'webhook',
    deviceCount: devices.rowCount,
    providerMessageId: typeof result.messageId === 'string'
      ? result.messageId.slice(0, 500)
      : null,
    invalidDeviceCount: invalidHashes.length,
  };
}
