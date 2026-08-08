import crypto from 'node:crypto';
import { promisify } from 'node:util';

import jwt from 'jsonwebtoken';

import { config } from './config.js';

const scrypt = promisify(crypto.scrypt);
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

export function isValidEmail(value) {
  const email = normalizeEmail(value);
  return email.length <= 254 && emailPattern.test(email);
}

export function isValidPassword(value) {
  return typeof value === 'string' && value.length >= 8 && value.length <= 200;
}

export async function hashPassword(password) {
  if (!isValidPassword(password)) throw new Error('Invalid password');
  const salt = crypto.randomBytes(16);
  const derived = await scrypt(password, salt, 64);
  return `scrypt$${salt.toString('hex')}$${Buffer.from(derived).toString('hex')}`;
}

export async function verifyPassword(password, encoded) {
  if (typeof password !== 'string' || typeof encoded !== 'string') return false;
  const [scheme, saltHex, hashHex] = encoded.split('$');
  if (scheme !== 'scrypt' || !saltHex || !hashHex) return false;
  try {
    const expected = Buffer.from(hashHex, 'hex');
    const actual = Buffer.from(await scrypt(password, Buffer.from(saltHex, 'hex'), expected.length));
    return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
  } catch {
    return false;
  }
}

export function signAccessToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email, type: 'access' },
    config.jwtSecret,
    {
      algorithm: 'HS256',
      issuer: 'shareittoo-api',
      audience: 'shareittoo-app',
      expiresIn: config.accessTokenLifetime,
    },
  );
}

export function verifyAccessToken(token) {
  const payload = jwt.verify(token, config.jwtSecret, {
    algorithms: ['HS256'],
    issuer: 'shareittoo-api',
    audience: 'shareittoo-app',
  });
  if (payload.type !== 'access' || typeof payload.sub !== 'string') {
    throw new Error('Invalid access token');
  }
  return payload;
}

export function newRefreshToken() {
  return crypto.randomBytes(48).toString('base64url');
}

export function newActionToken() {
  return crypto.randomBytes(48).toString('base64url');
}

export function hashRefreshToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function hashActionToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function bearerToken(req) {
  const value = req.get('authorization') ?? '';
  const match = /^Bearer\s+(.+)$/i.exec(value);
  return match?.[1] ?? null;
}

export function requireAuth(req, res, next) {
  const token = bearerToken(req);
  if (!token) return res.status(401).json({ error: 'authentication_required' });
  try {
    const payload = verifyAccessToken(token);
    req.auth = { userId: payload.sub, email: payload.email };
    return next();
  } catch {
    return res.status(401).json({ error: 'invalid_or_expired_session' });
  }
}

export function defaultProfile({ email }) {
  const localPart = normalizeEmail(email).split('@')[0] || 'Mitglied';
  const displayName = localPart
    .replace(/[._-]+/g, ' ')
    .replace(/\b\p{L}/gu, (letter) => letter.toUpperCase())
    .slice(0, 80);
  return {
    displayName,
    preferredLanguage: 'de-DE',
    emailVerified: false,
    phoneVerified: false,
    isVerified: false,
    isBanned: false,
    role: 'user',
    avgRating: 0,
    reviewCount: 0,
    languages: ['Deutsch'],
    interests: [],
    showWork: false,
    showHobbies: false,
    showHomeLocation: false,
    showBioPublic: true,
    showLanguagesPublic: true,
    showInterestsPublic: true,
    showFavoriteSong: false,
  };
}

const privateProfileKeys = new Set([
  'phone',
  'birthDate',
  'homeLat',
  'homeLng',
  'addressStreet',
  'addressHouseNumber',
  'addressPostalCode',
  'addressCity',
  'addressCountry',
  'addressExtra',
  'payoutAccountId',
]);

const protectedProfileKeys = new Set([
  'id',
  'email',
  'createdAt',
  'role',
  'isBanned',
  'isVerified',
  'emailVerified',
  'phoneVerified',
  'avgRating',
  'reviewCount',
  'isDeactivated',
  'deactivatedAt',
]);

export function sanitizeProfileUpdate(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const output = {};
  for (const [key, raw] of Object.entries(value)) {
    if (protectedProfileKeys.has(key)) continue;
    if (typeof raw === 'string') output[key] = raw.trim().slice(0, 2000);
    else if (typeof raw === 'boolean' || typeof raw === 'number' || raw === null) output[key] = raw;
    else if (Array.isArray(raw)) output[key] = raw.slice(0, 50).map((item) => String(item).slice(0, 120));
  }
  return output;
}

export function shapeUser(row, { publicOnly = false } = {}) {
  const profile = { ...defaultProfile({ email: row.email }), ...(row.profile ?? {}) };
  if (publicOnly) {
    for (const key of privateProfileKeys) delete profile[key];
  }
  return {
    ...profile,
    id: row.id,
    email: publicOnly ? '' : row.email,
    createdAt: new Date(row.created_at).toISOString(),
    isDeactivated: Boolean(row.deactivated_at),
    deactivatedAt: row.deactivated_at ? new Date(row.deactivated_at).toISOString() : null,
    emailVerified: Boolean(row.email_verified_at),
  };
}

export function safeText(value, maxLength = 4000) {
  return typeof value === 'string' ? value.trim().slice(0, maxLength) : '';
}
