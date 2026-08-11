import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'backend_config.dart';
import 'firebase_runtime.dart';

enum AppLinkKind {
  listing,
  profile,
  booking,
  chat,
  emailVerification,
  passwordReset,
  paymentReturn,
  crashDiagnostic,
}

class AppLinkTarget {
  final AppLinkKind kind;
  final String? id;
  final Uri uri;

  const AppLinkTarget({required this.kind, required this.uri, this.id});
}

class AppLinkTargetInbox {
  static const duplicateWindow = Duration(seconds: 5);

  final DateTime Function() _now;
  AppLinkTarget? _pending;
  Uri? _lastAcceptedUri;
  DateTime? _lastAcceptedAt;

  AppLinkTargetInbox({DateTime Function()? now}) : _now = now ?? DateTime.now;

  AppLinkTarget? takePending() {
    final target = _pending;
    _pending = null;
    return target;
  }

  bool accept(String raw) {
    if (raw.isEmpty || raw == '/') return false;
    final uri = Uri.tryParse(raw);
    final target = uri == null ? null : AppLinkParser.parse(uri);
    if (target == null) return false;

    final acceptedAt = _now();
    final previousAt = _lastAcceptedAt;
    if (_lastAcceptedUri == uri &&
        previousAt != null &&
        acceptedAt.difference(previousAt) <= duplicateWindow) {
      return false;
    }

    _pending = target;
    _lastAcceptedUri = uri;
    _lastAcceptedAt = acceptedAt;
    return true;
  }
}

class AppLinkBuilder {
  static Uri listing(String itemId) => _publicTarget('listing', itemId);

  static Uri profile(String userId) => _publicTarget('profile', userId);

  static Uri _publicTarget(String kind, String id) {
    final value = id.trim();
    if (value.isEmpty ||
        value.length > 120 ||
        !RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(value)) {
      throw ArgumentError.value(id, 'id', 'Ungültige ShareItToo-ID');
    }
    return BackendConfig.uri('/open/$kind/${Uri.encodeComponent(value)}');
  }
}

class AppLinkParser {
  static const _allowedWebHosts = <String>{
    'shareittoo.com',
    'www.shareittoo.com',
    'staging.shareittoo.com',
  };

  static AppLinkTarget? parse(Uri uri) {
    if (uri.userInfo.isNotEmpty) return null;
    final isCustom = uri.scheme.toLowerCase() == 'shareittoo';
    final isWeb = (uri.scheme == 'https' || uri.scheme == 'http') &&
        _allowedWebHosts.contains(uri.host.toLowerCase());
    if (!isCustom && !isWeb) return null;

    final segments = <String>[
      if (isCustom && uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ].where((segment) => segment.isNotEmpty).toList();
    while (segments.isNotEmpty &&
        const {'api', 'v1', 'open'}.contains(segments.first.toLowerCase())) {
      segments.removeAt(0);
    }
    if (segments.isEmpty) return null;

    String? safeId(int index) {
      if (segments.length <= index) return null;
      final value = segments[index].trim();
      return value.isNotEmpty &&
              value.length <= 120 &&
              RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(value)
          ? value
          : null;
    }

    switch (segments.first.toLowerCase()) {
      case 'listing':
        final id = safeId(1);
        return id == null
            ? null
            : AppLinkTarget(kind: AppLinkKind.listing, id: id, uri: uri);
      case 'profile':
        final id = safeId(1);
        return id == null
            ? null
            : AppLinkTarget(kind: AppLinkKind.profile, id: id, uri: uri);
      case 'booking':
        final id = safeId(1);
        return id == null
            ? null
            : AppLinkTarget(kind: AppLinkKind.booking, id: id, uri: uri);
      case 'chat':
        final id = safeId(1);
        return id == null
            ? null
            : AppLinkTarget(kind: AppLinkKind.chat, id: id, uri: uri);
      case 'auth':
        if (segments.length >= 3 &&
            segments[1] == 'email-verification' &&
            segments[2] == 'confirm' &&
            (uri.queryParameters['token'] ?? '').isNotEmpty) {
          return AppLinkTarget(
            kind: AppLinkKind.emailVerification,
            uri: uri,
          );
        }
        if (segments.length >= 2 &&
            segments[1] == 'password-reset' &&
            (uri.queryParameters['token'] ?? '').isNotEmpty) {
          return AppLinkTarget(kind: AppLinkKind.passwordReset, uri: uri);
        }
        return null;
      case 'payment':
        final id = segments.length >= 2 && segments[1] == 'return'
            ? safeId(2)
            : safeId(1);
        return id == null
            ? null
            : AppLinkTarget(
                kind: AppLinkKind.paymentReturn,
                id: id,
                uri: uri,
              );
      case 'qa':
        if (!isCustom ||
            segments.length != 3 ||
            segments[1].toLowerCase() != 'crashlytics') {
          return null;
        }
        final id = safeId(2);
        return id == null
            ? null
            : AppLinkTarget(
                kind: AppLinkKind.crashDiagnostic,
                id: id,
                uri: uri,
              );
      default:
        return null;
    }
  }
}

class AppLinkController extends ChangeNotifier with WidgetsBindingObserver {
  final AppLinkTargetInbox _inbox;
  final Future<Uri?> Function() _takeNativePendingActionLink;
  bool _initialized = false;
  StreamSubscription<Uri>? _firebaseActionSubscription;

  AppLinkController({
    AppLinkTargetInbox? inbox,
    Future<Uri?> Function()? takeNativePendingActionLink,
  })  : _inbox = inbox ?? AppLinkTargetInbox(),
        _takeNativePendingActionLink = takeNativePendingActionLink ??
            FirebaseRuntime.takeAndroidPendingActionLink;

  AppLinkTarget? takePending() => _inbox.takePending();

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    final raw = kIsWeb
        ? Uri.base.toString()
        : WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    _accept(raw);
    final firebasePending = FirebaseRuntime.takePendingActionLink();
    if (firebasePending != null) _accept(firebasePending.toString());
    _firebaseActionSubscription ??= FirebaseRuntime.actionLinks.listen(
      (uri) => _accept(uri.toString()),
    );
  }

  @override
  Future<bool> didPushRouteInformation(
      RouteInformation routeInformation) async {
    _accept(routeInformation.uri.toString());
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshNativePendingActionLink());
    }
  }

  Future<void> _refreshNativePendingActionLink() async {
    final uri = await _takeNativePendingActionLink();
    if (uri != null) _accept(uri.toString());
  }

  void _accept(String raw) {
    if (_inbox.accept(raw)) notifyListeners();
  }

  @override
  void dispose() {
    _firebaseActionSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
