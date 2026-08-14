import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'backend_config.dart';
import 'backend_repository.dart';
import 'release_identity.dart';
import 'shared_persistence_sync.dart';

bool controlledCrashDiagnosticAllowed({
  required bool releaseMode,
  required bool enabled,
  required String apiBaseUrl,
  required String releaseChannel,
  required String configuredRunId,
  required String requestedRunId,
}) {
  return releaseMode &&
      enabled &&
      apiBaseUrl == 'https://staging.shareittoo.com/api/v1' &&
      releaseChannel == 'internal' &&
      configuredRunId == requestedRunId &&
      RegExp(r'^b11-[a-z0-9-]{6,64}$').hasMatch(configuredRunId);
}

@visibleForTesting
String controlledCrashDiagnosticAttemptKey({
  required String buildNumber,
  required String runId,
}) =>
    'sit_controlled_crash_diagnostic_attempted_${buildNumber}_$runId';

@visibleForTesting
bool controlledCrashDiagnosticCanStart({
  required bool allowed,
  required bool alreadyAttempted,
  required bool inFlight,
}) =>
    allowed && !alreadyAttempted && !inFlight;

@visibleForTesting
bool shouldRecordUnhandledErrorAsFatal(Object error) {
  return error is! WebSocketChannelException;
}

class FirebaseRuntimeConfig {
  static const String projectId = String.fromEnvironment(
    'SIT_FIREBASE_PROJECT_ID',
  );
  static const String messagingSenderId = String.fromEnvironment(
    'SIT_FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String storageBucket = String.fromEnvironment(
    'SIT_FIREBASE_STORAGE_BUCKET',
  );
  static const String androidAppId = String.fromEnvironment(
    'SIT_FIREBASE_ANDROID_APP_ID',
  );
  static const String androidApiKey = String.fromEnvironment(
    'SIT_FIREBASE_ANDROID_API_KEY',
  );
  static const String iosAppId = String.fromEnvironment(
    'SIT_FIREBASE_IOS_APP_ID',
  );
  static const String iosApiKey = String.fromEnvironment(
    'SIT_FIREBASE_IOS_API_KEY',
  );

  static bool hasCompleteValues({
    required String project,
    required String sender,
    required String appId,
    required String apiKey,
  }) {
    return project.trim().isNotEmpty &&
        sender.trim().isNotEmpty &&
        appId.trim().isNotEmpty &&
        apiKey.trim().isNotEmpty;
  }

  static FirebaseOptions? get currentOptions {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (!hasCompleteValues(
          project: projectId,
          sender: messagingSenderId,
          appId: androidAppId,
          apiKey: androidApiKey,
        )) {
          return null;
        }
        return FirebaseOptions(
          apiKey: androidApiKey,
          appId: androidAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket.isEmpty ? null : storageBucket,
        );
      case TargetPlatform.iOS:
        if (!hasCompleteValues(
          project: projectId,
          sender: messagingSenderId,
          appId: iosAppId,
          apiKey: iosApiKey,
        )) {
          return null;
        }
        return FirebaseOptions(
          apiKey: iosApiKey,
          appId: iosAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket.isEmpty ? null : storageBucket,
          iosBundleId: 'com.shareittoo.app',
        );
      default:
        return null;
    }
  }
}

class ForegroundPushMessage {
  final String title;
  final String body;
  final Uri? actionUri;

  const ForegroundPushMessage({
    required this.title,
    required this.body,
    this.actionUri,
  });
}

@visibleForTesting
Uri? parsePushActionUri(Object? rawValue) {
  final raw = rawValue?.toString().trim() ?? '';
  final parsed = raw.isEmpty ? null : Uri.tryParse(raw);
  const supportedSchemes = {'https', 'http', 'shareittoo'};
  return parsed != null &&
          parsed.scheme.isNotEmpty &&
          supportedSchemes.contains(parsed.scheme.toLowerCase()) &&
          parsed.userInfo.isEmpty
      ? parsed
      : null;
}

@visibleForTesting
ForegroundPushMessage? parseForegroundPushMessage({
  String? title,
  String? body,
  Map<String, dynamic> data = const {},
}) {
  final safeTitle = title?.trim() ?? '';
  final safeBody = body?.trim() ?? '';
  if (safeTitle.isEmpty && safeBody.isEmpty) return null;

  final actionUri = parsePushActionUri(data['actionUrl']);
  return ForegroundPushMessage(
    title: safeTitle.isEmpty ? 'ShareItToo' : safeTitle,
    body: safeBody,
    actionUri: actionUri,
  );
}

@visibleForTesting
Set<String> sharedPersistenceKeysForForegroundPush(
  Map<String, dynamic> data,
) {
  final entityType = data['entityType']?.toString().trim().toLowerCase();
  if (entityType == 'thread') {
    return {SharedPersistenceSync.messageThreadsKey};
  }
  if (entityType == 'booking') {
    return {
      SharedPersistenceSync.rentalRequestsKey,
      SharedPersistenceSync.messageThreadsKey,
    };
  }
  return const {};
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseRuntime.ensureFirebaseApp();
}

