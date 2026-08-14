import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/services/private_pilot_pricing.dart';

import 'support/test_builders.dart';

void main() {
  test('platform contribution is exact ten percent with one cent rounding', () {
    expect(PrivatePilotPricing.platformFeeMinor(0), 0);
    expect(PrivatePilotPricing.platformFeeMinor(1), 0);
    expect(PrivatePilotPricing.platformFeeMinor(99), 10);
    expect(PrivatePilotPricing.platformFeeMinor(1000), 100);
    expect(PrivatePilotPricing.platformFeeMinor(1005), 101);
  });

  test('quote discounts owner rent before applying the contribution', () {
    final json = buildTestItem(
      id: 'pilot-item',
      ownerId: 'owner',
      pricePerDay: 10.01,
    ).toJson()
      ..['autoApplyDiscounts'] = true
      ..['longRentalDiscounts'] = [
        {'days': 3, 'discountPercent': 10},
      ];
    final item = Item.fromJson(json);

    final quote = PrivatePilotPricing.quoteForItem(item: item, days: 3);

    expect(quote.baseRentalMinor, 3003);
    expect(quote.discountMinor, 300);
    expect(quote.rentalSubtotalMinor, 2703);
    expect(quote.platformFeeMinor, 270);
    expect(quote.totalMinor, 2973);
  });

  test('public unit price already includes the contribution', () {
    expect(PrivatePilotPricing.customerUnitPriceMinor(10), 1100);
    expect(PrivatePilotPricing.formatMinor(1100), '11,00 €');
  });
}
