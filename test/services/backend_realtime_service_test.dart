import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/backend_realtime_service.dart';

void main() {
  group('BackendRealtimeService connectivity recovery', () {
    test('treats every no-network signal as unavailable', () {
      expect(
        BackendRealtimeService.hasUsableConnectivity(
          const [ConnectivityResult.none],
        ),
        isFalse,
      );
      expect(
        BackendRealtimeService.hasUsableConnectivity(const []),
        isFalse,
      );
    });

    test('accepts any concrete transport as a reconnect signal', () {
      expect(
        BackendRealtimeService.hasUsableConnectivity(
          const [ConnectivityResult.wifi],
        ),
        isTrue,
      );
      expect(
        BackendRealtimeService.hasUsableConnectivity(
          const [ConnectivityResult.mobile, ConnectivityResult.vpn],
        ),
        isTrue,
      );
    });
  });
}
