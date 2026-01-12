/// Centralized labels and mappings for item condition across the app.
///
/// Internal item.condition values (persisted):
/// - 'new' | 'like-new' | 'good' | 'acceptable' | legacy: 'used'
///
/// FiltersOverlay uses German-coded values:
/// - 'neu' | 'wie-neu' | 'gut' | 'akzeptabel' | 'egal'
class ConditionLabels {
  /// Display label for an internal condition code.
  static String label(String code) {
    switch (code) {
      case 'new': return 'Neu';
      case 'like-new': return 'Wie neu';
      case 'good': return 'Gut gepflegt';
      case 'acceptable': return 'Gebrauchsspuren';
      case 'used': return 'Gebraucht';
      default: return code;
    }
  }

  /// Display label for a FiltersOverlay condition code.
  static String filterLabel(String filterCode) {
    switch (filterCode) {
      case 'neu': return 'Neu';
      case 'wie-neu': return 'Wie neu';
      case 'gut': return 'Gut gepflegt';
      case 'akzeptabel': return 'Gebrauchsspuren';
      case 'egal': return 'Alle';
      default: return filterCode;
    }
  }

  /// Map FiltersOverlay code -> internal item.condition code. Returns null for 'egal'.
  static String? internalFromFilter(String filterCode) {
    switch (filterCode) {
      case 'neu': return 'new';
      case 'wie-neu': return 'like-new';
      case 'gut': return 'good';
      case 'akzeptabel': return 'acceptable';
      case 'egal':
      default: return null;
    }
  }
}
