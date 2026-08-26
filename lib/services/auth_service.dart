import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_config.dart';
import 'backend_http.dart';
import 'backend_realtime_service.dart';
import 'blue_ocean_draft_recovery_service.dart';
import 'firebase_runtime.dart';
import 'shared_persistence_sync.dart';

class _QueuedAuthSessionMutation {
  final Future<Object?> Function() operation;
  final void Function(Object? value) complete;
  final void Function(Object error, StackTrace stackTrace) completeError;

  const _QueuedAuthSessionMutation({
    required this.operation,
    required this.complete,
    required this.completeError,
  });
}

/// Serializes every app-owned write or removal of the persisted session.
///
/// This makes the owner comparison and mutation one atomic logical operation
/// within the Dart process. A successor sign-in therefore waits until an A
/// cleanup finishes, while an already-persisted B session makes the A clear a
/// no-op.
class _AuthSessionMutationQueue {
  final Queue<_QueuedAuthSessionMutation> _pending =
      Queue<_QueuedAuthSessionMutation>();
  bool _running = false;

  Future<T> run<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _pending.add(_QueuedAuthSessionMutation(
      operation: () async => operation(),
      complete: (value) => result.complete(value as T),
      completeError: result.completeError,
    ));
    _startIfIdle();
    return result.future;
  }

  void _startIfIdle() {
    if (_running) return;
    _running = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    while (_pending.isNotEmpty) {
      final queued = _pending.removeFirst();
      Object? value;
      Object? failure;
      StackTrace? failureStack;
      try {
        value = await queued.operation();
      } catch (error, stackTrace) {
        failure = error;
        failureStack = stackTrace;
      }
      final becameIdle = _pending.isEmpty;
      if (becameIdle) _running = false;
      if (failure != null) {
        queued.completeError(failure, failureStack!);
      } else {
        queued.complete(value);
      }
      if (becameIdle) {
        if (_pending.isNotEmpty) _startIfIdle();
        return;
      }
    }
    _running = false;
  }
}

/// Authentication facade.
///
/// Release builds use the central ShareItToo API. Debug/test builds keep the
/// existing local accounts unless SIT_BACKEND_ENABLED=true is supplied.
class AuthService {
  static const _accountsKey = 'auth_accounts_v1';
  static const _sessionKey = 'auth_session_v1';
  static const _seedKey = 'auth_seeded_v1';
  static const Set<String> _legacySyntheticSocialEmails = {
    'google.demo@shareittoo.app',
    'apple.demo@shareittoo.app',
  };

  static const demoEmail = 'demo@shareittoo.app';
  static const demoPassword = 'shareittoo';
  static Future<String?>? _refreshInFlight;
  static final _AuthSessionMutationQueue _sessionMutationQueue =
      _AuthSessionMutationQueue();
  static int _sessionGeneration = 0;
  static bool _sessionClearing = false;
  static Future<void>? _googleInitialization;
  static const bool _googleSocialAuthEnabled = bool.fromEnvironment(
    'SIT_SOCIAL_GOOGLE_ENABLED',
    defaultValue: false,
  );
  static const bool _appleSocialAuthEnabled = bool.fromEnvironment(
    'SIT_SOCIAL_APPLE_ENABLED',
    defaultValue: false,
  );
  static const bool _facebookSocialAuthEnabled = bool.fromEnvironment(
    'SIT_SOCIAL_FACEBOOK_ENABLED',
    defaultValue: false,
  );

  static void _notifyLocalPrincipalChanged() {
    SharedPersistenceSync.notify(SharedPersistenceSync.wishlistStateKey);
    SharedPersistenceSync.notify(SharedPersistenceSync.savedItemsKey);
    SharedPersistenceSync.notify(SharedPersistenceSync.rentalCartKey);
    SharedPersistenceSync.notify(
      SharedPersistenceSync.localSafetyPrivacyStateKey,
    );
    SharedPersistenceSync.notify(
      SharedPersistenceSync.accountSecurityStateKey,
    );
  }

  @visibleForTesting
  static bool socialProviderEnabled(AuthSocialProvider provider) =>
      switch (provider) {
        AuthSocialProvider.google => _googleSocialAuthEnabled,
        AuthSocialProvider.apple => _appleSocialAuthEnabled,
        AuthSocialProvider.facebook => _facebookSocialAuthEnabled,
      };

