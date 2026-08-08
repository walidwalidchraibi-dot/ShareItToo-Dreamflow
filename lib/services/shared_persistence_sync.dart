import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'shared_persistence_sync_stub.dart'
    if (dart.library.html) 'shared_persistence_sync_web.dart';

class SharedPersistenceSync {
  static const String rentalRequestsKey = 'rental_requests';
  static const String messageThreadsKey = 'message_threads_v1';
  static const String handoverReturnStateKey = 'handover_return_state_v1';

  static const Set<String> _bookingKeys = {
    rentalRequestsKey,
    messageThreadsKey,
    handoverReturnStateKey,
  };

  static Stream<String> get changes => sharedPersistenceChanges;

  static void notify(String key) {
    if (affectsBookingSync(key)) {
      notifySharedPersistenceChange(key);
    }
  }

  static bool affectsBookingSync(String key) => _bookingKeys.contains(key);

  /// Converts the browser storage key used by shared_preferences_web back to
  /// the logical SharedPreferences key consumed by the app.
  static String? logicalKeyFromStorageKey(String? storageKey) {
    final value = storageKey?.trim() ?? '';
    if (value.isEmpty) return null;
    if (_bookingKeys.contains(value)) return value;

    const prefix = 'flutter.';
    if (!value.startsWith(prefix)) return null;
    final logicalKey = value.substring(prefix.length);
    return _bookingKeys.contains(logicalKey) ? logicalKey : null;
  }

  /// SharedPreferences keeps an in-memory cache. A storage event from another
  /// browser tab must refresh that cache before screens read the new values.
  static Future<void> reloadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }
}

/// Serializes screen refreshes and coalesces events that arrive while a reload
/// is already running. This prevents concurrent setState/load races without
/// dropping the final state.
class SharedPersistenceRefreshCoordinator {
  bool _inFlight = false;
  bool _queued = false;
  bool _disposed = false;

  Future<void> schedule(Future<void> Function() refresh) async {
    if (_disposed) return;
    if (_inFlight) {
      _queued = true;
      return;
    }

    _inFlight = true;
    try {
      do {
        _queued = false;
        await refresh();
      } while (!_disposed && _queued);
    } finally {
      _inFlight = false;
    }
  }

  void dispose() {
    _disposed = true;
    _queued = false;
  }
}
