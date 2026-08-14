import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/screens/message_thread_screen.dart';

void main() {
  final now = DateTime.utc(2026, 8, 14, 12);

  test('active booking chat remains open', () {
    expect(
      isPrivatePilotBookingChatOpen(
        bookingStatus: 'running',
        returnState: 'not_started',
        now: now,
      ),
      isTrue,
    );
  });

  test('completed booking chat stays open during report window', () {
    expect(
      isPrivatePilotBookingChatOpen(
        bookingStatus: 'completed',
        returnState: 'reportWindowOpen',
        reportDeadline: now.add(const Duration(hours: 1)),
        now: now,
      ),
      isTrue,
    );
    expect(
      isPrivatePilotBookingChatOpen(
        bookingStatus: 'completed',
        returnState: 'reportWindowOpen',
        reportDeadline: now.subtract(const Duration(seconds: 1)),
        now: now,
      ),
      isFalse,
    );
  });

  test('substantiated case keeps chat open only until case closure', () {
    expect(
      isPrivatePilotBookingChatOpen(
        bookingStatus: 'completed',
        returnState: 'needsReview',
        now: now,
      ),
      isTrue,
    );
    expect(
      isPrivatePilotBookingChatOpen(
        bookingStatus: 'completed',
        returnState: 'needsReview',
        caseClosedAt: now,
        now: now,
      ),
      isFalse,
    );
  });

  test('declined and cancelled bookings do not open chat', () {
    for (final status in ['declined', 'cancelled']) {
      expect(
        isPrivatePilotBookingChatOpen(
          bookingStatus: status,
          returnState: 'needsReview',
          now: now,
        ),
        isFalse,
      );
    }
  });
}