  static Future<void> ensureSeeded() async {
    if (BackendConfig.enabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_seedKey) == true) return;
      final accounts = await _readAccounts(prefs);
      final exists = accounts.any(
        (account) => (account['email'] as String?)?.toLowerCase() == demoEmail,
      );
      if (!exists) {
        accounts.add({
          'email': demoEmail,
          'password': demoPassword,
          'createdAt': DateTime.now().toIso8601String(),
        });
        await prefs.setString(_accountsKey, jsonEncode(accounts));
      }
      await prefs.setBool(_seedKey, true);
    } catch (error) {
      debugPrint('[AuthService] ensureSeeded failed: $error');
    }
  }

  static Future<AuthSession?> readSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final email = map['email'];
      if (email is! String || email.isEmpty) return null;
      final normalizedEmail = email.trim().toLowerCase();
      if (_legacySyntheticSocialEmails.contains(normalizedEmail)) {
        await _removeStoredSessionIfRawMatches(raw);
        return null;
      }
      final session = AuthSession(
        userId: map['userId']?.toString(),
        email: normalizedEmail,
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
        accessToken: map['accessToken']?.toString(),
        refreshToken: map['refreshToken']?.toString(),
        sessionId: map['sessionId']?.toString(),
        accessTokenExpiresAt: DateTime.tryParse(
          map['accessTokenExpiresAt']?.toString() ?? '',
        ),
      );
      if (BackendConfig.enabled &&
          ((session.userId ?? '').isEmpty ||
              (session.accessToken ?? '').isEmpty ||
              (session.refreshToken ?? '').isEmpty ||
              (session.sessionId ?? '').isEmpty)) {
        await _removeStoredSessionIfRawMatches(raw);
        return null;
      }
      return session;
    } catch (error) {
      debugPrint('[AuthService] readSession failed: $error');
      return null;
    }
  }

  /// Returns true only when the persisted auth-session key is definitely
  /// absent. A malformed value or a storage read failure is not equivalent to
  /// a confirmed sign-out and therefore fails closed as false.
  static Future<bool> isStoredSessionDefinitelyAbsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !prefs.containsKey(_sessionKey);
    } catch (error) {
      debugPrint(
        '[AuthService] stored session absence check failed: '
        '${error.runtimeType}',
      );
      return false;
    }
  }

  /// Monotonic in-process epoch for every successful app-owned session write
  /// or removal. UI actions capture this synchronously with their principal.
  static int get sessionEpoch => _sessionGeneration;

  static AuthSessionOwner captureSessionOwner(AuthSession session) =>
      AuthSessionOwner(
        userId: session.userId,
        sessionId: session.sessionId,
        email: session.email,
        createdAt: session.createdAt,
        epoch: _sessionGeneration,
      );

  static Future<bool> isSessionOwnerDefinitelyCurrent(
    AuthSessionOwner owner,
  ) async {
    final observedEpoch = _sessionGeneration;
    if (owner.epoch != observedEpoch) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final matches = _storedSessionMatchesOwner(
        prefs.getString(_sessionKey),
        owner,
      );
      return matches &&
          owner.epoch == _sessionGeneration &&
          observedEpoch == _sessionGeneration;
    } catch (error) {
      debugPrint(
        '[AuthService] session owner check failed: ${error.runtimeType}',
      );
      return false;
    }
  }

  static Future<bool> isSessionClearReceiptCurrent(
    AuthSessionClearReceipt receipt,
  ) async {
    if (receipt.completionEpoch != _sessionGeneration) return false;
    final absent = await isStoredSessionDefinitelyAbsent();
    return absent && receipt.completionEpoch == _sessionGeneration;
  }

  static Future<void> clearSession() async {
    final session = await readSession();
    if (session == null) return;
    await clearSessionOwnerIfMatches(captureSessionOwner(session));
  }

  /// Clears only the exact captured session owner. The comparison, local
  /// account cleanup and session mutation remain serialized against successor
  /// sign-ins and token refresh persistence.
  static Future<AuthSessionClearReceipt?> clearSessionOwnerIfMatches(
    AuthSessionOwner owner, {
    bool runLogoutCleanup = true,
  }) {
    return _sessionMutationQueue.run(() async {
      if (owner.epoch != _sessionGeneration) return null;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (!_storedSessionMatchesOwner(raw, owner)) return null;
      final capturedSession = _decodeStoredSession(raw!);
      if (capturedSession == null) return null;

      _sessionClearing = true;
      _refreshInFlight = null;
      try {
        if (runLogoutCleanup) {
          try {
            await FirebaseRuntime.clearPushRegistrationForLogout();
          } catch (_) {
            // Logout remains authoritative if the local FCM SDK is offline.
          }
        }

        final removed = await prefs.remove(_sessionKey);
        if (!removed || prefs.containsKey(_sessionKey)) return null;
        _sessionGeneration += 1;
        final receipt = AuthSessionClearReceipt(
          owner: owner,
          completionEpoch: _sessionGeneration,
        );
        _notifyLocalPrincipalChanged();

        if (runLogoutCleanup) {
          try {
            await BlueOceanDraftRecoveryService().clear();
          } catch (_) {
            // Account-bound draft cleanup is best effort after exact removal.
          }
          try {
            // A successor realtime connection cannot start until this exact A
            // disconnect completes because session persistence shares the
            // mutation queue. Do not use a non-cancelling timeout here.
            await BackendRealtimeService.disconnect();
          } catch (_) {
            // Local session removal remains authoritative while disconnected.
          }
          await runBestEffortLogoutCleanup(
            remoteLogout: () async {
              if (BackendConfig.enabled &&
                  (capturedSession.refreshToken ?? '').isNotEmpty) {
                await BackendHttp.requestJson(
                  method: 'POST',
                  path: '/auth/logout',
                  body: {'refreshToken': capturedSession.refreshToken},
                );
              }
            },
            disconnectRealtime: () async {},
          );
        }
        return receipt;
      } catch (error) {
        debugPrint(
          '[AuthService] exact session clear failed: ${error.runtimeType}',
        );
        return null;
      } finally {
        _sessionClearing = false;
        _refreshInFlight = null;
      }
    });
  }

  /// Removes a backend session only when the exact expected principal is still
  /// stored. The comparison and removal invocation are deliberately adjacent,
  /// so a successor sign-in is never selected as the removal target.
  ///
  /// This narrow path is used after a server-authoritative password change or
  /// logout-all response. It intentionally does not run the broader best-effort
  /// logout cleanup, because that cleanup could act on a successor principal.
  static Future<bool> clearSessionIfMatches({
    required String userId,
    required String sessionId,
    required String email,
  }) async {
    final session = await readSession();
    if (session == null ||
        session.userId?.trim() != userId.trim() ||
        session.sessionId?.trim() != sessionId.trim() ||
        session.email.trim().toLowerCase() != email.trim().toLowerCase()) {
      return false;
    }
    final receipt = await clearSessionOwnerIfMatches(
      captureSessionOwner(session),
      runLogoutCleanup: false,
    );
    return receipt != null && await isSessionClearReceiptCurrent(receipt);
  }

  static AuthSession? _decodeStoredSession(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final email = map['email'];
      if (email is! String || email.trim().isEmpty) return null;
      return AuthSession(
        userId: map['userId']?.toString(),
        email: email.trim().toLowerCase(),
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
        accessToken: map['accessToken']?.toString(),
        refreshToken: map['refreshToken']?.toString(),
        sessionId: map['sessionId']?.toString(),
        accessTokenExpiresAt: DateTime.tryParse(
          map['accessTokenExpiresAt']?.toString() ?? '',
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static bool _storedSessionMatchesOwner(
    String? raw,
    AuthSessionOwner owner,
  ) {
    if (raw == null || raw.isEmpty) return false;
    final session = _decodeStoredSession(raw);
    if (session == null ||
        session.email.trim().toLowerCase() !=
            owner.email.trim().toLowerCase()) {
      return false;
    }
    final ownerUserId = owner.userId?.trim() ?? '';
    final ownerSessionId = owner.sessionId?.trim() ?? '';
    if (ownerUserId.isNotEmpty || ownerSessionId.isNotEmpty) {
      return _storedRemoteSessionMatches(
        raw,
        userId: ownerUserId,
        sessionId: ownerSessionId,
        email: owner.email,
      );
    }
    return (session.userId ?? '').trim().isEmpty &&
        (session.sessionId ?? '').trim().isEmpty &&
        session.createdAt == owner.createdAt;
  }

  static bool _storedRemoteSessionMatches(
    String? raw, {
    required String userId,
    required String sessionId,
    required String email,
  }) {
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final map = Map<String, dynamic>.from(decoded);
      return map['userId'] is String &&
          (map['userId'] as String).trim() == userId.trim() &&
          map['sessionId'] is String &&
          (map['sessionId'] as String).trim() == sessionId.trim() &&
          map['email'] is String &&
          (map['email'] as String).trim().toLowerCase() ==
              email.trim().toLowerCase();
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static Future<void> runBestEffortLogoutCleanup({
    required Future<void> Function() remoteLogout,
    required Future<void> Function() disconnectRealtime,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      await Future.wait<void>([
        remoteLogout(),
        disconnectRealtime(),
      ]).timeout(timeout);
    } catch (_) {
      // Local session removal is authoritative even while offline or when a
      // stale realtime socket cannot complete its closing handshake.
    }
  }

  static Future<AuthResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (BackendConfig.enabled) {
      try {
        final response = await BackendHttp.requestJson(
          method: 'POST',
          path: '/auth/login',
          body: {'email': email.trim(), 'password': password},
        );
        final session = await _saveRemoteSession(response);
        return AuthResult.success(
          session: session,
          verificationEmailSent: response['verificationEmailSent'] == true,
        );
      } on BackendException catch (error) {
        if (error.statusCode == 401) {
          return const AuthResult.failure(AuthFailure.invalidCredentials);
        }
        if (error.code == 'email_verification_required') {
          return const AuthResult.failure(
              AuthFailure.emailVerificationRequired);
        }
        debugPrint('[AuthService] remote sign-in failed: $error');
        return const AuthResult.failure(AuthFailure.network);
      } catch (error) {
        debugPrint('[AuthService] remote sign-in failed: $error');
        return const AuthResult.failure(AuthFailure.network);
      }
    }

    await ensureSeeded();
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await _readAccounts(prefs);
      final normalizedEmail = email.trim().toLowerCase();
      final match = accounts.firstWhere(
        (account) =>
            (account['email'] as String?)?.toLowerCase() == normalizedEmail,
        orElse: () => const <String, Object?>{},
      );
      if (match.isEmpty) {
        return const AuthResult.failure(AuthFailure.invalidCredentials);
      }
      final storedPassword = (match['password'] as String?) ?? '';
      if (storedPassword != password) {
        return const AuthResult.failure(AuthFailure.invalidCredentials);
      }

      final sessionData = {
        'email': normalizedEmail,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await _persistSessionEncoded(jsonEncode(sessionData));
      return AuthResult.success(
        session: AuthSession(
          email: normalizedEmail,
          createdAt: DateTime.parse(sessionData['createdAt']!),
        ),
      );
    } catch (error) {
      debugPrint('[AuthService] signInWithEmailPassword failed: $error');
      return const AuthResult.failure(AuthFailure.network);
    }
  }

  static Future<AuthResult> registerLocalAccount({
    required String email,
    required String password,
    String? displayName,
    required bool termsAccepted,
    required bool privacyAccepted,
    required bool minimumAgeConfirmed,
    required bool privateUseConfirmed,
  }) async {
    if (!termsAccepted ||
        !privacyAccepted ||
        !minimumAgeConfirmed ||
        !privateUseConfirmed) {
      return const AuthResult.failure(AuthFailure.consentRequired);
    }
    if (BackendConfig.enabled) {
      try {
        final response = await BackendHttp.requestJson(
          method: 'POST',
          path: '/auth/register',
          body: {
            'email': email.trim(),
            'password': password,
            'displayName': displayName?.trim(),
            'termsAccepted': termsAccepted,
            'privacyAccepted': privacyAccepted,
            'minimumAgeConfirmed': minimumAgeConfirmed,
            'privateUseConfirmed': privateUseConfirmed,
          },
        );
        if (response['accepted'] != true) {
          return const AuthResult.failure(AuthFailure.network);
        }
        return const AuthResult.success(verificationEmailSent: true);
      } on BackendException catch (error) {
        if (error.code == 'password_too_short' ||
            error.code == 'password_too_long' ||
            error.code == 'password_too_weak') {
          return const AuthResult.failure(AuthFailure.weakPassword);
        }
        if (error.code == 'registration_consents_required') {
          return const AuthResult.failure(AuthFailure.consentRequired);
        }
        debugPrint('[AuthService] remote registration failed: $error');
        return const AuthResult.failure(AuthFailure.network);
      } catch (error) {
        debugPrint('[AuthService] remote registration failed: $error');
        return const AuthResult.failure(AuthFailure.network);
      }
    }

    await ensureSeeded();
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await _readAccounts(prefs);
      final normalizedEmail = email.trim().toLowerCase();
      final exists = accounts.any(
        (account) =>
            (account['email'] as String?)?.toLowerCase() == normalizedEmail,
      );
      if (exists) return const AuthResult.failure(AuthFailure.emailInUse);
      accounts.add({
        'email': normalizedEmail,
        'password': password,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_accountsKey, jsonEncode(accounts));
      final sessionData = {
        'email': normalizedEmail,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await _persistSessionEncoded(jsonEncode(sessionData));
      return AuthResult.success(
        session: AuthSession(
          email: normalizedEmail,
          createdAt: DateTime.parse(sessionData['createdAt']!),
        ),
      );
    } catch (error) {
      debugPrint('[AuthService] registerLocalAccount failed: $error');
      return const AuthResult.failure(AuthFailure.network);
    }
  }

  static Future<String?> accessToken() async {
    if (!BackendConfig.enabled) return null;
    final session = await readSession();
    if (session == null) return null;
    final expiresAt = session.accessTokenExpiresAt;
    if (expiresAt != null &&
        expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
      return session.accessToken;
    }
    return refreshAccessToken();
  }

  static Future<bool> requestPasswordReset(String email) async {
    if (!BackendConfig.enabled) return true;
    try {
      await BackendHttp.requestJson(
        method: 'POST',
        path: '/auth/password-reset/request',
        body: {'email': email.trim()},
      );
      return true;
    } catch (error) {
      debugPrint('[AuthService] password reset request failed: $error');
      return false;
    }
  }

  static Future<bool> requestEmailVerification(String email) async {
    if (!BackendConfig.enabled) return true;
    try {
      await BackendHttp.requestJson(
        method: 'POST',
        path: '/auth/email-verification/request',
        body: {'email': email.trim()},
      );
      return true;
    } catch (error) {
      debugPrint('[AuthService] verification request failed: $error');
      return false;
    }
  }

  static Future<PhoneVerificationChallenge> requestPhoneVerification(
    String phoneNumber,
  ) async {
    if (!BackendConfig.enabled || kIsWeb) {
      throw const PhoneVerificationException(
        PhoneVerificationFailure.unavailable,
      );
    }
    final normalized = normalizePhoneNumber(phoneNumber);
    if (normalized == null) {
      throw const PhoneVerificationException(
        PhoneVerificationFailure.invalidPhone,
      );
    }
    final access = await accessToken();
    if (access == null || access.isEmpty) {
      throw const PhoneVerificationException(
        PhoneVerificationFailure.sessionExpired,
      );
    }
    try {
      final status = await BackendHttp.requestJson(
        method: 'GET',
        path: '/auth/phone-verification/status',
        accessToken: access,
      );
      if (status['available'] != true ||
          status['provider'] != 'firebase-phone') {
        throw const PhoneVerificationException(
          PhoneVerificationFailure.unavailable,
        );
      }
    } on PhoneVerificationException {
      rethrow;
    } on BackendException catch (error) {
      if (error.statusCode == 401) {
        throw const PhoneVerificationException(
          PhoneVerificationFailure.sessionExpired,
        );
      }
      throw const PhoneVerificationException(
        PhoneVerificationFailure.unavailable,
      );
    } catch (_) {
      throw const PhoneVerificationException(
        PhoneVerificationFailure.network,
      );
    }
    try {
      await FirebaseRuntime.ensureFirebaseApp();
    } catch (_) {
      throw const PhoneVerificationException(
        PhoneVerificationFailure.unavailable,
      );
    }
    if (Firebase.apps.isEmpty) {
      throw const PhoneVerificationException(
        PhoneVerificationFailure.unavailable,
      );
    }
    final completer = Completer<PhoneVerificationChallenge>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalized,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          if (completer.isCompleted) return;
          try {
            await _confirmPhoneCredential(
              phoneNumber: normalized,
              credential: credential,
            );
            if (!completer.isCompleted) {
              completer.complete(PhoneVerificationChallenge(
                phoneNumber: normalized,
                automaticallyVerified: true,
              ));
            }
          } catch (error, stack) {
            if (!completer.isCompleted) completer.completeError(error, stack);
          }
        },
        verificationFailed: (error) {
          if (completer.isCompleted) return;
          completer.completeError(_phoneVerificationException(error));
        },
        codeSent: (verificationId, _) {
          if (completer.isCompleted) return;
          completer.complete(PhoneVerificationChallenge(
            phoneNumber: normalized,
            verificationId: verificationId,
          ));
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (completer.isCompleted) return;
          completer.complete(PhoneVerificationChallenge(
            phoneNumber: normalized,
            verificationId: verificationId,
          ));
        },
      );
      return await completer.future.timeout(
        const Duration(seconds: 75),
        onTimeout: () => throw const PhoneVerificationException(
          PhoneVerificationFailure.timeout,
        ),
      );
    } on PhoneVerificationException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _phoneVerificationException(error);
    } catch (error) {
      debugPrint('[AuthService] phone verification request failed: $error');
      throw const PhoneVerificationException(
        PhoneVerificationFailure.network,
      );
    }
  }

  static Future<void> confirmPhoneVerification({
    required PhoneVerificationChallenge challenge,
    required String smsCode,
  }) async {
    final verificationId = challenge.verificationId?.trim() ?? '';
    final code = smsCode.trim();
    if (challenge.automaticallyVerified) return;
    if (verificationId.isEmpty || !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const PhoneVerificationException(
        PhoneVerificationFailure.invalidCode,
      );
    }
    try {
      await _confirmPhoneCredential(
        phoneNumber: challenge.phoneNumber,
        credential: PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        ),
      );
    } on PhoneVerificationException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _phoneVerificationException(error);
    } catch (error) {
      debugPrint('[AuthService] phone verification confirm failed: $error');
      throw const PhoneVerificationException(
        PhoneVerificationFailure.network,
      );
    }
  }

  static Future<void> _confirmPhoneCredential({
    required String phoneNumber,
    required PhoneAuthCredential credential,
  }) async {
    try {
      final signedIn = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final firebaseIdToken = await signedIn.user?.getIdToken(true);
      if (firebaseIdToken == null || firebaseIdToken.length < 100) {
        throw const PhoneVerificationException(
          PhoneVerificationFailure.invalidToken,
        );
      }
      final access = await accessToken();
      if (access == null || access.isEmpty) {
        throw const PhoneVerificationException(
          PhoneVerificationFailure.sessionExpired,
        );
      }
      await BackendHttp.requestJson(
        method: 'POST',
        path: '/auth/phone-verification/confirm',
        accessToken: access,
        body: {
          'phoneNumber': phoneNumber,
          'firebaseIdToken': firebaseIdToken,
        },
      );
    } on BackendException catch (error) {
      final failure = switch (error.code) {
        'phone_verification_mismatch' => PhoneVerificationFailure.phoneMismatch,
        'phone_already_verified' =>
          PhoneVerificationFailure.phoneAlreadyVerified,
        'invalid_phone' => PhoneVerificationFailure.invalidPhone,
        'invalid_phone_verification_token' ||
        'invalid_phone_verification_provider' =>
          PhoneVerificationFailure.invalidToken,
        'phone_verification_unavailable' =>
          PhoneVerificationFailure.unavailable,
        'authentication_required' ||
        'invalid_or_expired_session' =>
          PhoneVerificationFailure.sessionExpired,
        _ => PhoneVerificationFailure.network,
      };
      throw PhoneVerificationException(failure);
    } finally {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
  }

  static String? normalizePhoneNumber(String value) {
    final compact = value
        .trim()
        .replaceAll(RegExp(r'[\s().-]'), '')
        .replaceFirst(RegExp(r'^00'), '+');
    return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(compact) ? compact : null;
  }

  static PhoneVerificationException _phoneVerificationException(
    FirebaseAuthException error,
  ) {
    final failure = switch (error.code) {
      'invalid-phone-number' => PhoneVerificationFailure.invalidPhone,
      'invalid-verification-code' ||
      'session-expired' ||
      'missing-verification-code' =>
        PhoneVerificationFailure.invalidCode,
      'too-many-requests' ||
      'quota-exceeded' =>
        PhoneVerificationFailure.rateLimited,
      'operation-not-allowed' ||
      'app-not-authorized' ||
      'missing-client-identifier' ||
      'captcha-check-failed' =>
        PhoneVerificationFailure.unavailable,
      'network-request-failed' => PhoneVerificationFailure.network,
      _ => PhoneVerificationFailure.network,
    };
    return PhoneVerificationException(failure);
  }

  static Future<AuthResult> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    if (!BackendConfig.enabled) return const AuthResult.success();
    final token = await accessToken();
    if (token == null || token.isEmpty) {
      return const AuthResult.failure(AuthFailure.network);
    }
    try {
      await BackendHttp.requestJson(
        method: 'POST',
        path: '/auth/email-change/request',
        accessToken: token,
        body: {
          'newEmail': newEmail.trim(),
          'currentPassword': currentPassword,
        },
      );
      return const AuthResult.success(verificationEmailSent: true);
    } on BackendException catch (error) {
      if (error.code == 'invalid_credentials') {
        return const AuthResult.failure(AuthFailure.invalidCredentials);
      }
      if (error.code == 'email_in_use') {
        return const AuthResult.failure(AuthFailure.emailInUse);
      }
      if (error.code == 'invalid_email' || error.code == 'email_unchanged') {
        return const AuthResult.failure(AuthFailure.invalidEmail);
      }
      debugPrint('[AuthService] email change request failed: $error');
      return const AuthResult.failure(AuthFailure.network);
    } catch (error) {
      debugPrint('[AuthService] email change request failed: $error');
      return const AuthResult.failure(AuthFailure.network);
    }
  }

  static Future<String?> refreshAccessToken() async {
    if (!BackendConfig.enabled) return null;
    if (_sessionClearing) return null;
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final refresh = _performAccessTokenRefresh(_sessionGeneration);
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  static Future<String?> _performAccessTokenRefresh(
      int expectedGeneration) async {
    if (_sessionClearing || expectedGeneration != _sessionGeneration) {
      return null;
    }
    final session = await readSession();
    final refreshToken = session?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return null;
    final owner = captureSessionOwner(session!);
    try {
      final response = await BackendHttp.requestJson(
        method: 'POST',
        path: '/auth/refresh',
        body: {'refreshToken': refreshToken},
      );
      final refreshed = await _saveRemoteSession(
        response,
        expectedGeneration: expectedGeneration,
      );
      return refreshed.accessToken;
    } on _DiscardedRefreshResult {
      return null;
    } catch (error) {
      debugPrint('[AuthService] refresh failed: $error');
      if (shouldClearStoredSessionAfterRefreshFailure(error)) {
        await clearSessionOwnerIfMatches(owner);
      } else if (await isSessionOwnerDefinitelyCurrent(owner)) {
        await BackendRealtimeService.disconnect();
      }
      return null;
    }
  }

  @visibleForTesting
  static bool shouldClearStoredSessionAfterRefreshFailure(Object error) {
    return error is BackendException && error.statusCode == 401;
  }

  static Future<AuthResult> signInWithSocialProvider(
    AuthSocialProvider provider, {
    bool termsAccepted = false,
    bool privacyAccepted = false,
    bool minimumAgeConfirmed = false,
    bool privateUseConfirmed = false,
  }) async {
    if (!BackendConfig.enabled) {
      return const AuthResult.failure(AuthFailure.providerUnavailable);
    }
    try {
      final idToken = await _firebaseSocialIdToken(provider);
      final response = await BackendHttp.requestJson(
        method: 'POST',
        path: '/auth/social',
        body: {
          'idToken': idToken,
          'termsAccepted': termsAccepted,
          'privacyAccepted': privacyAccepted,
          'minimumAgeConfirmed': minimumAgeConfirmed,
          'privateUseConfirmed': privateUseConfirmed,
        },
      );
      if (response['accepted'] == true &&
          response['verificationEmailSent'] == true) {
        return AuthResult.success(
          verificationEmailSent: true,
          pendingEmail: response['email']?.toString().trim().toLowerCase(),
        );
      }
      return AuthResult.success(session: await _saveRemoteSession(response));
    } on _SocialSignInCancelled {
      return const AuthResult.failure(AuthFailure.socialCancelled);
    } on _SocialProviderUnavailable catch (error) {
      debugPrint('[AuthService] ${provider.name} unavailable: ${error.cause}');
      return const AuthResult.failure(AuthFailure.providerUnavailable);
    } on BackendException catch (error) {
      final failure = switch (error.code) {
        'social_registration_consents_required' => AuthFailure.consentRequired,
        'social_email_required' => AuthFailure.socialEmailRequired,
        'social_email_verification_required' =>
          AuthFailure.socialEmailVerificationRequired,
        'social_provider_already_linked' =>
          AuthFailure.socialProviderAlreadyLinked,
        'social_account_link_requires_reauthentication' =>
          AuthFailure.socialAccountLinkRequiresReauthentication,
        'unsupported_social_provider' ||
        'social_auth_unavailable' =>
          AuthFailure.providerUnavailable,
        'account_not_active' => AuthFailure.accountNotActive,
        _ => AuthFailure.network,
      };
      debugPrint('[AuthService] social exchange failed: ${error.code}');
      return AuthResult.failure(failure);
    } catch (error) {
      debugPrint('[AuthService] social sign-in failed: $error');
      return const AuthResult.failure(AuthFailure.network);
    } finally {
      try {
        if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
      } catch (_) {}
      try {
        switch (provider) {
          case AuthSocialProvider.google:
            await GoogleSignIn.instance.signOut();
          case AuthSocialProvider.facebook:
            await FacebookAuth.instance.logOut();
          case AuthSocialProvider.apple:
            break;
        }
      } catch (_) {
        // The ShareItToo session is already authoritative. Provider cleanup
        // is best effort so an SDK logout problem cannot undo a safe login.
      }
    }
  }

  static Future<String> _firebaseSocialIdToken(
    AuthSocialProvider provider,
  ) async {
    if (!socialProviderEnabled(provider)) {
      throw const _SocialProviderUnavailable(
        'provider is disabled in this release candidate',
      );
    }
    await FirebaseRuntime.ensureFirebaseApp();
    if (Firebase.apps.isEmpty) throw const _SocialProviderUnavailable();
    try {
      UserCredential credential;
      switch (provider) {
        case AuthSocialProvider.google:
          _googleInitialization ??= GoogleSignIn.instance.initialize();
          await _googleInitialization;
          final account = await GoogleSignIn.instance.authenticate();
          final providerCredential = GoogleAuthProvider.credential(
            idToken: account.authentication.idToken,
          );
          credential = await FirebaseAuth.instance.signInWithCredential(
            providerCredential,
          );
        case AuthSocialProvider.apple:
          final appleProvider = AppleAuthProvider()
            ..addScope('email')
            ..addScope('name');
          credential = await FirebaseAuth.instance.signInWithProvider(
            appleProvider,
          );
        case AuthSocialProvider.facebook:
          final login = await FacebookAuth.instance.login(
            permissions: const ['email', 'public_profile'],
          );
          if (login.status == LoginStatus.cancelled) {
            throw const _SocialSignInCancelled();
          }
          final facebookToken = login.accessToken;
          if (login.status != LoginStatus.success || facebookToken == null) {
            throw _SocialProviderUnavailable(login.message);
          }
          final providerCredential = switch (facebookToken) {
            LimitedToken() => OAuthProvider('facebook.com').credential(
                idToken: facebookToken.tokenString,
                rawNonce: facebookToken.nonce,
                signInMethod: 'facebook.com',
              ),
            _ => FacebookAuthProvider.credential(facebookToken.tokenString),
          };
          credential = await FirebaseAuth.instance.signInWithCredential(
            providerCredential,
          );
      }
      final token = await credential.user?.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw const _SocialProviderUnavailable();
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw const _SocialSignInCancelled();
      }
      throw _SocialProviderUnavailable(error);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'web-context-cancelled' ||
          error.code == 'canceled' ||
          error.code == 'popup-closed-by-user') {
        throw const _SocialSignInCancelled();
      }
      throw _SocialProviderUnavailable(error);
    } on UnsupportedError catch (error) {
      throw _SocialProviderUnavailable(error);
    }
  }

  static Future<AuthSession> _saveRemoteSession(
    Map<String, dynamic> response, {
    int? expectedGeneration,
  }) async {
    final user = Map<String, dynamic>.from(response['user'] as Map);
    final accessToken = response['accessToken']?.toString() ?? '';
    final refreshToken = response['refreshToken']?.toString() ?? '';
    final sessionId = response['sessionId']?.toString() ?? '';
    final expiresIn = (response['expiresIn'] as num?)?.toInt() ?? 900;
    if (accessToken.isEmpty || refreshToken.isEmpty || sessionId.isEmpty) {
      throw const BackendException(500, 'invalid_auth_response');
    }
    final now = DateTime.now();
    final session = AuthSession(
      userId: user['id']?.toString(),
      email: user['email']?.toString().trim().toLowerCase() ?? '',
      createdAt: DateTime.tryParse(user['createdAt']?.toString() ?? '') ?? now,
      accessToken: accessToken,
      refreshToken: refreshToken,
      sessionId: sessionId,
      accessTokenExpiresAt: now.add(Duration(seconds: expiresIn)),
    );
    final encoded = jsonEncode({
      'userId': session.userId,
      'email': session.email,
      'createdAt': session.createdAt?.toIso8601String(),
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'sessionId': session.sessionId,
      'accessTokenExpiresAt': session.accessTokenExpiresAt?.toIso8601String(),
    });
    final persisted = await _persistSessionEncoded(
      encoded,
      expectedGeneration: expectedGeneration,
      connectAccessToken: accessToken,
    );
    if (!persisted) throw const _DiscardedRefreshResult();
    return session;
  }

  static Future<bool> _persistSessionEncoded(
    String encoded, {
    int? expectedGeneration,
    String? connectAccessToken,
  }) {
    return _sessionMutationQueue.run(() async {
      if (_sessionClearing ||
          (expectedGeneration != null &&
              expectedGeneration != _sessionGeneration)) {
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      final persisted = await prefs.setString(_sessionKey, encoded);
      if (!persisted || prefs.getString(_sessionKey) != encoded) return false;
      _sessionGeneration += 1;
      _notifyLocalPrincipalChanged();
      if (connectAccessToken != null && connectAccessToken.isNotEmpty) {
        await BackendRealtimeService.connect(connectAccessToken);
      }
      return true;
    });
  }

  static Future<bool> _removeStoredSessionIfRawMatches(String expectedRaw) {
    return _sessionMutationQueue.run(() async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_sessionKey) != expectedRaw) return false;
      final removed = await prefs.remove(_sessionKey);
      if (!removed || prefs.containsKey(_sessionKey)) return false;
      _sessionGeneration += 1;
      _refreshInFlight = null;
      _notifyLocalPrincipalChanged();
      return true;
    });
  }

  @visibleForTesting
  static Future<bool> persistRefreshResultSafely({
    required bool Function() isCurrent,
    required Future<void> Function() persist,
    required Future<void> Function() remove,
  }) async {
    if (!isCurrent()) return false;
    await persist();
    if (isCurrent()) return true;
    await remove();
    return false;
  }

  static Future<List<Map<String, dynamic>>> _readAccounts(
    SharedPreferences prefs,
  ) async {
    try {
      final raw = prefs.getString(_accountsKey);
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (error) {
      debugPrint('[AuthService] _readAccounts failed: $error');
      return <Map<String, dynamic>>[];
    }
  }
}

