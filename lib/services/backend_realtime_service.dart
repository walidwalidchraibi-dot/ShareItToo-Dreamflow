import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'backend_config.dart';
import 'shared_persistence_sync.dart';

class BackendRealtimeService {
  static WebSocketChannel? _channel;
  static StreamSubscription<dynamic>? _subscription;
  static StreamSubscription<List<ConnectivityResult>>?
      _connectivitySubscription;
  static Timer? _reconnectTimer;
  static String? _accessToken;
  static bool _stopped = true;
  static bool _networkUnavailable = false;

  @visibleForTesting
  static bool hasUsableConnectivity(Iterable<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  static Future<void> connect(String accessToken) async {
    if (!BackendConfig.enabled || accessToken.trim().isEmpty) return;
    if (_channel != null && _accessToken == accessToken && !_stopped) return;
    await disconnect();
    _stopped = false;
    _accessToken = accessToken;
    await _startConnectivityMonitoring();
    if (!_networkUnavailable) unawaited(_open());
  }

  static Future<void> _startConnectivityMonitoring() async {
    final connectivity = Connectivity();
    try {
      _networkUnavailable = !hasUsableConnectivity(
        await connectivity.checkConnectivity(),
      );
    } catch (error) {
      // Connectivity type is only a recovery signal. Socket errors remain the
      // authoritative fallback and must continue to be handled normally.
      debugPrint('[BackendRealtime] connectivity check unavailable: $error');
      _networkUnavailable = false;
    }
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      (results) => unawaited(_handleConnectivityChanged(results)),
      onError: (Object error) {
        debugPrint(
            '[BackendRealtime] connectivity monitor unavailable: $error');
      },
    );
  }

  static Future<void> _handleConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    if (_stopped) return;
    final unavailable = !hasUsableConnectivity(results);
    if (unavailable) {
      _networkUnavailable = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      await _closeCurrentChannel();
      return;
    }
    final recovered = _networkUnavailable;
    _networkUnavailable = false;
    if (!recovered) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeCurrentChannel();
    if (!_stopped) unawaited(_open());
  }

  static Future<void> _closeCurrentChannel() async {
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    try {
      await subscription?.cancel();
    } catch (_) {
      // The network may have disappeared before cancellation completed.
    }
    try {
      await channel?.sink.close();
    } catch (_) {
      // Closing an already-broken socket is best effort only.
    }
  }

  static Future<void> _open() async {
    if (_stopped || _networkUnavailable || _accessToken == null) return;
    final accessToken = _accessToken;
    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(BackendConfig.realtimeUri);
      _channel = channel;
      await channel.ready;
      if (_stopped || _accessToken != accessToken || _channel != channel) {
        await channel.sink.close();
        return;
      }
      channel.sink.add(jsonEncode({'type': 'auth', 'token': accessToken}));
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (Object error) {
          debugPrint('[BackendRealtime] connection error: $error');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('[BackendRealtime] connect failed: $error');
      if (_channel == channel) _channel = null;
      if (channel != null) {
        try {
          await channel.sink.close();
        } catch (_) {
          // The connection may have failed before a close frame was possible.
        }
      }
      _scheduleReconnect();
    }
  }

  static Future<void> _handleMessage(dynamic raw) async {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map || decoded['type'] != 'changed') return;
      final resource = decoded['resource']?.toString();
      final prefs = await SharedPreferences.getInstance();
      switch (resource) {
        case 'listings':
          await prefs.remove('items');
          break;
        case 'rental_requests':
          await prefs.remove(SharedPersistenceSync.rentalRequestsKey);
          SharedPersistenceSync.notify(
            SharedPersistenceSync.rentalRequestsKey,
          );
          break;
        case 'message_threads':
          await prefs.remove(SharedPersistenceSync.messageThreadsKey);
          SharedPersistenceSync.notify(
            SharedPersistenceSync.messageThreadsKey,
          );
          break;
        case 'profiles':
          await prefs.remove('currentUser');
          break;
      }
    } catch (error) {
      debugPrint('[BackendRealtime] invalid event: $error');
    }
  }

  static void _scheduleReconnect() {
    _subscription = null;
    _channel = null;
    if (_stopped || _networkUnavailable || _reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      unawaited(_open());
    });
  }

  static Future<void> disconnect() async {
    _stopped = true;
    _networkUnavailable = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _closeCurrentChannel();
    _accessToken = null;
  }
}
