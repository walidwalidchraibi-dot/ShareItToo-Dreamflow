import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local auth/session layer (SharedPreferences) to make the app
/// behave like a real product even without a backend.
///
/// This is intentionally simple and can later be replaced by Firebase/Supabase.
class AuthService {
  static const _accountsKey = 'auth_accounts_v1';
  static const _sessionKey = 'auth_session_v1';
  static const _seedKey = 'auth_seeded_v1';

  static const demoEmail = 'demo@shareittoo.app';
  static const demoPassword = 'shareittoo';

  static Future<void> ensureSeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_seedKey) == true) return;
      final accounts = await _readAccounts(prefs);
      final exists = accounts.any((a) => (a['email'] as String?)?.toLowerCase() == demoEmail);
      if (!exists) {
        accounts.add({
          'email': demoEmail,
          'password': demoPassword,
          'createdAt': DateTime.now().toIso8601String(),
        });
        await prefs.setString(_accountsKey, jsonEncode(accounts));
      }
      await prefs.setBool(_seedKey, true);
    } catch (e) {
      debugPrint('[AuthService] ensureSeeded failed: $e');
    }
  }

  static Future<AuthSession?> readSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final email = decoded['email'];
      if (email is! String || email.isEmpty) return null;
      return AuthSession(email: email, createdAt: DateTime.tryParse(decoded['createdAt']?.toString() ?? ''));
    } catch (e) {
      debugPrint('[AuthService] readSession failed: $e');
      return null;
    }
  }

  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (e) {
      debugPrint('[AuthService] clearSession failed: $e');
    }
  }

  static Future<AuthResult> signInWithEmailPassword({required String email, required String password}) async {
    await ensureSeeded();
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await _readAccounts(prefs);
      final normalizedEmail = email.trim().toLowerCase();
      final match = accounts.firstWhere(
        (a) => (a['email'] as String?)?.toLowerCase() == normalizedEmail,
        orElse: () => const <String, Object?>{},
      );
      if (match.isEmpty) return const AuthResult.failure(AuthFailure.invalidCredentials);
      final storedPw = (match['password'] as String?) ?? '';
      if (storedPw != password) return const AuthResult.failure(AuthFailure.invalidCredentials);

      final session = {'email': normalizedEmail, 'createdAt': DateTime.now().toIso8601String()};
      await prefs.setString(_sessionKey, jsonEncode(session));
      return const AuthResult.success();
    } on Exception catch (e) {
      debugPrint('[AuthService] signInWithEmailPassword failed: $e');
      return const AuthResult.failure(AuthFailure.network);
    }
  }

  /// Optional local register used by the existing RegisterScreen.
  static Future<AuthResult> registerLocalAccount({required String email, required String password}) async {
    await ensureSeeded();
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await _readAccounts(prefs);
      final normalizedEmail = email.trim().toLowerCase();
      final exists = accounts.any((a) => (a['email'] as String?)?.toLowerCase() == normalizedEmail);
      if (exists) return const AuthResult.failure(AuthFailure.emailInUse);
      accounts.add({'email': normalizedEmail, 'password': password, 'createdAt': DateTime.now().toIso8601String()});
      await prefs.setString(_accountsKey, jsonEncode(accounts));
      final session = {'email': normalizedEmail, 'createdAt': DateTime.now().toIso8601String()};
      await prefs.setString(_sessionKey, jsonEncode(session));
      return const AuthResult.success();
    } catch (e) {
      debugPrint('[AuthService] registerLocalAccount failed: $e');
      return const AuthResult.failure(AuthFailure.network);
    }
  }

  static Future<List<Map<String, dynamic>>> _readAccounts(SharedPreferences prefs) async {
    try {
      final raw = prefs.getString(_accountsKey);
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('[AuthService] _readAccounts failed: $e');
      return <Map<String, dynamic>>[];
    }
  }
}

class AuthSession {
  final String email;
  final DateTime? createdAt;
  const AuthSession({required this.email, this.createdAt});
}

enum AuthFailure { invalidCredentials, network, emailInUse }

class AuthResult {
  final bool ok;
  final AuthFailure? failure;
  const AuthResult._(this.ok, this.failure);
  const AuthResult.success() : this._(true, null);
  const AuthResult.failure(AuthFailure f) : this._(false, f);
}
