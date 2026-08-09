import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lendify/services/backend_config.dart';
import 'package:lendify/services/backend_repository.dart';
import 'package:lendify/services/qa_runtime_service.dart';

/// Local-only blocked-users store.
///
/// Keeps a list of user ids that are blocked from contacting the current user.
/// (No backend connected.)
class BlockedUsersService {
  static const _key = 'blocked_user_ids_v1';

  static Future<List<String>> getBlockedUserIds() async {
    try {
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        final remote = await BackendRepository.getBlockedUserIds();
        await setBlockedUserIds(remote);
        return remote;
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      debugPrint('[BlockedUsersService] getBlockedUserIds failed: $e');
      return const [];
    }
  }

  static Future<void> setBlockedUserIds(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleaned = ids
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      await prefs.setString(_key, jsonEncode(cleaned));
    } catch (e) {
      debugPrint('[BlockedUsersService] setBlockedUserIds failed: $e');
    }
  }

  static Future<bool> isBlocked(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return false;
    final current = await getBlockedUserIds();
    return current.contains(id);
  }

  static Future<void> blockUser(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    final current = await getBlockedUserIds();
    if (current.contains(id)) return;
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      await BackendRepository.blockUser(id);
    }
    await setBlockedUserIds([...current, id]);
  }

  static Future<void> unblockUser(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    final current = await getBlockedUserIds();
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      await BackendRepository.unblockUser(id);
    }
    await setBlockedUserIds(
      current.where((e) => e != id).toList(growable: false),
    );
  }
}
