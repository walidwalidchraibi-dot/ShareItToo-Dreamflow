import path from 'node:path';

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
});
