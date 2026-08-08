import 'package:flutter/foundation.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/developer_preview_service.dart';
import 'package:lendify/services/qa_runtime_service.dart';

class QaBootstrapService {
  static bool isEnabled({Uri? uri, bool? debugMode}) {
    final effectiveUri = uri ?? Uri.base;
    final allow = debugMode ?? !kReleaseMode;
    return allow && effectiveUri.queryParameters['qa'] == '1';
  }

  static String resolvePersonaId({Uri? uri}) {
    final raw = (uri ?? Uri.base).queryParameters['persona']?.trim();
    if (raw == null || raw.isEmpty) return 'u1';
    return kQaAllowedPersonaIds.contains(raw) ? raw : 'u1';
  }

  static Future<DeveloperUserState?> maybeBootstrap({
    Uri? uri,
    bool? debugMode,
  }) async {
    final effectiveUri = uri ?? Uri.base;
    if (!isEnabled(uri: effectiveUri, debugMode: debugMode)) {
      QaRuntimeService.reset();
      return null;
    }

    QaRuntimeService.configureFromUri(effectiveUri, debugMode: debugMode);
    await DataService.getCurrentUser();
    return DeveloperUserState.loggedIn;
  }
}
