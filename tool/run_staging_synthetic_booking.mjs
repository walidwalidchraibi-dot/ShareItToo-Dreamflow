#!/usr/bin/env node

import { randomBytes } from 'node:crypto';
import {
  chmodSync,
  lstatSync,
  readFileSync,
  realpathSync,
  writeFileSync,
} from 'node:fs';
import { isAbsolute, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repositoryRoot = realpathSync(resolve(fileURLToPath(new URL('..', import.meta.url))));
const stagingApiBaseUrl = 'https://staging.shareittoo.com/api/v1';
const allowedTransitions = new Map([
  ['accepted', { role: 'owner', previous: 'requested', result: 'accepted' }],
  ['running', { role: 'renter', previous: 'accepted', result: 'active' }],
  ['completed', { role: 'owner', previous: 'active', result: 'completed' }],
]);

function fail(message) {
  throw new Error(message);
}

function privateVaultFile(value) {
  if (typeof value !== 'string' || !isAbsolute(value)) {
    fail('The synthetic account vault must be an absolute path.');
  }
  const canonical = realpathSync(value);
  const rel = relative(repositoryRoot, canonical);
  if (rel === '' || (!rel.startsWith('..') && !isAbsolute(rel))) {
    fail('The synthetic account vault must remain outside the repository.');
  }
  const stat = lstatSync(canonical);
  if (!stat.isFile() || stat.isSymbolicLink() || (stat.mode & 0o077) !== 0) {
    fail('The synthetic account vault must be a private, regular file.');
  }
  return canonical;
}

function readVault(vaultFile) {
  const path = privateVaultFile(vaultFile);
  let vault;
  try {
    vault = JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    fail('The synthetic account vault is invalid.');
  }
  if (vault?.schemaVersion !== 1
      || vault?.kind !== 'sit-staging-synthetic-account-vault'
      || vault?.apiBaseUrl !== stagingApiBaseUrl
      || vault?.stripeLivemode !== false
      || !['fixture-verified-ready-for-login', 'email-link-verified-ready-for-login', 'synthetic-booking-active', 'synthetic-booking-completed'].includes(vault?.status)
      || !Array.isArray(vault?.accounts)
      || vault.accounts.length !== 2) {
    fail('The vault is not an isolated, verified Staging role set.');
  }
  const accounts = new Map();
  for (const account of vault.accounts) {
    if (!['owner', 'renter'].includes(account?.role)
        || typeof account?.email !== 'string'
        || typeof account?.password !== 'string'
        || account.email.length < 3
        || account.password.length < 12
        || accounts.has(account.role)) {
      fail('The vault does not contain exactly one valid account per synthetic role.');
    }
    accounts.set(account.role, account);
  }
  if (accounts.size !== 2) fail('The vault does not contain both synthetic roles.');
  return { path, vault, accounts };
}

function saveVault(path, vault) {
  writeFileSync(path, `${JSON.stringify(vault, null, 2)}\n`, { mode: 0o600 });
  chmodSync(path, 0o600);
}

function dateOnly(now, daysFromNow) {
  return new Date(now.getTime() + daysFromNow * 86_400_000).toISOString().slice(0, 10);
}

async function request(fetchImpl, path, {
  method = 'GET',
  token = null,
  body = undefined,
  headers = {},
  expected = [200],
} = {}) {
  if (typeof path !== 'string' || !path.startsWith('/') || path.includes('://')) {
    fail('A Staging API path is invalid.');
  }
  const response = await fetchImpl(`${stagingApiBaseUrl}${path}`, {
    method,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body !== undefined && !(body instanceof FormData)
        ? { 'Content-Type': 'application/json' }
        : {}),
      ...headers,
    },
    body: body === undefined || body instanceof FormData ? body : JSON.stringify(body),
  });
  const raw = await response.text();
  let value = null;
  try {
    value = raw ? JSON.parse(raw) : null;
  } catch {
    value = null;
  }
  if (!expected.includes(response.status)) {
    fail(`Staging ${method} ${path} failed with HTTP ${response.status}.`);
  }
  return value;
}

async function login(fetchImpl, account) {
  const session = await request(fetchImpl, '/auth/login', {
    method: 'POST',
    body: { email: account.email, password: account.password },
  });
  if (typeof session?.accessToken !== 'string' || session.accessToken.length < 20) {
    fail(`The ${account.role} Staging login did not return a usable session.`);
  }
  return session.accessToken;
}

