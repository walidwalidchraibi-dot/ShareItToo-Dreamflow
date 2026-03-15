import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:lendify/models/sit_credit_transaction.dart';

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
  static const String _txKey = 'sit_credit_transactions_v1';

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

  static Future<List<SitCreditTransaction>> getTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _ensureSeeded(prefs);
      final raw = prefs.getString(_txKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = <SitCreditTransaction>[];
      for (final e in decoded) {
        if (e is Map) {
          final map = e.map((k, v) => MapEntry(k.toString(), v));
          final tx = SitCreditTransaction.fromJson(map);
          if (tx.id.isEmpty) continue;
          items.add(tx);
        }
      }
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      debugPrint('[SitCreditService] getTransactions failed: $e');
      return const [];
    }
  }

  static Future<void> addTransaction(SitCreditTransaction tx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _ensureSeeded(prefs);
      final current = await getTransactions();
      final next = [tx, ...current];
      await prefs.setString(_txKey, jsonEncode(next.map((e) => e.toJson()).toList()));

      // Keep balance consistent with tx stream.
      final status = await getStatus();
      await setBalance((status.balance + tx.amount).clamp(-999999, 999999).toDouble());
    } catch (e) {
      debugPrint('[SitCreditService] addTransaction failed: $e');
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

      if (!prefs.containsKey(_txKey)) {
        final now = DateTime.now();
        final demo = [
          SitCreditTransaction(
            id: 'tx_${now.subtract(const Duration(days: 2)).microsecondsSinceEpoch}',
            type: SitCreditTransactionType.deposit,
            amount: 25.00,
            title: 'Einnahmen aus Vermietung',
            subtitle: 'Buchung abgeschlossen',
            createdAt: now.subtract(const Duration(days: 2, hours: 3)),
          ),
          SitCreditTransaction(
            id: 'tx_${now.subtract(const Duration(days: 1)).microsecondsSinceEpoch}',
            type: SitCreditTransactionType.spend,
            amount: -6.50,
            title: 'Buchung bezahlt',
            subtitle: 'SIT Guthaben verwendet',
            createdAt: now.subtract(const Duration(days: 1, hours: 6)),
          ),
        ];
        await prefs.setString(_txKey, jsonEncode(demo.map((e) => e.toJson()).toList()));
      }
      await prefs.setBool(_seededKey, true);
    } catch (e) {
      debugPrint('[SitCreditService] ensureSeeded failed: $e');
    }
  }
}
