import 'package:flutter/foundation.dart';

/// Centralized handover/return code generation.
///
/// We derive a 6-digit numeric code from a stable combination of
/// the listing title and the pickup start time. This ensures both
/// renter and owner see/expect the exact same code across all views
/// (booking detail, owner detail, stepper flows), removing previous
/// inconsistencies.
class HandoverCodeService {
  /// Returns a 6-digit code as string (e.g., "203476").
  static String codeFromTitleAndStart({required String title, required DateTime start}) {
    try {
      final seed = (title.hashCode ^ start.hashCode).abs();
      final code = (seed % 900000) + 100000; // 6-digit
      return code.toString();
    } catch (e) {
      debugPrint('[handover] code gen failed: $e');
      // Fallback: deterministic but simple
      final fallback = (title.hashCode.abs() % 900000) + 100000;
      return fallback.toString();
    }
  }
}
