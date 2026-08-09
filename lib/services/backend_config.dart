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

  static bool isManagedListingImageUrl(String value) {
    try {
      final candidate = Uri.parse(value);
      final base = Uri.parse(apiBaseUrl);
      final basePath = base.path.endsWith('/')
          ? base.path.substring(0, base.path.length - 1)
          : base.path;
      final prefix = '$basePath/uploads/';
      if (candidate.scheme != base.scheme ||
          candidate.host != base.host ||
          candidate.port != base.port ||
          !candidate.path.startsWith(prefix)) {
        return false;
      }
      final storageName =
          Uri.decodeComponent(candidate.path.substring(prefix.length));
      return RegExp(
        r'^[0-9a-f-]{36}-full\.(?:webp|jpe?g|png)$',
        caseSensitive: false,
      ).hasMatch(storageName);
    } catch (_) {
      return false;
    }
  }

  static Uri get realtimeUri {
    final httpUri = uri('/realtime');
    return httpUri.replace(scheme: httpUri.scheme == 'https' ? 'wss' : 'ws');
  }
}
