import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../../', import.meta.url);
const read = (path) => readFileSync(new URL(path, root), 'utf8');
const escaped = (value) => value.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&');

test('RW9 is permanently invoked by the supported regression', () => {
  const regression = read('scripts/technical_regression_check.sh');
  for (const marker of [
    'rw9_local_account_profile_authorization_durability_test.dart',
    'rw9_local_account_profile_authorization_durability_wiring.test.mjs',
    'validate_rw9_local_account_profile_authorization_durability.mjs',
  ]) assert.match(regression, new RegExp(escaped(marker), 'u'));
});

test('profile patches expose only owner-mutable fields', () => {
  const service = read('lib/services/data_service.dart');
  const fieldBlock = service.match(
    /enum CurrentUserProfileField \{([\s\S]*?)\n\}/u,
  )?.[1];
  assert.ok(fieldBlock, 'CurrentUserProfileField enum must exist.');
  for (const protectedField of [
    'email',
    'emailVerified',
    'phoneVerified',
    'isVerified',
    'isBanned',
    'role',
    'payoutAccountId',
    'avgRating',
    'reviewCount',
    'createdAt',
    'isDeactivated',
    'deactivatedAt',
  ]) assert.doesNotMatch(fieldBlock, new RegExp(`\\b${protectedField}\\b`, 'u'));
  for (const marker of [
    'updateCurrentUserProfile({',
    '_requireCurrentOperationalUser(',
    '_assertCurrentOperationalUserId(',
    'Geschützte Kontofelder dürfen nicht geändert werden.',
  ]) assert.match(service, new RegExp(escaped(marker), 'u'));
});

test('paired local profile documents are strict bounded and rollback verified', () => {
  const service = read('lib/services/data_service.dart');
  for (const marker of [
    '_accountProfileMutationQueue',
    '_maxLocalUsers = 1000',
    '_maxLocalUserDocumentBytes = 16 * 1024 * 1024',
    '_decodeLocalUsersStrict(',
    '_decodeCurrentUserStrict(',
    '_persistAccountProfileDocumentsVerified(',
    'failNextAccountProfilePersistenceForTesting()',
    'clearSessionDuringNextAccountProfilePersistenceForTesting()',
  ]) assert.match(service, new RegExp(escaped(marker), 'u'));
  assert.doesNotMatch(
    service,
    /static Future<List<User>> getUsers\(\)[\s\S]*?prefs\.setString\(_usersKey/u,
  );
});

test('user-facing profile screens use field patches rather than snapshot writes', () => {
  const patchScreens = [
    'lib/screens/change_address_screen.dart',
    'lib/screens/contact_data_screen.dart',
    'lib/screens/edit_profile_screen.dart',
    'lib/screens/edit_social_media_screen.dart',
    'lib/screens/explore_screen.dart',
    'lib/screens/own_profile_screen.dart',
    'lib/screens/profile_info_screen.dart',
  ];
  for (const path of patchScreens) {
    const source = read(path);
    assert.match(source, /DataService\.updateCurrentUserProfile\(/u, path);
    assert.doesNotMatch(source, /DataService\.setCurrentUser\(/u, path);
  }
  const contact = read('lib/screens/contact_data_screen.dart');
  assert.doesNotMatch(contact, /copyWith\(emailVerified:\s*true/u);
  assert.doesNotMatch(contact, /lokalen Demo-Modus wird die Bestätigung simuliert/u);
  assert.match(contact, /nur über den bestätigten Anmeldeweg geändert/u);
  assert.match(
    read('lib/screens/register_screen.dart'),
    /DataService\.setCurrentUser\(/u,
  );
});

test('privacy export and deletion stay exact-current-account scoped', () => {
  const service = read('lib/services/data_service.dart');
  for (const marker of [
    'exportCurrentAccountProfileForPrivacy()',
    "'otherCachedProfilesExcluded': true",
    "'authenticationSessionExcluded': true",
    'anonymizeAndDeactivateUser({',
    '_requireCurrentOperationalUser(requestedUserId: userId)',
  ]) assert.match(service, new RegExp(escaped(marker), 'u'));
  const privacy = read('lib/screens/privacy_info_screen.dart');
  assert.match(privacy, /exportCurrentAccountProfileForPrivacy\(\)/u);

  const deletion = read('lib/services/account_deletion_service.dart');
  const deactivate = deletion.indexOf('deactivateAllListingsForUser(user.id)');
  const anonymize = deletion.indexOf('anonymizeAndDeactivateUser(userId: user.id)');
  const clearSession = deletion.lastIndexOf('AuthService.clearSession()');
  const clearCurrent = deletion.lastIndexOf('clearCurrentUserAndMarkDeleted()');
  assert.ok(deactivate >= 0 && deactivate < anonymize);
  assert.ok(anonymize < clearSession && clearSession < clearCurrent);
});

test('lifecycle privacy and retention manifests bind local account profiles', () => {
  const lifecycle = JSON.parse(read('store/g2-data-lifecycle.json'));
  assert.equal(
    lifecycle.localAccountProfile.mutationIdentityBinding,
    'matching-auth-session-and-exact-current-account-field-patch',
  );
  const privacy = JSON.parse(read('store/privacy-disclosures.json'));
  assert.equal(
    privacy.localAccountProfile.privacyExport,
    'current-account-profile-only-other-cache-and-auth-session-excluded',
  );
  const retention = JSON.parse(read('store/retention-deletion-readiness.json'));
  assert.equal(
    retention.implementedControls.localAccountProfile.retentionPeriodInvented,
    false,
  );
});

test('RW9 proof is deterministic and covers the local threat matrix', () => {
  const source = read(
    'test/rw9_local_account_profile_authorization_durability_test.dart',
  );
  for (const marker of [
    'guest, foreign and stale sessions cannot mutate the cached profile',
    'field patches preserve protected truth and support explicit clears',
    'parallel disjoint patches serialize without lost updates',
    'failed paired write restores exact bytes and queue recovers',
    'session replacement during paired write rolls both documents back',
    'corrupt current profile fails closed and preserves exact bytes',
    'duplicate account identity fails closed without sanitizing users',
    'divergent paired profile fails closed for mutation export and deletion',
    'bounded account capacity rejects overflow without pruning',
    'completed paired write survives process-style recreation',
    'privacy export is exact-current-account and excludes cache/session',
    'deactivation is exact-current-account and paired-profile scoped',
  ]) assert.match(source, new RegExp(escaped(marker), 'u'));
  assert.doesNotMatch(source, /Future(?:<void>)?\.delayed|Timer\s*\(/u);
});