export async function createSyntheticBookingFixture({
  vaultFile,
  imagePath = resolve(repositoryRoot, 'assets/images/shareittoo_app_icon_master.png'),
  fetchImpl = globalThis.fetch,
  now = new Date(),
  random = (size) => randomBytes(size),
} = {}) {
  if (typeof fetchImpl !== 'function') fail('A fetch implementation is required.');
  if (!(now instanceof Date) || !Number.isFinite(now.getTime())) fail('The fixture time is invalid.');
  const { path, vault, accounts } = readVault(vaultFile);
  if (vault.syntheticBooking && vault.syntheticBooking.workflowStatus !== 'cleaned') {
    fail('The vault already contains an active synthetic booking fixture.');
  }
  const ownerToken = await login(fetchImpl, accounts.get('owner'));
  const renterToken = await login(fetchImpl, accounts.get('renter'));

  const expectedTitle = `SIT Rollenprüfung ${vault.runId}`;
  const [mine, requests] = await Promise.all([
    request(fetchImpl, '/listings/mine', { token: ownerToken }),
    request(fetchImpl, '/rental-requests', { token: renterToken }),
  ]);
  const matchingListings = Array.isArray(mine?.listings)
    ? mine.listings.filter((listing) => listing?.title === expectedTitle)
    : [];
  const matchingRequests = Array.isArray(requests?.requests)
    ? requests.requests.filter((booking) => (
        matchingListings.some((listing) => listing?.id === booking?.itemId)
        && booking?.workflowStatus === 'requested'
      ))
    : [];
  if (matchingListings.length === 1 && matchingRequests.length === 1) {
    const listing = matchingListings[0];
    const booking = matchingRequests[0];
    vault.syntheticBooking = {
      schemaVersion: 1,
      listingId: listing.id,
      bookingId: booking.id,
      title: expectedTitle,
      startDate: booking.startDate,
      endDate: booking.endDate,
      workflowStatus: 'requested',
      createdAt: booking.createdAt ?? now.toISOString(),
      recoveredAt: now.toISOString(),
      paymentMode: 'memory',
      stripeLivemode: false,
      paymentEndpointCalled: false,
    };
    vault.status = 'synthetic-booking-active';
    saveVault(path, vault);
    return Object.freeze({
      status: 'synthetic-booking-requested',
      rolesLoggedIn: ['owner', 'renter'],
      listingCreated: true,
      bookingCreated: true,
      fixtureRecovered: true,
      workflowStatus: 'requested',
      paymentMode: 'memory',
      stripeLivemode: false,
      paymentEndpointCalled: false,
      containsSecrets: false,
      containsEmailAddresses: false,
      containsTokens: false,
    });
  }
  if (matchingListings.length !== 0 || matchingRequests.length !== 0) {
    fail('A partial synthetic booking fixture requires controlled cleanup before retry.');
  }

  const imageBytes = readFileSync(resolve(imagePath));
  if (imageBytes.length < 100) fail('The synthetic listing image is invalid.');
  const form = new FormData();
  form.append('purpose', 'listing_image');
  form.append('file', new Blob([imageBytes], { type: 'image/png' }), 'sit-role-fixture.png');
  const upload = await request(fetchImpl, '/uploads', {
    method: 'POST',
    token: ownerToken,
    body: form,
    expected: [201],
  });
  if (typeof upload?.url !== 'string' || !upload.url.startsWith('https://')) {
    fail('The synthetic listing upload did not return a safe URL.');
  }

  const suffix = random(4).toString('hex');
  const listingId = `sit-${vault.runId}-${suffix}-listing`;
  const bookingId = `sit-${vault.runId}-${suffix}-booking`;
  const title = expectedTitle;
  const startDate = dateOnly(now, 60);
  const endDate = dateOnly(now, 62);

  await request(fetchImpl, '/listings', {
    method: 'POST',
    token: ownerToken,
    expected: [201],
    body: {
      id: listingId,
      title,
      description: 'Isoliertes Staging-Inserat für die ShareItToo Rollen- und Buchungsprüfung ohne Echtgeld.',
      categoryId: 'electronics',
      subcategory: 'Kameras',
      tags: ['sit', 'role-fixture'],
      pricePerDay: 12,
      priceRaw: 12,
      priceUnit: 'day',
      currency: 'EUR',
      deposit: 30,
      photos: [upload.url],
      locationText: 'Staging Testadresse',
      city: 'Berlin',
      country: 'Deutschland',
      lat: 52.52,
      lng: 13.405,
      geohash: 'private',
      condition: 'good',
      minDays: 1,
      maxDays: 14,
      protectionModel: 'standard',
      status: 'active',
      isActive: true,
    },
  });
  await request(fetchImpl, `/listings/${encodeURIComponent(listingId)}/availability`, {
    method: 'PUT',
    token: ownerToken,
    body: {
      timezone: 'Europe/Berlin',
      minimumDays: 1,
      maximumDays: 14,
      noticeHours: 0,
      acceptanceWindowMinutes: 30,
      rules: Array.from({ length: 7 }, (_, weekday) => ({
        weekday,
        localStart: '00:00',
        localEnd: '23:59',
        isAvailable: true,
      })),
      blocks: [],
    },
  });
  const created = await request(fetchImpl, '/bookings', {
    method: 'POST',
    token: renterToken,
    headers: { 'Idempotency-Key': `${bookingId}-create` },
    body: { id: bookingId, itemId: listingId, startDate, endDate },
    expected: [201],
  });
  if (created?.booking?.workflowStatus !== 'requested') {
    fail('The synthetic booking was not created in the requested state.');
  }

  vault.syntheticBooking = {
    schemaVersion: 1,
    listingId,
    bookingId,
    title,
    startDate,
    endDate,
    workflowStatus: 'requested',
    createdAt: now.toISOString(),
    paymentMode: 'memory',
    stripeLivemode: false,
    paymentEndpointCalled: false,
  };
  vault.status = 'synthetic-booking-active';
  saveVault(path, vault);
  return Object.freeze({
    status: 'synthetic-booking-requested',
    rolesLoggedIn: ['owner', 'renter'],
    listingCreated: true,
    bookingCreated: true,
    fixtureRecovered: false,
    workflowStatus: 'requested',
    paymentMode: 'memory',
    stripeLivemode: false,
    paymentEndpointCalled: false,
    containsSecrets: false,
    containsEmailAddresses: false,
    containsTokens: false,
  });
}

