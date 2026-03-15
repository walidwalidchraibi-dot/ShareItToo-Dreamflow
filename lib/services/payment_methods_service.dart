import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lendify/models/payment_method.dart';

class PaymentMethodsService {
  static const String _key = 'payment_methods_v1';
  static const String _seededKey = 'payment_methods_seeded_v1';

  static Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _ensureSeeded(prefs);
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final parsed = <PaymentMethod>[];
      for (final e in decoded) {
        if (e is Map) {
          final map = e.map((k, v) => MapEntry(k.toString(), v));
          final pm = PaymentMethod.fromJson(map);
          if (pm.id.isEmpty) continue;
          parsed.add(pm);
        }
      }
      return _normalized(parsed);
    } catch (e) {
      debugPrint('[PaymentMethodsService] getPaymentMethods failed: $e');
      return const [];
    }
  }

  static Future<void> setPaymentMethods(List<PaymentMethod> methods) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalized = _normalized(methods);
      await prefs.setString(_key, jsonEncode(normalized.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[PaymentMethodsService] setPaymentMethods failed: $e');
    }
  }

  static Future<List<PaymentMethod>> add(PaymentMethod method) async {
    final current = await getPaymentMethods();
    final now = DateTime.now();
    final next = [...current];
    final isFirst = next.isEmpty;
    next.add(method.copyWith(
      isDefault: isFirst ? true : method.isDefault,
      updatedAt: now,
    ));
    final normalized = _normalized(next);
    await setPaymentMethods(normalized);
    return normalized;
  }

  static Future<List<PaymentMethod>> setDefault(String id) async {
    final current = await getPaymentMethods();
    final now = DateTime.now();
    final updated = current
        .map((m) => m.id == id
            ? m.copyWith(isDefault: true, updatedAt: now)
            : (m.isDefault ? m.copyWith(isDefault: false, updatedAt: now) : m))
        .toList();
    final normalized = _normalized(updated);
    await setPaymentMethods(normalized);
    return normalized;
  }

  static Future<List<PaymentMethod>> remove(String id) async {
    final current = await getPaymentMethods();
    final removed = current.where((m) => m.id != id).toList();
    final normalized = _normalized(removed);
    await setPaymentMethods(normalized);
    return normalized;
  }

  static List<PaymentMethod> _normalized(List<PaymentMethod> methods) {
    if (methods.isEmpty) return const [];

    // Ensure exactly one default (prefer existing first default; else first item).
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

      final now = DateTime.now();
      final demo = <PaymentMethod>[
        PaymentMethod(
          id: 'pm_visa_demo',
          type: PaymentMethodType.visa,
          isDefault: true,
          label: 'Visa',
          last4: '4242',
          holderName: 'Max Mustermann',
          createdAt: now.subtract(const Duration(days: 14)),
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
        PaymentMethod(
          id: 'pm_paypal_demo',
          type: PaymentMethodType.paypal,
          isDefault: false,
          label: 'PayPal',
          createdAt: now.subtract(const Duration(days: 7)),
          updatedAt: now.subtract(const Duration(days: 7)),
        ),
      ];
      await prefs.setString(_key, jsonEncode(demo.map((e) => e.toJson()).toList()));
      await prefs.setBool(_seededKey, true);
    } catch (e) {
      debugPrint('[PaymentMethodsService] ensureSeeded failed: $e');
    }
  }
}
