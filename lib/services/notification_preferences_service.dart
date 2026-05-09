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
  final bool showSupport;
  final bool showPayments;
  final bool showReviews;
  final bool showSecurity;
  final bool showSystem;
  final bool groupByCategory;
  final bool unreadFirst;

  const NotificationPreferences({
    required this.showImportant,
    required this.showBookings,
    required this.showMessages,
    required this.showSupport,
    required this.showPayments,
    required this.showReviews,
    required this.showSecurity,
    required this.showSystem,
    required this.groupByCategory,
    required this.unreadFirst,
  });

  factory NotificationPreferences.defaults() => const NotificationPreferences(
    showImportant: true,
    showBookings: true,
    showMessages: true,
    showSupport: true,
    showPayments: true,
    showReviews: true,
    showSecurity: true,
    showSystem: true,
    groupByCategory: true,
    unreadFirst: true,
  );

  NotificationPreferences copyWith({
    bool? showImportant,
    bool? showBookings,
    bool? showMessages,
    bool? showSupport,
    bool? showPayments,
    bool? showReviews,
    bool? showSecurity,
    bool? showSystem,
    bool? groupByCategory,
    bool? unreadFirst,
  }) => NotificationPreferences(
    // Locked categories: always true.
    showImportant: true,
    showBookings: showBookings ?? this.showBookings,
    showMessages: showMessages ?? this.showMessages,
    showSupport: showSupport ?? this.showSupport,
    showPayments: showPayments ?? this.showPayments,
    showReviews: showReviews ?? this.showReviews,
    // Locked categories: always true.
    showSecurity: true,
    showSystem: showSystem ?? this.showSystem,
    groupByCategory: groupByCategory ?? this.groupByCategory,
    unreadFirst: unreadFirst ?? this.unreadFirst,
  );

  Map<String, dynamic> toJson() => {
    'showImportant': showImportant,
    'showBookings': showBookings,
    'showMessages': showMessages,
    'showSupport': showSupport,
    'showPayments': showPayments,
    'showReviews': showReviews,
    'showSecurity': showSecurity,
    'showSystem': showSystem,
    'groupByCategory': groupByCategory,
    'unreadFirst': unreadFirst,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final d = NotificationPreferences.defaults();
    bool b(String k, bool v) {
      final raw = json[k];
      if (raw is bool) return raw;
      return v;
    }

    return NotificationPreferences(
      // Locked categories: always enabled.
      showImportant: true,
      showBookings: b('showBookings', d.showBookings),
      showMessages: b('showMessages', d.showMessages),
      showSupport: b('showSupport', d.showSupport),
      showPayments: b('showPayments', d.showPayments),
      showReviews: b('showReviews', d.showReviews),
      // Locked categories: always enabled.
      showSecurity: true,
      showSystem: b('showSystem', d.showSystem),
      groupByCategory: b('groupByCategory', d.groupByCategory),
      unreadFirst: b('unreadFirst', d.unreadFirst),
    );
  }
}

class NotificationPreferencesService {
  static const _key = 'notification_preferences_v2';

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
      // Sanitize to enforce locked categories.
      final sanitized = value.copyWith(showImportant: true, showSecurity: true);
      await prefs.setString(_key, jsonEncode(sanitized.toJson()));
    } catch (e) {
      debugPrint('[NotificationPreferencesService] set failed: $e');
    }
  }

  static Future<void> reset() async => set(NotificationPreferences.defaults());
}
