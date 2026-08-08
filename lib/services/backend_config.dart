import 'package:flutter/foundation.dart';

class BackendConfig {
  static const bool enabled = bool.fromEnvironment(
    'SIT_BACKEND_ENABLED',
    defaultValue: kReleaseMode,
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'SIT_API_BASE_URL',
    defaultValue: 'https://shareittoo.com/api/v1',
  );

  static Uri uri(String path) {
    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    final suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$suffix');
  }

  static Uri get realtimeUri {
    final httpUri = uri('/realtime');
    return httpUri.replace(scheme: httpUri.scheme == 'https' ? 'wss' : 'ws');
  }
}