@visibleForTesting
Future<String?> waitForApplePushToken({
  required Future<String?> Function() readToken,
  Future<void> Function(Duration) delay = Future<void>.delayed,
  int maxAttempts = 20,
  Duration retryDelay = const Duration(milliseconds: 250),
}) async {
  assert(maxAttempts > 0);
  for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
    final token = (await readToken())?.trim();
    if (token != null && token.isNotEmpty) return token;
    if (attempt + 1 < maxAttempts) await delay(retryDelay);
  }
  return null;
}

class FirebaseRuntime {
  static const MethodChannel _androidActionLinkChannel = MethodChannel(
    'com.shareittoo.app/push_action_links',
  );
  static const bool _controlledCrashDiagnosticEnabled = bool.fromEnvironment(
    'SIT_ENABLE_STAGING_CRASH_DIAGNOSTIC',
    defaultValue: false,
  );
  static const String _controlledCrashDiagnosticRunId = String.fromEnvironment(
    'SIT_STAGING_CRASH_DIAGNOSTIC_RUN_ID',
  );
  static final StreamController<Uri> _actionLinks =
      StreamController<Uri>.broadcast(sync: true);
  static final StreamController<ForegroundPushMessage> _foregroundMessages =
      StreamController<ForegroundPushMessage>.broadcast(sync: true);
  static Future<bool>? _initialization;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  static bool _initialized = false;
  static bool _nativeActionLinkChannelInitialized = false;
  static final Set<String> _controlledCrashDiagnosticsInFlight = <String>{};
  static Uri? _pendingActionLink;
  static String _locale = 'de-DE';

  static Stream<Uri> get actionLinks => _actionLinks.stream;
  static Stream<ForegroundPushMessage> get foregroundMessages =>
      _foregroundMessages.stream;
  static bool get isInitialized => _initialized;

  static Future<bool> initialize() {
    return _initialization ??= _initialize();
  }

