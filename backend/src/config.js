import fs from 'node:fs';
import path from 'node:path';

import { validateFirebaseServiceAccount } from './firebase_service_account.js';

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function csv(value) {
  return (value ?? '')
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);
}

const jwtSecret = required('JWT_SECRET');
if (jwtSecret.length < 32) {
  throw new Error('JWT_SECRET must contain at least 32 characters');
}

const deploymentEnvironment = (process.env.DEPLOYMENT_ENVIRONMENT ?? process.env.NODE_ENV ?? 'development')
  .trim()
  .toLowerCase();
const bookingPilotMode = (process.env.BOOKING_PILOT_MODE ?? (
  deploymentEnvironment === 'staging' || deploymentEnvironment === 'test' || deploymentEnvironment === 'development'
    ? 'pilot'
    : 'off'
)).trim().toLowerCase();
if (!['off', 'pilot', 'on'].includes(bookingPilotMode)) {
  throw new Error('BOOKING_PILOT_MODE must be off, pilot, or on');
}
const pushTransport = (process.env.PUSH_TRANSPORT ?? (
  deploymentEnvironment === 'staging' || deploymentEnvironment === 'test'
    ? 'memory'
    : 'disabled'
)).trim().toLowerCase();
if (!['disabled', 'memory', 'webhook', 'fcm'].includes(pushTransport)) {
  throw new Error('PUSH_TRANSPORT must be disabled, memory, webhook, or fcm');
}
const pushWebhookUrl = process.env.PUSH_WEBHOOK_URL?.trim() ?? '';
if (pushTransport === 'webhook') {
  let parsed;
  try {
    parsed = new URL(pushWebhookUrl);
  } catch {
    throw new Error('PUSH_WEBHOOK_URL must be a valid HTTPS URL');
  }
  if (parsed.protocol !== 'https:') {
    throw new Error('PUSH_WEBHOOK_URL must be a valid HTTPS URL');
  }
}
const firebaseProjectId = process.env.FIREBASE_PROJECT_ID?.trim() ?? '';
const firebaseServiceAccountFile = process.env.FIREBASE_SERVICE_ACCOUNT_FILE?.trim() ?? '';
const firebaseAuthEnabled = (process.env.FIREBASE_AUTH_ENABLED ?? 'false')
  .trim()
  .toLowerCase() === 'true';
const firebasePhoneVerificationEnabled = (
  process.env.FIREBASE_PHONE_VERIFICATION_ENABLED ?? 'false'
).trim().toLowerCase() === 'true';
if (pushTransport === 'fcm' || firebaseAuthEnabled || firebasePhoneVerificationEnabled) {
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(firebaseProjectId)) {
    throw new Error('FIREBASE_PROJECT_ID must be configured for Firebase services');
  }
  if (!firebaseServiceAccountFile) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_FILE must be configured for Firebase services');
  }
  const resolvedServiceAccountFile = path.resolve(firebaseServiceAccountFile);
  let serviceAccountFileIsReadable = false;
  try {
    fs.accessSync(resolvedServiceAccountFile, fs.constants.R_OK);
    serviceAccountFileIsReadable = fs.statSync(resolvedServiceAccountFile).isFile();
  } catch {
    serviceAccountFileIsReadable = false;
  }
  if (!serviceAccountFileIsReadable) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_FILE must point to a readable file');
  }
  try {
    validateFirebaseServiceAccount(
      fs.readFileSync(resolvedServiceAccountFile, 'utf8'),
      firebaseProjectId,
    );
  } catch {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_FILE must contain credentials for FIREBASE_PROJECT_ID');
  }
}

