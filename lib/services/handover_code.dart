import 'package:flutter/foundation.dart';

class HandoverQrPayload {
  final String segment;
  final String presenterRole;
  final String code;
  final String bookingId;

  const HandoverQrPayload({
    required this.segment,
    required this.presenterRole,
    required this.code,
    required this.bookingId,
  });
}

/// Centralized handover/return code generation.
///
/// Legacy helper `codeFromTitleAndStart(...)` stays intact for compatibility.
/// New v2 helpers bind manual/QR confirmation to both segment and presenter role.
class HandoverCodeService {
  static const String segmentPickup = 'pickup';
  static const String segmentReturn = 'return';
  static const String presenterOwner = 'owner';
  static const String presenterRenter = 'renter';

  /// Returns a 6-digit code as string (e.g., "203476").
  static String codeFromTitleAndStart({required String title, required DateTime start}) {
    try {
      final seed = (title.hashCode ^ start.hashCode).abs();
      final code = (seed % 900000) + 100000; // 6-digit
      return code.toString();
    } catch (e) {
      debugPrint('[handover] code gen failed: $e');
      final fallback = (title.hashCode.abs() % 900000) + 100000;
      return fallback.toString();
    }
  }

  static String codeForTitleAndStart({
    required String title,
    required DateTime start,
    required String bookingId,
    required String segment,
    required String presenterRole,
  }) {
    try {
      final seed = [title, start.toIso8601String(), bookingId, segment, presenterRole].join('|').hashCode.abs();
      final code = (seed % 900000) + 100000;
      return code.toString();
    } catch (e) {
      debugPrint('[handover] v2 code gen failed: $e');
      final fallbackSeed = [title, bookingId, segment, presenterRole].join('|').hashCode.abs();
      final code = (fallbackSeed % 900000) + 100000;
      return code.toString();
    }
  }

  static String qrPayload({
    required String segment,
    required String presenterRole,
    required String code,
    required String bookingId,
  }) {
    return 'shareittoo:v2:$segment:$presenterRole:$code:$bookingId';
  }

  static HandoverQrPayload? parseQrPayload(String payload) {
    final raw = payload.trim();
    final parts = raw.split(':');
    if (parts.length != 6) return null;
    if (parts[0] != 'shareittoo' || parts[1] != 'v2') return null;
    final segment = parts[2].trim();
    final presenterRole = parts[3].trim();
    final code = parts[4].trim();
    final bookingId = parts[5].trim();
    if (segment.isEmpty || presenterRole.isEmpty || code.isEmpty || bookingId.isEmpty) return null;
    return HandoverQrPayload(
      segment: segment,
      presenterRole: presenterRole,
      code: code,
      bookingId: bookingId,
    );
  }

  static bool isExpectedQrPayload(
    String payload, {
    required String segment,
    required String presenterRole,
    required String code,
    required String bookingId,
  }) {
    final parsed = parseQrPayload(payload);
    if (parsed == null) return false;
    return parsed.segment == segment &&
        parsed.presenterRole == presenterRole &&
        parsed.code == code &&
        parsed.bookingId == bookingId;
  }
}
