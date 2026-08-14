import 'package:lendify/config/private_pilot_config.dart';

enum PrivatePilotReturnState {
  notStarted,
  awaitingReturnConfirmation,
  reportWindowOpen,
  needsReview,
  payoutEligible,
}

extension PrivatePilotReturnStateStorage on PrivatePilotReturnState {
  String get storageValue => switch (this) {
        PrivatePilotReturnState.notStarted => 'not_started',
        PrivatePilotReturnState.awaitingReturnConfirmation =>
          'awaitingReturnConfirmation',
        PrivatePilotReturnState.reportWindowOpen => 'reportWindowOpen',
        PrivatePilotReturnState.needsReview => 'needsReview',
        PrivatePilotReturnState.payoutEligible => 'payoutEligible',
      };
}

class PrivatePilotReturnTimeline {
  final PrivatePilotReturnState state;
  final DateTime t0;
  final DateTime reportDeadline;
  final DateTime clarificationDeadline;
  final DateTime? caseOpenedAt;
  final DateTime? responseDueAt;
  final DateTime? nextStatusUpdateDueAt;
  final DateTime? payoutInstructionDueAt;

  const PrivatePilotReturnTimeline({
    required this.state,
    required this.t0,
    required this.reportDeadline,
    required this.clarificationDeadline,
    this.caseOpenedAt,
    this.responseDueAt,
    this.nextStatusUpdateDueAt,
    this.payoutInstructionDueAt,
  });
}

class PrivatePilotAmountSplit {
  final int authorizedBookingMinor;
  final int contestedAuthorizedMinor;
  final int undisputedReleasableMinor;
  final int allegedDamageMinorRecordedOnly;

  const PrivatePilotAmountSplit({
    required this.authorizedBookingMinor,
    required this.contestedAuthorizedMinor,
    required this.undisputedReleasableMinor,
    required this.allegedDamageMinorRecordedOnly,
  });

  int get additionalChargeMinor => 0;
}

class PrivatePilotReturnPolicy {
  PrivatePilotReturnPolicy._();

  static DateTime resolveT0({
    required DateTime scheduledReturnAt,
    DateTime? mutuallyConfirmedChangedReturnAt,
    DateTime? mutuallyConfirmedActualReturnAt,
  }) =>
      mutuallyConfirmedActualReturnAt ??
      mutuallyConfirmedChangedReturnAt ??
      scheduledReturnAt;

  static PrivatePilotReturnTimeline evaluate({
    required DateTime scheduledReturnAt,
    DateTime? mutuallyConfirmedChangedReturnAt,
    DateTime? mutuallyConfirmedActualReturnAt,
    bool ownerConfirmed = false,
    bool renterConfirmed = false,
    DateTime? substantiatedCaseOpenedAt,
    DateTime? now,
  }) {
    final t0 = resolveT0(
      scheduledReturnAt: scheduledReturnAt,
      mutuallyConfirmedChangedReturnAt: mutuallyConfirmedChangedReturnAt,
      mutuallyConfirmedActualReturnAt: mutuallyConfirmedActualReturnAt,
    );
    final current = now ?? DateTime.now();
    final reportDeadline = t0.add(
      const Duration(hours: PrivatePilotConfig.returnReportWindowHours),
    );
    final clarificationDeadline = t0.add(
      const Duration(days: PrivatePilotConfig.missingReturnConfirmationDays),
    );

    if (substantiatedCaseOpenedAt != null) {
      return PrivatePilotReturnTimeline(
        state: PrivatePilotReturnState.needsReview,
        t0: t0,
        reportDeadline: reportDeadline,
        clarificationDeadline: clarificationDeadline,
        caseOpenedAt: substantiatedCaseOpenedAt,
        responseDueAt: substantiatedCaseOpenedAt.add(const Duration(days: 5)),
        nextStatusUpdateDueAt:
            substantiatedCaseOpenedAt.add(const Duration(days: 7)),
      );
    }

    final bothConfirmed = ownerConfirmed && renterConfirmed;
    if (!bothConfirmed && current.isBefore(clarificationDeadline)) {
      return PrivatePilotReturnTimeline(
        state: PrivatePilotReturnState.awaitingReturnConfirmation,
        t0: t0,
        reportDeadline: reportDeadline,
        clarificationDeadline: clarificationDeadline,
        payoutInstructionDueAt: clarificationDeadline,
      );
    }
    if (bothConfirmed && current.isBefore(reportDeadline)) {
      return PrivatePilotReturnTimeline(
        state: PrivatePilotReturnState.reportWindowOpen,
        t0: t0,
        reportDeadline: reportDeadline,
        clarificationDeadline: clarificationDeadline,
        payoutInstructionDueAt: reportDeadline,
      );
    }
    return PrivatePilotReturnTimeline(
      state: PrivatePilotReturnState.payoutEligible,
      t0: t0,
      reportDeadline: reportDeadline,
      clarificationDeadline: clarificationDeadline,
      payoutInstructionDueAt:
          bothConfirmed ? reportDeadline : clarificationDeadline,
    );
  }

  static PrivatePilotAmountSplit splitAuthorizedAmount({
    required int authorizedBookingMinor,
    int contestedAuthorizedMinor = 0,
    int allegedDamageMinor = 0,
  }) {
    if (authorizedBookingMinor < 0) {
      throw ArgumentError.value(
        authorizedBookingMinor,
        'authorizedBookingMinor',
      );
    }
    final contested =
        contestedAuthorizedMinor.clamp(0, authorizedBookingMinor).toInt();
    return PrivatePilotAmountSplit(
      authorizedBookingMinor: authorizedBookingMinor,
      contestedAuthorizedMinor: contested,
      undisputedReleasableMinor: authorizedBookingMinor - contested,
      allegedDamageMinorRecordedOnly:
          allegedDamageMinor < 0 ? 0 : allegedDamageMinor,
    );
  }

  static bool isChatOpen({
    required bool bookingActive,
    required PrivatePilotReturnState returnState,
    DateTime? now,
    DateTime? reportDeadline,
    DateTime? clarificationDeadline,
    DateTime? caseClosedAt,
  }) {
    if (bookingActive) return true;
    if (returnState == PrivatePilotReturnState.needsReview) {
      return caseClosedAt == null;
    }
    final current = now ?? DateTime.now();
    final deadline =
        returnState == PrivatePilotReturnState.awaitingReturnConfirmation
            ? clarificationDeadline
            : reportDeadline;
    return deadline != null && !current.isAfter(deadline);
  }
}
