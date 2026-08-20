import 'package:flutter/foundation.dart';

/// G4 planner work remains an inactive deterministic technical path.
///
/// G4A has no public UI and no inventory resolver. A later release cannot
/// expose the surface through this flag, and external generative AI has no
/// runtime switch in this package.
class PlannerTechnicalConfig {
  static const bool enabled = bool.fromEnvironment(
    'SIT_PLANNER_TECHNICAL_UI_ENABLED',
    defaultValue: false,
  );

  static const bool publicReleaseAllowed = false;
  static const bool externalGenerativeAiAllowed = false;
  static const bool inventoryResolutionAllowed = false;

  static bool get available => availableForMode(releaseMode: kReleaseMode);

  @visibleForTesting
  static bool availableForMode({required bool releaseMode}) {
    return enabled &&
        !publicReleaseAllowed &&
        !externalGenerativeAiAllowed &&
        !inventoryResolutionAllowed &&
        !releaseMode;
  }
}
