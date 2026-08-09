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
}
