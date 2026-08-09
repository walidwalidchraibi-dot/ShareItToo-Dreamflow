import 'package:flutter/foundation.dart';

import 'backend_config.dart';

/// Immutable identity embedded in every closed-test or production binary.
class ReleaseIdentity {
  static const String appCommit = String.fromEnvironment('SIT_APP_COMMIT');
  static const String buildNumber = String.fromEnvironment('SIT_BUILD_NUMBER');
  static const String releaseChannel = String.fromEnvironment(
    'SIT_RELEASE_CHANNEL',
    defaultValue: 'development',
  );
  static const String bundleId = String.fromEnvironment(
    'SIT_BUNDLE_ID',
    defaultValue: 'com.shareittoo.app',
  );

  static String? validationError({
    required bool releaseMode,
    required String commit,
    required String build,
    required String channel,
    required String applicationId,
    required String apiBaseUrl,
  }) {
    if (!releaseMode) return null;
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
      return 'SIT_APP_COMMIT must be the complete 40-character Git commit.';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(build)) {
      return 'SIT_BUILD_NUMBER must use the 10-digit YYYYMMDDNN scheme.';
    }
    if (!const {'internal', 'staging', 'production'}.contains(channel)) {
      return 'SIT_RELEASE_CHANNEL must be internal, staging, or production.';
    }
    if (applicationId != 'com.shareittoo.app') {
      return 'Unexpected application identifier: $applicationId.';
    }
    final apiUri = Uri.tryParse(apiBaseUrl);
    if (apiUri == null || apiUri.scheme != 'https' || apiUri.host.isEmpty) {
      return 'SIT_API_BASE_URL must be an absolute HTTPS URL.';
    }
    return null;
  }

  static void validateCurrentBuild() {
    final error = validationError(
      releaseMode: kReleaseMode,
      commit: appCommit,
      build: buildNumber,
      channel: releaseChannel,
      applicationId: bundleId,
      apiBaseUrl: BackendConfig.apiBaseUrl,
    );
    if (error != null) {
      throw StateError('Invalid ShareItToo release identity: $error');
    }
  }
}
