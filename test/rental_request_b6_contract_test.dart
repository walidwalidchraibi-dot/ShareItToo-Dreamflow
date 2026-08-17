import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/models/rental_request.dart';

void main() {
  test('booking contract carries stable date-only occupancy boundaries', () {
    final request = RentalRequest(
      id: 'booking-1',
      itemId: 'listing-1',
      ownerId: 'owner',
      renterId: 'renter',
      start: DateTime(2026, 10, 24),
      end: DateTime(2026, 10, 27),
      quotedTotalRenter: 49.50,
    );

    final json = request.toJson();

    expect(json['startDate'], '2026-10-24');
    expect(json['endDate'], '2026-10-27');
    expect(json['status'], 'pending');
    expect(json['quotedTotalRenter'], 49.50);
    expect(RentalRequest.fromJson(json).toJson()['startDate'], '2026-10-24');
  });

  test('server-normalized UTC instants are rendered as local rental dates', () {
    final request = RentalRequest.fromJson({
      'id': 'booking-dst',
      'itemId': 'listing-1',
      'ownerId': 'owner',
      'renterId': 'renter',
      'start': '2026-03-27T23:00:00.000Z',
      'end': '2026-03-30T22:00:00.000Z',
      'status': 'pending',
      'startDate': '2026-03-28',
      'endDate': '2026-03-31',
    });

    final json = request.toJson();
    expect(json['startDate'], '2026-03-28');
    expect(json['endDate'], '2026-03-31');
  });

  test('server quote snapshot survives parsing, copy and serialization', () {
    final request = RentalRequest.fromJson({
      'id': 'booking-quote',
      'itemId': 'listing-1',
      'ownerId': 'owner',
      'renterId': 'renter',
      'start': '2026-09-01T10:00:00.000Z',
      'end': '2026-09-04T10:00:00.000Z',
      'status': 'pending',
      'quote': {
        'days': 3,
        'pricePerDayMinor': 2500,
        'baseRentalMinor': 7500,
        'discountPercent': 20,
        'discountMinor': 1500,
        'rentalSubtotalMinor': 6000,
        'platformFeeMinor': 600,
        'totalMinor': 6600,
        'ownerPayoutMinor': 6000,
        'currency': 'EUR',
      },
    });

    final copied = request.copyWith(status: 'accepted');
    final json = copied.toJson();

    expect(json['quotedDays'], 3);
    expect(json['quotedPricePerDayMinor'], 2500);
    expect(json['quotedBaseRentalMinor'], 7500);
    expect(json['quotedDiscountPercent'], 20);
    expect(json['quotedDiscountMinor'], 1500);
    expect(json['quotedRentalSubtotalMinor'], 6000);
    expect(json['quotedPlatformFeeMinor'], 600);
    expect(json['quotedTotalMinor'], 6600);
    expect(json['quotedOwnerPayoutMinor'], 6000);
    expect(json['quotedCurrency'], 'EUR');
  });
}
