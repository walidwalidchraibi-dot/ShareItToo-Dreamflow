import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/private_pilot_return_policy.dart';

void main() {
  final t0 = DateTime.utc(2026, 8, 20, 12);

  test('missing confirmation stays neutral and does not become a case', () {
    final timeline = PrivatePilotReturnPolicy.evaluate(
      scheduledReturnAt: t0,
      ownerConfirmed: true,
      renterConfirmed: false,
      now: t0.add(const Duration(days: 3)),
    );
    expect(
      timeline.state,
      PrivatePilotReturnState.awaitingReturnConfirmation,
    );
    expect(timeline.caseOpenedAt, isNull);
    expect(timeline.clarificationDeadline, t0.add(const Duration(days: 5)));
  });

  test('both confirmations open the 48 hour report window', () {
    final timeline = PrivatePilotReturnPolicy.evaluate(
      scheduledReturnAt: t0,
      ownerConfirmed: true,
      renterConfirmed: true,
      now: t0.add(const Duration(hours: 12)),
    );
    expect(timeline.state, PrivatePilotReturnState.reportWindowOpen);
    expect(timeline.reportDeadline, t0.add(const Duration(hours: 48)));
  });

  test('substantiated case is the only input that creates needsReview', () {
    final openedAt = t0.add(const Duration(hours: 2));
    final timeline = PrivatePilotReturnPolicy.evaluate(
      scheduledReturnAt: t0,
      ownerConfirmed: false,
      renterConfirmed: false,
      substantiatedCaseOpenedAt: openedAt,
    );
    expect(timeline.state, PrivatePilotReturnState.needsReview);
    expect(timeline.responseDueAt, openedAt.add(const Duration(days: 5)));
  });

  test('damage is recorded only and never creates an extra charge', () {
    final split = PrivatePilotReturnPolicy.splitAuthorizedAmount(
      authorizedBookingMinor: 11000,
      contestedAuthorizedMinor: 3300,
      allegedDamageMinor: 50000,
    );
    expect(split.undisputedReleasableMinor, 7700);
    expect(split.allegedDamageMinorRecordedOnly, 50000);
    expect(split.additionalChargeMinor, 0);
  });
}
