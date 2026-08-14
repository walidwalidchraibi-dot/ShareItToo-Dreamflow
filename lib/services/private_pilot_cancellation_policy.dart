import 'package:lendify/config/private_pilot_config.dart';

enum PrivatePilotCancellationActor { renter, owner }

class PrivatePilotCancellationOutcome {
  final int refundBasisPoints;
  final DateTime? freeCancellationUntil;
  final String reasonCode;

  const PrivatePilotCancellationOutcome({
    required this.refundBasisPoints,
    required this.freeCancellationUntil,
    required this.reasonCode,
  });

  bool get isFullRefund => refundBasisPoints == 10000;

  int refundMinor(int paidMinor) =>
      ((paidMinor * refundBasisPoints) + 5000) ~/ 10000;

  int retainedMinor(int paidMinor) => paidMinor - refundMinor(paidMinor);
}

class PrivatePilotCancellationPolicy {
  PrivatePilotCancellationPolicy._();

  static DateTime? shortNoticeGraceDeadline({
    required DateTime contractConfirmedAt,
    required DateTime rentalStartAt,
  }) {
    if (!rentalStartAt.isAfter(contractConfirmedAt)) return null;
    if (rentalStartAt.difference(contractConfirmedAt) >=
        const Duration(
          hours: PrivatePilotConfig.shortNoticeThresholdHours,
        )) {
      return null;
    }
    final candidate = contractConfirmedAt.add(
      const Duration(minutes: PrivatePilotConfig.shortNoticeGraceMinutes),
    );
    return candidate.isBefore(rentalStartAt) ? candidate : rentalStartAt;
  }

  static PrivatePilotCancellationOutcome evaluate({
    required DateTime rentalStartAt,
    required DateTime cancelAt,
    required PrivatePilotCancellationActor actor,
    DateTime? contractConfirmedAt,
    bool noShow = false,
  }) {
    if (actor == PrivatePilotCancellationActor.owner) {
      return const PrivatePilotCancellationOutcome(
        refundBasisPoints: 10000,
        freeCancellationUntil: null,
        reasonCode: 'owner_cancellation_full_refund',
      );
    }

    if (noShow || !cancelAt.isBefore(rentalStartAt)) {
      return const PrivatePilotCancellationOutcome(
        refundBasisPoints: 0,
        freeCancellationUntil: null,
        reasonCode: 'renter_no_show_or_after_start',
      );
    }

    final graceDeadline = contractConfirmedAt == null
        ? null
        : shortNoticeGraceDeadline(
            contractConfirmedAt: contractConfirmedAt,
            rentalStartAt: rentalStartAt,
          );
    if (graceDeadline != null && !cancelAt.isAfter(graceDeadline)) {
      return PrivatePilotCancellationOutcome(
        refundBasisPoints: 10000,
        freeCancellationUntil: graceDeadline,
        reasonCode: 'short_notice_grace_full_refund',
      );
    }

    if (rentalStartAt.difference(cancelAt) >=
        const Duration(
          hours: PrivatePilotConfig.shortNoticeThresholdHours,
        )) {
      return const PrivatePilotCancellationOutcome(
        refundBasisPoints: 10000,
        freeCancellationUntil: null,
        reasonCode: 'at_least_24_hours_full_refund',
      );
    }

    return const PrivatePilotCancellationOutcome(
      refundBasisPoints:
          10000 - PrivatePilotConfig.shortNoticeRemainingBasisPoints,
      freeCancellationUntil: null,
      reasonCode: 'less_than_24_hours_partial_refund',
    );
  }
}
