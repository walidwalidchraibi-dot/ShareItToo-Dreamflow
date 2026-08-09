import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lendify/services/backend_config.dart';
import 'package:lendify/services/backend_repository.dart';
import 'package:lendify/services/qa_runtime_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server-authoritative reporting with an explicit local QA fallback.
class UserReportsService {
  static const _key = 'user_reports_v1';

  static Future<void> addReport({
    required String reporterUserId,
    required String reportedUserId,
    required String reasonCode,
    String details = '',
    List<String> evidenceNames = const [],
    List<String> evidenceUploadIds = const [],
    String? reference,
  }) async {
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      await BackendRepository.createReport(
        targetType: 'user',
        targetId: reportedUserId,
        reasonCode: reasonCode,
        details: details,
        reference: reference,
        evidenceUploadIds: evidenceUploadIds,
      );
      return;
    }
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
        'reasonCode': reasonCode,
        'details': details,
        'evidenceNames': evidenceNames,
        'reference': reference,
        'createdAt': now.toIso8601String(),
      });
      await prefs.setString(_key, jsonEncode(list));
    } catch (e) {
      debugPrint('[UserReportsService] addReport failed: $e');
      rethrow;
    }
  }
}