  static Future<void> ensureFirebaseApp() async {
    final options = FirebaseRuntimeConfig.currentOptions;
    if (options == null || Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(options: options);
  }

  static Future<bool> _initialize() async {
    await _initializeNativeActionLinks();
    final options = FirebaseRuntimeConfig.currentOptions;
    if (options == null) return false;
    try {
      await ensureFirebaseApp();
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(kReleaseMode);
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _openedMessageSubscription ??=
          FirebaseMessaging.onMessageOpenedApp.listen(_captureActionLink);
      _foregroundMessageSubscription ??=
          FirebaseMessaging.onMessage.listen(_captureForegroundMessage);
      _captureActionLink(await FirebaseMessaging.instance.getInitialMessage());
      _initialized = true;
      return true;
    } catch (error, stack) {
      debugPrint('[FirebaseRuntime] initialization unavailable: $error');
      debugPrint(stack.toString());
      return false;
    }
  }

  static void recordFlutterFatalError(FlutterErrorDetails details) {
    if (!_initialized || !kReleaseMode) return;
    unawaited(
      FirebaseCrashlytics.instance.recordFlutterFatalError(details),
    );
  }

  static void recordUnhandledError(Object error, StackTrace stack) {
    if (!_initialized || !kReleaseMode) return;
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: shouldRecordUnhandledErrorAsFatal(error),
        reason: error is WebSocketChannelException
            ? 'Transient realtime connectivity failure'
            : 'Unhandled asynchronous application error',
      ),
    );
  }

  static Future<bool> recordControlledStagingCrashDiagnostic(
    String requestedRunId,
  ) async {
    final allowed = _initialized &&
        controlledCrashDiagnosticAllowed(
          releaseMode: kReleaseMode,
          enabled: _controlledCrashDiagnosticEnabled,
          apiBaseUrl: BackendConfig.apiBaseUrl,
          releaseChannel: ReleaseIdentity.releaseChannel,
          configuredRunId: _controlledCrashDiagnosticRunId,
          requestedRunId: requestedRunId,
        );
    final attemptKey = controlledCrashDiagnosticAttemptKey(
      buildNumber: ReleaseIdentity.buildNumber,
      runId: requestedRunId,
    );
    if (!controlledCrashDiagnosticCanStart(
      allowed: allowed,
      alreadyAttempted: false,
      inFlight: _controlledCrashDiagnosticsInFlight.contains(attemptKey),
    )) {
      return false;
    }
    _controlledCrashDiagnosticsInFlight.add(attemptKey);
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!controlledCrashDiagnosticCanStart(
        allowed: allowed,
        alreadyAttempted: preferences.getBool(attemptKey) == true,
        inFlight: false,
      )) {
        return false;
      }

      // Reserve the run before talking to Crashlytics. This deliberately
      // prefers a missed diagnostic over emitting the same internal event
      // twice after a retry, relaunch, or duplicate app link.
      if (!await preferences.setBool(attemptKey, true)) return false;

      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCustomKey(
        'sit_release_commit',
        ReleaseIdentity.appCommit,
      );
      await crashlytics.setCustomKey(
        'sit_build_number',
        ReleaseIdentity.buildNumber,
      );
      await crashlytics.setCustomKey(
        'sit_release_channel',
        ReleaseIdentity.releaseChannel,
      );
      await crashlytics.setCustomKey(
        'sit_diagnostic_run_id',
        requestedRunId,
      );
      await crashlytics.recordError(
        StateError('SIT_B11_CONTROLLED_CRASH_DIAGNOSTIC'),
        StackTrace.current,
        reason: 'Sanitized internal release-mapping diagnostic',
        fatal: false,
      );
      await crashlytics.sendUnsentReports();
      await crashlytics.setCustomKey('sit_diagnostic_run_id', '');
      return true;
    } catch (_) {
      debugPrint('[FirebaseRuntime] controlled crash diagnostic unavailable');
      return false;
    } finally {
      _controlledCrashDiagnosticsInFlight.remove(attemptKey);
    }
  }

  static Future<bool> syncPushRegistration() async {
    if (!_initialized || !BackendConfig.enabled) return false;
    final platform = _platformName();
    if (platform == null) return false;
    try {
      _locale = PlatformDispatcher.instance.locale.toLanguageTag();
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      if (!const {
        AuthorizationStatus.authorized,
        AuthorizationStatus.provisional,
      }.contains(settings.authorizationStatus)) {
        return false;
      }
      if (platform == 'ios') {
        final apnsToken = await waitForApplePushToken(
          readToken: FirebaseMessaging.instance.getAPNSToken,
        );
        if (apnsToken == null) {
          debugPrint('[FirebaseRuntime] APNs token is not available.');
          return false;
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return false;
      await _registerToken(token, platform);
      _tokenRefreshSubscription ??=
          FirebaseMessaging.instance.onTokenRefresh.listen(
        (refreshedToken) {
          unawaited(_registerToken(refreshedToken, platform));
        },
        onError: (Object error, StackTrace stack) {
          debugPrint('[FirebaseRuntime] token refresh unavailable: $error');
        },
      );
      return true;
    } catch (error) {
      debugPrint('[FirebaseRuntime] push registration unavailable: $error');
      return false;
    }
  }

  static Future<void> _registerToken(String token, String platform) async {
    try {
      await BackendRepository.registerPushDevice(
        token: token,
        platform: platform,
        locale: _locale,
      );
    } catch (error) {
      debugPrint('[FirebaseRuntime] push token sync unavailable: $error');
    }
  }

  static String? _platformName() {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  static Future<void> _initializeNativeActionLinks() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _nativeActionLinkChannelInitialized) {
      return;
    }
    _nativeActionLinkChannelInitialized = true;
    try {
      _androidActionLinkChannel.setMethodCallHandler((call) async {
        if (call.method == 'pushActionLink') {
          _captureRawActionLink(call.arguments);
        }
      });
      final initial = await takeAndroidPendingActionLink();
      _captureRawActionLink(initial);
    } on MissingPluginException {
      debugPrint('[FirebaseRuntime] native action-link bridge unavailable');
    } on PlatformException catch (error) {
      debugPrint(
        '[FirebaseRuntime] native action-link bridge unavailable: ${error.code}',
      );
    }
  }

  static Future<Uri?> takeAndroidPendingActionLink() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final raw = await _androidActionLinkChannel.invokeMethod<String>(
        'takeInitialActionLink',
      );
      return parsePushActionUri(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static void _captureActionLink(RemoteMessage? message) {
    _captureRawActionLink(message?.data['actionUrl']);
  }

  static void _captureRawActionLink(Object? raw) {
    final uri = parsePushActionUri(raw);
    if (uri == null) return;
    _pendingActionLink = uri;
    _actionLinks.add(uri);
  }

  static void _captureForegroundMessage(RemoteMessage message) {
    for (final key in sharedPersistenceKeysForForegroundPush(message.data)) {
      SharedPersistenceSync.notifyWithCatchUpRetry(key);
    }
    final notification = message.notification;
    final foreground = parseForegroundPushMessage(
      title: notification?.title,
      body: notification?.body,
      data: message.data,
    );
    if (foreground != null) _foregroundMessages.add(foreground);
  }

  static void openForegroundMessage(ForegroundPushMessage message) {
    final actionUri = message.actionUri;
    if (actionUri == null) return;
    _captureRawActionLink(actionUri);
  }

  static Uri? takePendingActionLink() {
    final pending = _pendingActionLink;
    _pendingActionLink = null;
    return pending;
  }
}
