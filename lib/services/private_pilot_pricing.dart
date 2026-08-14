import 'package:lendify/config/private_pilot_config.dart';
import 'package:lendify/models/item.dart';

class PrivatePilotQuote {
  final int days;
  final int ownerPricePerDayMinor;
  final int baseRentalMinor;
  final int discountBasisPoints;
  final int discountMinor;
  final int rentalSubtotalMinor;
  final int platformFeeMinor;
  final int totalMinor;
  final String currency;

  const PrivatePilotQuote({
    required this.days,
    required this.ownerPricePerDayMinor,
    required this.baseRentalMinor,
    required this.discountBasisPoints,
    required this.discountMinor,
    required this.rentalSubtotalMinor,
    required this.platformFeeMinor,
    required this.totalMinor,
    this.currency = 'EUR',
  });
}

class PrivatePilotPricing {
  PrivatePilotPricing._();

  static int eurosToMinor(double value) {
    if (!value.isFinite || value <= 0) return 0;
    return (value * 100).round();
  }

  static double minorToEuros(int value) => value / 100;

  /// Positive monetary amounts use integer half-up rounding to the nearest
  /// cent. This is the single rounding rule for the pilot.
  static int percentageMinor(int amountMinor, int basisPoints) {
    if (amountMinor <= 0 || basisPoints <= 0) return 0;
    return ((amountMinor * basisPoints) + 5000) ~/ 10000;
  }

  static int platformFeeMinor(int discountedRentalMinor) => percentageMinor(
        discountedRentalMinor,
        PrivatePilotConfig.platformFeeBasisPoints,
      );

  static int customerUnitPriceMinor(double ownerUnitPrice) {
    final ownerMinor = eurosToMinor(ownerUnitPrice);
    return ownerMinor + platformFeeMinor(ownerMinor);
  }

  static int discountBasisPointsFor(Item item, int days) {
    if (!item.autoApplyDiscounts || days < 1) return 0;
    var best = 0;
    for (final tier in item.longRentalDiscounts) {
      if (tier.days <= days) {
        final candidate =
            (tier.discountPercent * 100).round().clamp(0, 9000).toInt();
        if (candidate > best) best = candidate;
      }
    }
    return best;
  }

  static PrivatePilotQuote quoteForItem({
    required Item item,
    required int days,
  }) {
    final safeDays = days.clamp(1, 365).toInt();
    final ownerDailyMinor = eurosToMinor(item.pricePerDay);
    final baseMinor = ownerDailyMinor * safeDays;
    final discountBasisPoints = discountBasisPointsFor(item, safeDays);
    final discountMinor = percentageMinor(baseMinor, discountBasisPoints)
        .clamp(0, baseMinor)
        .toInt();
    final rentalSubtotalMinor = baseMinor - discountMinor;
    final feeMinor = platformFeeMinor(rentalSubtotalMinor);
    return PrivatePilotQuote(
      days: safeDays,
      ownerPricePerDayMinor: ownerDailyMinor,
      baseRentalMinor: baseMinor,
      discountBasisPoints: discountBasisPoints,
      discountMinor: discountMinor,
      rentalSubtotalMinor: rentalSubtotalMinor,
      platformFeeMinor: feeMinor,
      totalMinor: rentalSubtotalMinor + feeMinor,
      currency: item.currency,
    );
  }

  static String formatMinor(int value, {String currency = 'EUR'}) {
    final euros = (value / 100).toStringAsFixed(2).replaceAll('.', ',');
    return '$euros ${currency == 'EUR' ? '€' : currency}';
  }
}
