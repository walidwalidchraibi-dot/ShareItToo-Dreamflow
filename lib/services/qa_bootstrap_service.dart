import 'package:flutter/foundation.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/developer_preview_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QaBootstrapService {
  static const String _previewKey = 'dev_preview_user_state_v1';
  static const Set<String> _allowedPersonaIds = {'u1', 'u2'};

  static bool isEnabled({Uri? uri, bool? debugMode}) {
    final effectiveUri = uri ?? Uri.base;
    final allow = debugMode ?? !kReleaseMode;
    return allow && effectiveUri.queryParameters['qa'] == '1';
  }

  static String resolvePersonaId({Uri? uri}) {
    final raw = (uri ?? Uri.base).queryParameters['persona']?.trim();
    if (raw == null || raw.isEmpty) return 'u1';
    return _allowedPersonaIds.contains(raw) ? raw : 'u1';
  }

  static Future<DeveloperUserState?> maybeBootstrap({
    Uri? uri,
    bool? debugMode,
  }) async {
    if (!isEnabled(uri: uri, debugMode: debugMode)) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_previewKey, DeveloperUserState.loggedIn.name);

    final personaId = resolvePersonaId(uri: uri);
    final users = await DataService.getUsers();
    final User target = users.firstWhere(
      (u) => u.id == personaId,
      orElse: () => users.firstWhere((u) => u.id == 'u1'),
    );

    await DataService.setCurrentUser(target);
    return DeveloperUserState.loggedIn;
  }
}
