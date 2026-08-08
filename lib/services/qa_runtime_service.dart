import 'package:flutter/foundation.dart';

const Set<String> kQaAllowedPersonaIds = {'u1', 'u2'};

/// Keeps the QA persona inside the current app instance instead of persisting
/// it in SharedPreferences. On web, each browser tab has its own Dart runtime,
/// so owner and renter tabs can share booking data without sharing identity.
class QaRuntimeService {
  static bool _enabled = false;
  static String _personaId = 'u1';
  static Map<String, dynamic>? _runtimeUserJson;

  static bool get isEnabled => _enabled;
  static String get personaId => _personaId;

  static void configureFromUri(Uri uri, {bool? debugMode}) {
    final allow = debugMode ?? !kReleaseMode;
    if (!allow || uri.queryParameters['qa'] != '1') {
      reset();
      return;
    }

    final requestedPersona = uri.queryParameters['persona']?.trim();
    _personaId = requestedPersona != null &&
            kQaAllowedPersonaIds.contains(requestedPersona)
        ? requestedPersona
        : 'u1';
    _runtimeUserJson = null;
    _enabled = true;
  }

  static Map<String, dynamic>? get runtimeUserJson => _runtimeUserJson == null
      ? null
      : Map<String, dynamic>.from(_runtimeUserJson!);

  static void setRuntimeUserJson(Map<String, dynamic> userJson) {
    if (!_enabled) return;
    _runtimeUserJson = Map<String, dynamic>.from(userJson);
  }

  static void clearRuntimeUser() {
    _runtimeUserJson = null;
  }

  static void reset() {
    _enabled = false;
    _personaId = 'u1';
    _runtimeUserJson = null;
  }
}