const paymentTransport = (process.env.PAYMENT_TRANSPORT ?? (
  deploymentEnvironment === 'staging' || deploymentEnvironment === 'test'
    ? 'memory'
    : 'disabled'
)).trim().toLowerCase();
if (!['disabled', 'memory', 'stripe'].includes(paymentTransport)) {
  throw new Error('PAYMENT_TRANSPORT must be disabled, memory, or stripe');
}
const stripeSecretKey = process.env.STRIPE_SECRET_KEY?.trim() ?? '';
const stripeWebhookSecret = process.env.STRIPE_WEBHOOK_SECRET?.trim() ?? '';
const stripeLivemode = (process.env.STRIPE_LIVEMODE ?? 'false').trim().toLowerCase() === 'true';
if (paymentTransport === 'stripe') {
  if (!/^sk_(?:test|live)_[A-Za-z0-9]+$/.test(stripeSecretKey)) {
    throw new Error('STRIPE_SECRET_KEY must be a valid server-side Stripe key');
  }
  if (!/^whsec_[A-Za-z0-9]+$/.test(stripeWebhookSecret)) {
    throw new Error('STRIPE_WEBHOOK_SECRET must be configured for Stripe transport');
  }
  if (stripeLivemode !== stripeSecretKey.startsWith('sk_live_')) {
    throw new Error('STRIPE_LIVEMODE must match STRIPE_SECRET_KEY');
  }
}
const paymentCurrency = (process.env.PAYMENT_CURRENCY ?? 'EUR').trim().toUpperCase();
if (!/^[A-Z]{3}$/.test(paymentCurrency)) throw new Error('PAYMENT_CURRENCY must be an ISO 4217 code');
const connectCountry = (process.env.STRIPE_CONNECT_COUNTRY ?? 'DE').trim().toUpperCase();
if (!/^[A-Z]{2}$/.test(connectCountry)) throw new Error('STRIPE_CONNECT_COUNTRY must be an ISO country code');
const paymentPilotUserIds = csv(process.env.PAYMENT_PILOT_USER_IDS);
if (paymentTransport === 'stripe' && stripeLivemode && paymentPilotUserIds.length === 0) {
  throw new Error('PAYMENT_PILOT_USER_IDS is required for live Stripe transport');
}

const publicComplianceApproved = (process.env.PUBLIC_COMPLIANCE_APPROVED ?? 'false')
  .trim()
  .toLowerCase() === 'true';
const publicCompliance = {
  approved: publicComplianceApproved,
  supportEmail: process.env.PUBLIC_SUPPORT_EMAIL?.trim() ?? '',
  privacyEmail: process.env.PUBLIC_PRIVACY_EMAIL?.trim() ?? '',
  providerName: process.env.PUBLIC_LEGAL_PROVIDER_NAME?.trim() ?? '',
  providerAddress: process.env.PUBLIC_LEGAL_PROVIDER_ADDRESS?.trim() ?? '',
  representative: process.env.PUBLIC_LEGAL_REPRESENTATIVE?.trim() ?? '',
  contentResponsible: process.env.PUBLIC_LEGAL_CONTENT_RESPONSIBLE?.trim() ?? '',
  effectiveDate: process.env.PUBLIC_PRIVACY_EFFECTIVE_DATE?.trim() ?? '',
};

const googleMapsServerApiKey = process.env.GOOGLE_MAPS_SERVER_API_KEY?.trim() ?? '';
if (googleMapsServerApiKey && !/^AIza[0-9A-Za-z_-]{20,}$/u.test(googleMapsServerApiKey)) {
  throw new Error('GOOGLE_MAPS_SERVER_API_KEY must be a valid server-side Google API key');
}
if (publicComplianceApproved) {
  const requiredComplianceFields = [
    ['PUBLIC_SUPPORT_EMAIL', publicCompliance.supportEmail],
    ['PUBLIC_PRIVACY_EMAIL', publicCompliance.privacyEmail],
    ['PUBLIC_LEGAL_PROVIDER_NAME', publicCompliance.providerName],
    ['PUBLIC_LEGAL_PROVIDER_ADDRESS', publicCompliance.providerAddress],
    ['PUBLIC_LEGAL_REPRESENTATIVE', publicCompliance.representative],
    ['PUBLIC_LEGAL_CONTENT_RESPONSIBLE', publicCompliance.contentResponsible],
    ['PUBLIC_PRIVACY_EFFECTIVE_DATE', publicCompliance.effectiveDate],
  ];
  const missingComplianceFields = requiredComplianceFields
    .filter(([, value]) => !value)
    .map(([name]) => name);
  if (missingComplianceFields.length > 0) {
    throw new Error(
      `PUBLIC_COMPLIANCE_APPROVED requires: ${missingComplianceFields.join(', ')}`,
    );
  }
  for (const [name, value] of [
    ['PUBLIC_SUPPORT_EMAIL', publicCompliance.supportEmail],
    ['PUBLIC_PRIVACY_EMAIL', publicCompliance.privacyEmail],
  ]) {
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      throw new Error(`${name} must be a valid email address`);
    }
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(publicCompliance.effectiveDate)) {
    throw new Error('PUBLIC_PRIVACY_EFFECTIVE_DATE must use YYYY-MM-DD');
  }
}

