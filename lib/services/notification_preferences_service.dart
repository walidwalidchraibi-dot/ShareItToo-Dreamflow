import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only notification settings (no push/e-mail in MVP).
///
/// These settings control what categories are shown in the in-app notification
/// feed and how it behaves. Stored via SharedPreferences.
class NotificationPreferences {
  final bool showImportant;
  final bool showBookings;
  final bool showMessages;
  final bool showReviews;
  final bool showPayments;
  final bool showSecurity;
  final bool showSystem;
  final bool groupByCategory;

  const NotificationPreferences({
    required this.showImportant,
    required this.showBookings,
    required this.showMessages,
    required this.showReviews,
    required this.showPayments,
    required this.showSecurity,
    required this.showSystem,
    required this.groupByCategory,
  });

  factory NotificationPreferences.defaults() => const NotificationPreferences(
    showImportant: true,
    showBookings: true,
    showMessages: true,
    showReviews: true,
    showPayments: true,
    showSecurity: true,
    showSystem: true,
    groupByCategory: true,
  );

  NotificationPreferences copyWith({
    bool? showImportant,
    bool? showBookings,
    bool? showMessages,
    bool? showReviews,
    bool? showPayments,
    bool? showSecurity,
    bool? showSystem,
    bool? groupByCategory,
  }) => NotificationPreferences(
    showImportant: showImportant ?? this.showImportant,
    showBookings: showBookings ?? this.showBookings,
    showMessages: showMessages ?? this.showMessages,
    showReviews: showReviews ?? this.showReviews,
    showPayments: showPayments ?? this.showPayments,
    showSecurity: showSecurity ?? this.showSecurity,
    showSystem: showSystem ?? this.showSystem,
    groupByCategory: groupByCategory ?? this.groupByCategory,
  );

  Map<String, dynamic> toJson() => {
    'showImportant': showImportant,
    'showBookings': showBookings,
    'showMessages': showMessages,
    'showReviews': showReviews,
    'showPayments': showPayments,
    'showSecurity': showSecurity,
    'showSystem': showSystem,
    'groupByCategory': groupByCategory,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final d = NotificationPreferences.defaults();
    bool b(String k, bool v) {
      final raw = json[k];
      if (raw is bool) return raw;
      return v;
    }

    return NotificationPreferences(
      showImportant: b('showImportant', d.showImportant),
      showBookings: b('showBookings', d.showBookings),
      showMessages: b('showMessages', d.showMessages),
      showReviews: b('showReviews', d.showReviews),
      showPayments: b('showPayments', d.showPayments),
      showSecurity: b('showSecurity', d.showSecurity),
      showSystem: b('showSystem', d.showSystem),
      groupByCategory: b('groupByCategory', d.groupByCategory),
    );
  }
}

class NotificationPreferencesService {
  static const _key = 'notification_preferences_v1';

  static Future<NotificationPreferences> get() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return NotificationPreferences.defaults();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return NotificationPreferences.defaults();
      return NotificationPreferences.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('[NotificationPreferencesService] get failed: $e');
      return NotificationPreferences.defaults();
    }
  }

  static Future<void> set(NotificationPreferences value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(value.toJson()));
    } catch (e) {
      debugPrint('[NotificationPreferencesService] set failed: $e');
    }
  }

  static Future<void> reset() async => set(NotificationPreferences.defaults());
}
