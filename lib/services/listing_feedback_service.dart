import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ListingFeedbackService {
  static const _hiddenItemIdsKey = 'hidden_listing_ids_v1';
  static const _feedbackLogKey = 'listing_feedback_log_v1';
  static const _reasonProfileKey = 'listing_feedback_reason_profile_v1';

  static Future<Set<String>> getHiddenItemIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_hiddenItemIdsKey) ?? const <String>[]).toSet();
  }

  static Future<void> hideItem(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_hiddenItemIdsKey) ?? const <String>[]).toSet();
    ids.add(itemId);
    await prefs.setStringList(_hiddenItemIdsKey, ids.toList());
  }

  static Future<void> recordFeedback({
    required String itemId,
    required String reason,
    String? categoryId,
    double? pricePerDay,
    String? city,
    bool hideOnlyThisItem = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();

    final log = prefs.getStringList(_feedbackLogKey) ?? <String>[];
    final entry = jsonEncode({
      'itemId': itemId,
      'reason': reason,
      'categoryId': categoryId,
      'pricePerDay': pricePerDay,
      'city': city,
      'hideOnlyThisItem': hideOnlyThisItem,
      'recordedAt': now,
    });
    log.add(entry);
    await prefs.setStringList(_feedbackLogKey, log);

    final rawProfile = prefs.getString(_reasonProfileKey);
    final profile = rawProfile == null || rawProfile.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawProfile) as Map<String, dynamic>;

    final reasonCounts = Map<String, dynamic>.from(profile['reasonCounts'] as Map? ?? {});
    reasonCounts[reason] = (reasonCounts[reason] as int? ?? 0) + 1;
    profile['reasonCounts'] = reasonCounts;

    if (categoryId != null && categoryId.isNotEmpty) {
      final dislikedCategories = Map<String, dynamic>.from(profile['categorySignals'] as Map? ?? {});
      dislikedCategories[categoryId] = (dislikedCategories[categoryId] as int? ?? 0) + ((reason == 'not_interesting') ? 2 : 1);
      profile['categorySignals'] = dislikedCategories;
    }

    if (reason == 'too_far') {
      profile['distanceSensitivityDownvotes'] = (profile['distanceSensitivityDownvotes'] as int? ?? 0) + 1;
    }
    if (reason == 'too_expensive') {
      profile['priceSensitivityDownvotes'] = (profile['priceSensitivityDownvotes'] as int? ?? 0) + 1;
      if (pricePerDay != null) {
        final samples = List<num>.from(profile['expensivePriceSamples'] as List? ?? []);
        samples.add(pricePerDay);
        profile['expensivePriceSamples'] = samples;
      }
    }
    if (reason == 'already_have') {
      profile['similarityDownvotes'] = (profile['similarityDownvotes'] as int? ?? 0) + 1;
    }
    if (reason == 'seen_too_often') {
      profile['frequencyDownvotes'] = (profile['frequencyDownvotes'] as int? ?? 0) + 1;
    }

    await prefs.setString(_reasonProfileKey, jsonEncode(profile));

    if (hideOnlyThisItem) {
      await hideItem(itemId);
    }
  }
}
