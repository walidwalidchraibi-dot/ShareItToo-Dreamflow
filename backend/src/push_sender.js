import crypto from 'node:crypto';
import fs from 'node:fs/promises';

import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

import { config } from './config.js';
import { validateFirebaseServiceAccount } from './firebase_service_account.js';

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

let messagingClientPromise;

async function fcmMessagingClient() {
  if (!messagingClientPromise) {
    const initialization = (async () => {
      let serviceAccount;
      try {
        serviceAccount = validateFirebaseServiceAccount(
          await fs.readFile(config.push.firebaseServiceAccountFile, 'utf8'),
          config.push.firebaseProjectId,
        );
      } catch (error) {
        throw pushError('push_fcm_credentials_invalid', error);
      }
      const app = getApps().find((candidate) => candidate.name === 'shareittoo-push') ??
        initializeApp({
          credential: cert(serviceAccount),
          projectId: config.push.firebaseProjectId,
        }, 'shareittoo-push');
      return getMessaging(app);
    })();
    messagingClientPromise = initialization.catch((error) => {
      messagingClientPromise = undefined;
      throw error;
    });
  }
  return messagingClientPromise;
}

function fcmData(payload) {
  const values = {
    eventKey: payload.eventKey,
    actionUrl: payload.actionUrl,
    ...payload.data,
  };
  return Object.fromEntries(Object.entries(values).flatMap(([key, value]) => {
    const safeKey = String(key).trim();
    const reservedKey = /^(?:google\.|gcm\.)/i.test(safeKey) ||
      ['from', 'message_type', 'collapse_key'].includes(safeKey.toLowerCase());
    if (!safeKey || safeKey.length > 120 || reservedKey || value == null) return [];
    const stringValue = typeof value === 'string' ? value : JSON.stringify(value);
    if (!stringValue || stringValue.length > 2000) return [];
    return [[safeKey, stringValue]];
  }));
}

export function buildFcmMessageForTest(device, payload) {
  return {
    token: device.token,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: fcmData(payload),
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        clickAction: 'SIT_NOTIFICATION_CLICK',
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: { aps: { sound: 'default' } },
    },
  };
}

const invalidFcmTokenErrorCodes = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

function isInvalidFcmTokenError(error) {
  return invalidFcmTokenErrorCodes.has(error?.code);
}

async function sendWithFcm(client, devices, payload, userId) {
  const messaging = await fcmMessagingClient();
  const invalidHashes = [];
  const messageIds = [];
  let transientFailureCount = 0;
  for (let index = 0; index < devices.length; index += 500) {
    const batch = devices.slice(index, index + 500);
    let result;
    try {
      result = await messaging.sendEach(
        batch.map((device) => buildFcmMessageForTest(device, payload)),
      );
    } catch (error) {
      throw pushError('push_fcm_unavailable', error);
    }
    result.responses.forEach((response, responseIndex) => {
      if (response.success) {
        if (response.messageId) messageIds.push(response.messageId);
        return;
      }
      if (isInvalidFcmTokenError(response.error)) {
        invalidHashes.push(batch[responseIndex].token_hash);
      } else {
        transientFailureCount += 1;
      }
    });
  }
  if (invalidHashes.length) {
    await client.query(
      `UPDATE push_devices SET enabled = false
       WHERE user_id = $1 AND token_hash = ANY($2::text[])`,
      [userId, invalidHashes],
    );
  }
  if (!messageIds.length && transientFailureCount > 0) {
    throw pushError('push_fcm_unavailable');
  }
  return {
    outcome: messageIds.length ? 'sent' : 'suppressed',
    provider: 'fcm',
    deviceCount: devices.length,
    providerMessageId: messageIds[0] ?? null,
    invalidDeviceCount: invalidHashes.length,
    failedDeviceCount: transientFailureCount,
  };
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

  if (config.push.transport === 'fcm') {
    return sendWithFcm(client, devices.rows, payload, userId);
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
