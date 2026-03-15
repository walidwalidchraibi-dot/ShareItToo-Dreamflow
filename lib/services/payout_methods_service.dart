import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lendify/models/payout_method.dart';

class PayoutMethodsService {
  static const String _key = 'payout_methods_v1';
  static const String _seededKey = 'payout_methods_seeded_v1';

  static Future<List<PayoutMethod>> getPayoutMethods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _ensureSeeded(prefs);
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final parsed = <PayoutMethod>[];
      for (final e in decoded) {
        if (e is Map) {
          final map = e.map((k, v) => MapEntry(k.toString(), v));
          final m = PayoutMethod.fromJson(map);
          if (m.id.isEmpty) continue;
          parsed.add(m);
        }
      }
      return _normalized(parsed);
    } catch (e) {
      debugPrint('[PayoutMethodsService] getPayoutMethods failed: $e');
      return const [];
    }
  }

  static Future<void> setPayoutMethods(List<PayoutMethod> methods) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalized = _normalized(methods);
      await prefs.setString(_key, jsonEncode(normalized.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[PayoutMethodsService] setPayoutMethods failed: $e');
    }
  }

  static Future<List<PayoutMethod>> add(PayoutMethod method) async {
    final current = await getPayoutMethods();
    final now = DateTime.now();
    final next = [...current];
    final isFirst = next.isEmpty;
    next.add(method.copyWith(isDefault: isFirst ? true : method.isDefault, updatedAt: now));
    final normalized = _normalized(next);
    await setPayoutMethods(normalized);
    return normalized;
  }

  static Future<List<PayoutMethod>> setDefault(String id) async {
    final current = await getPayoutMethods();
    final now = DateTime.now();
    final updated = current
        .map((m) => m.id == id
            ? m.copyWith(isDefault: true, updatedAt: now)
            : (m.isDefault ? m.copyWith(isDefault: false, updatedAt: now) : m))
        .toList();
    final normalized = _normalized(updated);
    await setPayoutMethods(normalized);
    return normalized;
  }

  static Future<List<PayoutMethod>> remove(String id) async {
    final current = await getPayoutMethods();
    final removed = current.where((m) => m.id != id).toList();
    final normalized = _normalized(removed);
    await setPayoutMethods(normalized);
    return normalized;
  }

  static List<PayoutMethod> _normalized(List<PayoutMethod> methods) {
    if (methods.isEmpty) return const [];

    final firstDefaultIndex = methods.indexWhere((m) => m.isDefault);
    final defaultId = firstDefaultIndex >= 0 ? methods[firstDefaultIndex].id : methods.first.id;
    final now = DateTime.now();

    final normalized = methods
        .map((m) => m.id == defaultId
            ? (m.isDefault ? m : m.copyWith(isDefault: true, updatedAt: now))
            : (!m.isDefault ? m : m.copyWith(isDefault: false, updatedAt: now)))
        .toList();

    normalized.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return normalized;
  }

  static Future<void> _ensureSeeded(SharedPreferences prefs) async {
    try {
      final seeded = prefs.getBool(_seededKey) ?? false;
      if (seeded) return;
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        await prefs.setBool(_seededKey, true);
        return;
      }

      // Start empty (no automatic demo methods), so empty state can be previewed.
      await prefs.setString(_key, jsonEncode(const []));
      await prefs.setBool(_seededKey, true);
    } catch (e) {
      debugPrint('[PayoutMethodsService] ensureSeeded failed: $e');
    }
  }
}