export const config = Object.freeze({
  port: Number.parseInt(process.env.PORT ?? '8080', 10),
  databaseUrl: required('DATABASE_URL'),
  jwtSecret,
  corsOrigins: csv(process.env.CORS_ORIGINS),
  publicBaseUrl: (process.env.PUBLIC_BASE_URL ?? 'https://shareittoo.com/api/v1').replace(/\/$/, ''),
  uploadDir: path.resolve(process.env.UPLOAD_DIR ?? '/data/uploads'),
  accessTokenLifetime: '15m',
  accessTokenLifetimeSeconds: 15 * 60,
  refreshTokenLifetimeDays: 30,
  emailVerificationLifetimeHours: 24,
  passwordResetLifetimeMinutes: 30,
  accountDeletionLifetimeMinutes: 30,
  staffElevationMinutes: Math.min(30, Math.max(5, Number.parseInt(process.env.STAFF_ELEVATION_MINUTES ?? '10', 10))),
  minimumAccountAge: 18,
  deploymentEnvironment,
  bookingPilotMode,
  bookingPilotEnabled: bookingPilotMode !== 'off',
  bookingPilotWithoutPayment: bookingPilotMode === 'pilot',
  failedLoginLimit: 10,
  failedLoginLockMinutes: 15,
  appPublicUrl: (process.env.APP_PUBLIC_URL ?? 'https://shareittoo.com').replace(/\/$/, ''),
  publicCompliance: Object.freeze(publicCompliance),
  maps: Object.freeze({
    enabled: googleMapsServerApiKey !== '',
    serverApiKey: googleMapsServerApiKey,
  }),
  mail: Object.freeze({
    transport: (process.env.MAIL_TRANSPORT ?? 'disabled').trim().toLowerCase(),
    host: process.env.SMTP_HOST?.trim() ?? '',
    port: Number.parseInt(process.env.SMTP_PORT ?? '587', 10),
    secure: (process.env.SMTP_SECURE ?? 'false').trim().toLowerCase() === 'true',
    requireTls: (process.env.SMTP_REQUIRE_TLS ?? 'true').trim().toLowerCase() !== 'false',
    user: process.env.SMTP_USER?.trim() ?? '',
    password: process.env.SMTP_PASSWORD ?? '',
    from: process.env.MAIL_FROM?.trim() ?? 'ShareItToo <contact@shareittoo.com>',
    replyTo: process.env.MAIL_REPLY_TO?.trim() ?? 'contact@shareittoo.com',
  }),
  notifications: Object.freeze({
    workerIntervalMs: Math.max(500, Number.parseInt(process.env.NOTIFICATION_WORKER_INTERVAL_MS ?? '5000', 10)),
    batchSize: Math.min(100, Math.max(1, Number.parseInt(process.env.NOTIFICATION_BATCH_SIZE ?? '25', 10))),
    maxAttempts: Math.min(20, Math.max(1, Number.parseInt(process.env.NOTIFICATION_MAX_ATTEMPTS ?? '5', 10))),
  }),
  push: Object.freeze({
    transport: pushTransport,
    webhookUrl: pushWebhookUrl,
    webhookToken: process.env.PUSH_WEBHOOK_TOKEN ?? '',
    firebaseProjectId,
    firebaseServiceAccountFile: firebaseServiceAccountFile
      ? path.resolve(firebaseServiceAccountFile)
      : '',
  }),
  socialAuth: Object.freeze({
    enabled: firebaseAuthEnabled,
    firebaseProjectId,
    firebaseServiceAccountFile: firebaseServiceAccountFile
      ? path.resolve(firebaseServiceAccountFile)
      : '',
    allowedProviders: Object.freeze(['google', 'apple', 'facebook']),
  }),
  phoneVerification: Object.freeze({
    enabled: firebasePhoneVerificationEnabled,
    firebaseProjectId,
    firebaseServiceAccountFile: firebaseServiceAccountFile
      ? path.resolve(firebaseServiceAccountFile)
      : '',
  }),
  payments: Object.freeze({
    transport: paymentTransport,
    enabled: paymentTransport !== 'disabled',
    livemode: stripeLivemode,
    secretKey: stripeSecretKey,
    webhookSecret: stripeWebhookSecret,
    apiVersion: process.env.STRIPE_API_VERSION?.trim() ?? '',
    currency: paymentCurrency,
    connectCountry,
    pilotUserIds: Object.freeze(paymentPilotUserIds),
    payoutHoldHours: Math.min(24 * 30, Math.max(0, Number.parseInt(process.env.PAYOUT_HOLD_HOURS ?? '48', 10))),
  }),
});
