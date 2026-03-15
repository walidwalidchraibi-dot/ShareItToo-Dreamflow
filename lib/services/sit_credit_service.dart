import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

class SitCreditStatus {
  final bool enabled;
  final double balance;

  const SitCreditStatus({required this.enabled, required this.balance});
}

/// Local-only SIT credit preference + balance storage.
///
/// Note: This is intentionally simple (SharedPreferences) until a backend
/// is connected.
class SitCreditService {
  static const String _enabledKey = 'sit_credit_enabled_v1';
  static const String _balanceKey = 'sit_credit_balance_v1';
  static const String _seededKey = 'sit_credit_seeded_v1';

  static Future<SitCreditStatus> getStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _ensureSeeded(prefs);
      final enabled = prefs.getBool(_enabledKey) ?? false;
      final balance = prefs.getDouble(_balanceKey) ?? 0.0;
      return SitCreditStatus(enabled: enabled, balance: balance);
    } catch (e) {
      debugPrint('[SitCreditService] getStatus failed: $e');
      return const SitCreditStatus(enabled: false, balance: 0.0);
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
    } catch (e) {
      debugPrint('[SitCreditService] setEnabled failed: $e');
    }
  }

  static Future<void> setBalance(double balance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_balanceKey, balance);
    } catch (e) {
      debugPrint('[SitCreditService] setBalance failed: $e');
    }
  }

  static Future<void> _ensureSeeded(SharedPreferences prefs) async {
    try {
      final seeded = prefs.getBool(_seededKey) ?? false;
      if (seeded) return;

      // Seed demo balance if nothing exists yet.
      if (!prefs.containsKey(_balanceKey)) {
        await prefs.setDouble(_balanceKey, 18.50);
      }
      if (!prefs.containsKey(_enabledKey)) {
        await prefs.setBool(_enabledKey, false);
      }
      await prefs.setBool(_seededKey, true);
    } catch (e) {
      debugPrint('[SitCreditService] ensureSeeded failed: $e');
    }
  }
}