class _DiscardedRefreshResult implements Exception {
  const _DiscardedRefreshResult();
}

enum AuthSocialProvider { google, apple, facebook }

enum PhoneVerificationFailure {
  invalidPhone,
  invalidCode,
  invalidToken,
  phoneMismatch,
  phoneAlreadyVerified,
  rateLimited,
  sessionExpired,
  timeout,
  unavailable,
  network,
}

class PhoneVerificationException implements Exception {
  final PhoneVerificationFailure failure;

  const PhoneVerificationException(this.failure);
}

class PhoneVerificationChallenge {
  final String phoneNumber;
  final String? verificationId;
  final bool automaticallyVerified;

  const PhoneVerificationChallenge({
    required this.phoneNumber,
    this.verificationId,
    this.automaticallyVerified = false,
  });
}

class _SocialSignInCancelled implements Exception {
  const _SocialSignInCancelled();
}

class _SocialProviderUnavailable implements Exception {
  final Object? cause;
  const _SocialProviderUnavailable([this.cause]);
}

class AuthSession {
  final String? userId;
  final String email;
  final DateTime? createdAt;
  final String? accessToken;
  final String? refreshToken;
  final String? sessionId;
  final DateTime? accessTokenExpiresAt;

  const AuthSession({
    this.userId,
    required this.email,
    this.createdAt,
    this.accessToken,
    this.refreshToken,
    this.sessionId,
    this.accessTokenExpiresAt,
  });
}

