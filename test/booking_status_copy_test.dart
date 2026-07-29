import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/utils/booking_status_copy.dart';

void main() {
  test('upcoming labels distinguish pickup vs delivery', () {
    expect(
      bookingCardStatusLabel(
        category: 'upcoming',
        start: DateTime(2026, 8, 1),
        end: null,
        booking: const {'ownerDeliversAtDropoffChosen': false},
        now: DateTime(2026, 7, 30),
      ),
      'Abholung in 2 Tage',
    );

    expect(
      bookingCardStatusLabel(
        category: 'upcoming',
        start: DateTime(2026, 8, 1),
        end: null,
        booking: const {'ownerDeliversAtDropoffChosen': true},
        now: DateTime(2026, 7, 30),
      ),
      'Lieferung in 2 Tage',
    );
  });

  test('ongoing labels distinguish return vs owner pickup', () {
    expect(
      bookingCardStatusLabel(
        category: 'ongoing',
        start: null,
        end: DateTime(2026, 8, 2),
        booking: const {'ownerPicksUpAtReturnChosen': false},
      ),
      'Rückgabe bis 02. Aug',
    );

    expect(
      bookingCardStatusLabel(
        category: 'ongoing',
        start: null,
        end: DateTime(2026, 8, 2),
        booking: const {'ownerPicksUpAtReturnChosen': true},
      ),
      'Abholung bis 02. Aug',
    );
  });

  test('completed labels keep held and cancelled wording', () {
    expect(
      bookingCardStatusLabel(
        category: 'completed',
        start: null,
        end: null,
        booking: const {'needsReview': true},
      ),
      'In Prüfung',
    );
    expect(
      bookingCardStatusLabel(
        category: 'completed',
        start: null,
        end: null,
        booking: const {'rawStatus': 'cancelled'},
      ),
      'Storniert',
    );
  });
}
