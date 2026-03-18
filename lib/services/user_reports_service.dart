import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only user reporting store.
///
/// Until a backend is connected, we store reports locally so the UI is testable.
class UserReportsService {
  static const _key = 'user_reports_v1';

  static Future<void> addReport({
    required String reporterUserId,
    required String reportedUserId,
    required String reason,
    String details = '',
    List<String> evidenceNames = const [],
    String? reference,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) list = decoded;
        } catch (_) {
          list = [];
        }
      }
      final now = DateTime.now();
      list.add({
        'id': 'rep_${now.microsecondsSinceEpoch}',
        'reporterUserId': reporterUserId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'details': details,
        'evidenceNames': evidenceNames,
        'reference': reference,
        'createdAt': now.toIso8601String(),
      });
      await prefs.setString(_key, jsonEncode(list));
    } catch (e) {
      debugPrint('[UserReportsService] addReport failed: $e');
    }
  }
}
