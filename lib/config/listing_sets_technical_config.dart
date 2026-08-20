import 'package:flutter/foundation.dart';

/// G5B listing sets are a disabled technical path until the later legal and
/// public-release gates. They never authorize production or release use.
class ListingSetsTechnicalConfig {
  static const bool enabled = bool.fromEnvironment(
    'SIT_LISTING_SETS_TECHNICAL_UI_ENABLED',
    defaultValue: false,
  );

  static const bool publicReleaseAllowed = false;
  static const bool fewerHandoversRankingAllowed = true;
  static const bool businessStatusRankingAllowed = false;
  static const bool hiddenPriceManipulationAllowed = false;

  static bool get available => availableForMode(releaseMode: kReleaseMode);

  @visibleForTesting
  static bool availableForMode({required bool releaseMode}) {
    return enabled &&
        !publicReleaseAllowed &&
        fewerHandoversRankingAllowed &&
        !businessStatusRankingAllowed &&
        !hiddenPriceManipulationAllowed &&
        !releaseMode;
  }
}