export async function transitionSyntheticBookingFixture({
  vaultFile,
  status,
  fetchImpl = globalThis.fetch,
  now = new Date(),
} = {}) {
  const transition = allowedTransitions.get(status);
  if (!transition) fail('The synthetic booking transition is invalid.');
  const { path, vault, accounts } = readVault(vaultFile);
  const fixture = vault.syntheticBooking;
  if (!fixture || fixture.paymentEndpointCalled !== false || fixture.stripeLivemode !== false) {
    fail('The active synthetic booking fixture is missing or unsafe.');
  }
  if (fixture.workflowStatus !== transition.previous) {
    fail(`The synthetic booking is not ready for the ${status} transition.`);
  }
  const token = await login(fetchImpl, accounts.get(transition.role));
  const result = await request(fetchImpl, `/bookings/${encodeURIComponent(fixture.bookingId)}/transitions`, {
    method: 'POST',
    token,
    headers: { 'Idempotency-Key': `${fixture.bookingId}-${status}` },
    body: { status },
  });
  if (result?.booking?.workflowStatus !== transition.result) {
    fail(`The synthetic booking did not reach ${transition.result}.`);
  }
  fixture.workflowStatus = transition.result;
  fixture.updatedAt = now.toISOString();
  if (status === 'completed') vault.status = 'synthetic-booking-completed';
  saveVault(path, vault);
  return Object.freeze({
    status: `synthetic-booking-${status}`,
    actingRole: transition.role,
    workflowStatus: transition.result,
    paymentMode: fixture.paymentMode,
    stripeLivemode: false,
    paymentEndpointCalled: false,
    containsSecrets: false,
    containsEmailAddresses: false,
    containsTokens: false,
  });
}

function cliValue(args, flag) {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : null;
}

const invokedPath = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : null;
if (invokedPath === import.meta.url) {
  const [command] = process.argv.slice(2);
  const vaultFile = cliValue(process.argv.slice(2), '--vault-file');
  try {
    const result = command === 'create'
      ? await createSyntheticBookingFixture({ vaultFile })
      : await transitionSyntheticBookingFixture({
          vaultFile,
          status: cliValue(process.argv.slice(2), '--status'),
        });
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    process.exit(1);
  }
}
