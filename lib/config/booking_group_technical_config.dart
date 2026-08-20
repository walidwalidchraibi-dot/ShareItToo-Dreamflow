import 'package:flutter/foundation.dart';

/// G3 multi-item work remains a local/test-only technical path.
///
/// A release build cannot expose this surface even when a build-time value is
/// supplied accidentally. Public activation requires the later legal and
/// release gates and therefore has no runtime override here.
class BookingGroupTechnicalConfig {
  static const bool enabled = bool.fromEnvironment(
    'SIT_BOOKING_GROUPS_TECHNICAL_UI_ENABLED',
    defaultValue: false,
  );

  static const bool publicReleaseAllowed = bool.fromEnvironment(
    'SIT_BOOKING_GROUPS_PUBLIC_RELEASE_ALLOWED',
    defaultValue: false,
  );

  static bool get available => availableForMode(releaseMode: kReleaseMode);

  @visibleForTesting
  static bool availableForMode({required bool releaseMode}) {
    return enabled && !publicReleaseAllowed && !releaseMode;
  }
}