/// Principal plus session identity captured synchronously with the auth epoch.
/// Tokens are intentionally excluded so this value is safe to retain in UI
/// state and cannot be used as a credential container.
class AuthSessionOwner {
  final String? userId;
  final String? sessionId;
  final String email;
  final DateTime? createdAt;
  final int epoch;

  const AuthSessionOwner({
    required this.userId,
    required this.sessionId,
    required this.email,
    required this.createdAt,
    required this.epoch,
  });
}

class AuthSessionClearReceipt {
  final AuthSessionOwner owner;
  final int completionEpoch;

  const AuthSessionClearReceipt({
    required this.owner,
    required this.completionEpoch,
  });
}

enum AuthFailure {
  invalidCredentials,
  invalidEmail,
  emailVerificationRequired,
  weakPassword,
  consentRequired,
  network,
  emailInUse,
  notImplemented,
  socialCancelled,
  providerUnavailable,
  socialEmailRequired,
  socialEmailVerificationRequired,
  socialProviderAlreadyLinked,
  socialAccountLinkRequiresReauthentication,
  accountNotActive,
}

class AuthResult {
  final bool ok;
  final AuthFailure? failure;
  final AuthSession? session;
  final bool verificationEmailSent;
  final String? pendingEmail;

  const AuthResult.success({
    this.session,
    this.verificationEmailSent = false,
    this.pendingEmail,
  })  : ok = true,
        failure = null;
  const AuthResult.failure(this.failure)
      : ok = false,
        session = null,
        verificationEmailSent = false,
        pendingEmail = null;
}
