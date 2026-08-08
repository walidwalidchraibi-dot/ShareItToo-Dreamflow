import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_config.dart';
import 'backend_http.dart';
import 'backend_realtime_service.dart';

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
        await prefs.remove(_sessionKey);
        return null;
      }
      final session = AuthSession(
        userId: map['userId']?.toString(),
        email: normalizedEmail,
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
        accessToken: map['accessToken']?.toString(),
        refreshToken: map['refreshToken']?.toString(),
        accessTokenExpiresAt: DateTime.tryParse(
          map['accessTokenExpiresAt']?.toString() ?? '',
        ),
      );
      if (BackendConfig.enabled &&
          ((session.userId ?? '').isEmpty ||
              (session.accessToken ?? '').isEmpty ||
              (session.refreshToken ?? '').isEmpty)) {
        await prefs.remove(_sessionKey);
        return null;
      }
      return session;
    } catch (error) {
      debugPrint('[AuthService] readSession failed: $error');
      return null;
    }
  }

  static Future<void> clearSession() async {
    try {
      final session = await readSession();
      if (BackendConfig.enabled && (session?.refreshToken ?? '').isNotEmpty) {
        try {
          await BackendHttp.requestJson(
            method: 'POST',
            path: '/auth/logout',
            body: {'refreshToken': session!.refreshToken},
          );
        } catch (_) {
          // Local logout must still succeed while offline.
        }
      }
      await BackendRealtimeService.disconnect();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (error) {
      debugPrint('[AuthService] clearSession failed: $error');
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
      await prefs.setString(_sessionKey, jsonEncode(sessionData));
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
  }) async {
    if (BackendConfig.enabled) {
      try {
        final response = await BackendHttp.requestJson(
          method: 'POST',
          path: '/auth/register',
          body: {'email': email.trim(), 'password': password},
        );
        final session = await _saveRemoteSession(response);
        return AuthResult.success(session: session);
      } on BackendException catch (error) {
        if (error.statusCode == 409 || error.code == 'email_in_use') {
          return const AuthResult.failure(AuthFailure.emailInUse);
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
      await prefs.setString(_sessionKey, jsonEncode(sessionData));
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

  static Future<bool> requestEmailVerification() async {
    if (!BackendConfig.enabled) return true;
    var token = await accessToken() ?? '';
    if (token.isEmpty) return false;
    try {
      await BackendHttp.requestJson(
        method: 'POST',
        path: '/auth/email-verification/request',
        accessToken: token,
      );
      return true;
    } on BackendException catch (error) {
      if (error.statusCode != 401) {
        debugPrint('[AuthService] verification request failed: $error');
        return false;
      }
      token = await refreshAccessToken() ?? '';
      if (token.isEmpty) return false;
      try {
        await BackendHttp.requestJson(
          method: 'POST',
          path: '/auth/email-verification/request',
          accessToken: token,
        );
        return true;
      } catch (retryError) {
        debugPrint('[AuthService] verification retry failed: $retryError');
        return false;
      }
    } catch (error) {
      debugPrint('[AuthService] verification request failed: $error');
      return false;
    }
  }

  static Future<String?> refreshAccessToken() async {
    if (!BackendConfig.enabled) return null;
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final refresh = _performAccessTokenRefresh();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  static Future<String?> _performAccessTokenRefresh() async {
    final session = await readSession();
    final refreshToken = session?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final response = await BackendHttp.requestJson(
        method: 'POST',
        path: '/auth/refresh',
        body: {'refreshToken': refreshToken},
      );
      final refreshed = await _saveRemoteSession(response);
      return refreshed.accessToken;
    } catch (error) {
      debugPrint('[AuthService] refresh failed: $error');
      await BackendRealtimeService.disconnect();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      return null;
    }
  }

  static Future<AuthResult> signInWithSocialProvider(
    AuthSocialProvider provider,
  ) async {
    debugPrint(
      '[AuthService] signInWithSocialProvider unavailable for ${provider.name}',
    );
    return const AuthResult.failure(AuthFailure.notImplemented);
  }

  static Future<AuthSession> _saveRemoteSession(
    Map<String, dynamic> response,
  ) async {
    final user = Map<String, dynamic>.from(response['user'] as Map);
    final accessToken = response['accessToken']?.toString() ?? '';
    final refreshToken = response['refreshToken']?.toString() ?? '';
    final expiresIn = (response['expiresIn'] as num?)?.toInt() ?? 900;
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw const BackendException(500, 'invalid_auth_response');
    }
    final now = DateTime.now();
    final session = AuthSession(
      userId: user['id']?.toString(),
      email: user['email']?.toString().trim().toLowerCase() ?? '',
      createdAt: DateTime.tryParse(user['createdAt']?.toString() ?? '') ?? now,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: now.add(Duration(seconds: expiresIn)),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionKey,
      jsonEncode({
        'userId': session.userId,
        'email': session.email,
        'createdAt': session.createdAt?.toIso8601String(),
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'accessTokenExpiresAt': session.accessTokenExpiresAt?.toIso8601String(),
      }),
    );
    await BackendRealtimeService.connect(accessToken);
    return session;
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
enum AuthSocialProvider { google, apple }

class AuthSession {
  final String? userId;
  final String email;
  final DateTime? createdAt;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? accessTokenExpiresAt;

  const AuthSession({
    this.userId,
    required this.email,
    this.createdAt,
    this.accessToken,
    this.refreshToken,
    this.accessTokenExpiresAt,
  });
}

enum AuthFailure { invalidCredentials, network, emailInUse, notImplemented }

class AuthResult {
  final bool ok;
  final AuthFailure? failure;
  final AuthSession? session;
  final bool verificationEmailSent;

  const AuthResult.success({this.session, this.verificationEmailSent = false})
      : ok = true,
        failure = null;
  const AuthResult.failure(AuthFailure failure)
      : ok = false,
        failure = failure,
        session = null,
        verificationEmailSent = false;
}
