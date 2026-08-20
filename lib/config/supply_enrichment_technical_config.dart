import 'package:flutter/foundation.dart';

/// G5A is a disabled technical path for deterministic post-listing questions.
///
/// It cannot be exposed by a signed release build and has no external-AI
/// runtime switch.
class SupplyEnrichmentTechnicalConfig {
  static const bool enabled = bool.fromEnvironment(
    'SIT_SUPPLY_ENRICHMENT_TECHNICAL_UI_ENABLED',
    defaultValue: false,
  );

  static const bool publicReleaseAllowed = false;
  static const bool externalGenerativeAiAllowed = false;

  static bool get available => availableForMode(releaseMode: kReleaseMode);

  @visibleForTesting
  static bool availableForMode({required bool releaseMode}) {
    return enabled &&
        !publicReleaseAllowed &&
        !externalGenerativeAiAllowed &&
        !releaseMode;
  }
}
