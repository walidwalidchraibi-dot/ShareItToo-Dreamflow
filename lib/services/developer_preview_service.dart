import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeveloperUserState { firstLaunch, loggedOut, loggedIn, verifiedUser }

class DeveloperPreviewController extends ChangeNotifier {
  static const String _prefsKey = 'dev_preview_user_state_v1';

  DeveloperUserState _state;
  bool _hydrated = false;

  /// True once the controller has loaded persisted state (or decided none exists).
  bool get hydrated => _hydrated;
  DeveloperUserState get state => _state;

  bool get isGuest => _state == DeveloperUserState.loggedOut || _state == DeveloperUserState.firstLaunch;
  bool get isVerified => _state == DeveloperUserState.verifiedUser;

  DeveloperPreviewController({DeveloperUserState? initialState}) : _state = initialState ?? DeveloperUserState.firstLaunch;

  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      final parsed = _parse(raw);
      if (parsed != null) _state = parsed;
    } catch (e) {
      debugPrint('[DeveloperPreview] loadFromPrefs failed: $e');
    } finally {
      _hydrated = true;
    }
    notifyListeners();
  }

  Future<void> setState(DeveloperUserState next) async {
    _state = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, next.name);
    } catch (e) {
      debugPrint('[DeveloperPreview] setState persist failed: $e');
    }
  }

  /// Developer utility: clears local storage (SharedPreferences) and switches
  /// the app back into a "fresh install" experience.
  ///
  /// Useful on Web when local storage quota is exceeded.
  Future<void> resetLocalStorageToFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _state = DeveloperUserState.firstLaunch;
      notifyListeners();
      // Best effort: persist the new state (may still fail if quota issues persist)
      await prefs.setString(_prefsKey, _state.name);
    } catch (e) {
      debugPrint('[DeveloperPreview] resetLocalStorageToFirstLaunch failed: $e');
      _state = DeveloperUserState.firstLaunch;
      notifyListeners();
    }
  }

  static DeveloperUserState? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final v in DeveloperUserState.values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  static Future<DeveloperUserState?> readStateOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _parse(prefs.getString(_prefsKey));
    } catch (e) {
      debugPrint('[DeveloperPreview] readStateOnce failed: $e');
      return null;
    }
  }
}
