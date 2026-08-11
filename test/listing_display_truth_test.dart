import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/widgets/listing_display_truth.dart';

void main() {
  group('listing ratings', () {
    test('shows only a real rating in the supported range', () {
      expect(listingRatingForDisplay(4.7), 4.7);
      expect(listingRatingForDisplay(0.1), 0.1);
      expect(listingRatingForDisplay(5), 5);
    });

    test('does not invent or sanitize an absent or invalid rating', () {
      expect(listingRatingForDisplay(null), isNull);
      expect(listingRatingForDisplay(0), isNull);
      expect(listingRatingForDisplay(-1), isNull);
      expect(listingRatingForDisplay(5.1), isNull);
      expect(listingRatingForDisplay(double.nan), isNull);
      expect(listingRatingForDisplay(double.infinity), isNull);
    });
  });

  group('listing location labels', () {
    test('shows a calculated distance only when one is available', () {
      expect(
        listingLocationLabel(
          distanceKm: 3.42,
          listingCity: 'Berlin',
          unavailableLabel: 'Nicht verfügbar',
        ),
        '3.4 km',
      );
      expect(
        listingLocationLabel(
          distanceKm: 12.6,
          listingCity: 'Berlin',
          unavailableLabel: 'Nicht verfügbar',
        ),
        '13 km',
      );
    });

    test('falls back to the listing city, never to a fake nearby claim', () {
      expect(
        listingLocationLabel(
          distanceKm: null,
          listingCity: '  Hamburg  ',
          unavailableLabel: 'Nicht verfügbar',
        ),
        'Hamburg',
      );
      expect(
        listingLocationLabel(
          distanceKm: double.nan,
          listingCity: '',
          unavailableLabel: 'Nicht verfügbar',
        ),
        'Nicht verfügbar',
      );
    });
  });

  test('an unset user city stays unset instead of defaulting to Berlin', () {
    expect(configuredUserCity(null), isNull);
    expect(configuredUserCity(''), isNull);
    expect(configuredUserCity('   '), isNull);
    expect(configuredUserCity('  Berlin '), 'Berlin');
  });

  test('listing surfaces contain no deterministic rating fabrication', () {
    for (final path in [
      'lib/screens/explore_screen.dart',
      'lib/widgets/item_card.dart',
      'lib/widgets/listing_carousel_card.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('_deriveRating')),
          reason: '$path must not derive a rating from an item identifier.');
      expect(source, isNot(contains('_deriveStableListingRating')),
          reason: '$path must not invent a stable-looking rating.');
      expect(source, isNot(contains('4.4 +')),
          reason: '$path must not manufacture a positive rating floor.');
    }
  });

  test('explore does not silently use Berlin for an unset user city', () {
    final source = File('lib/screens/explore_screen.dart').readAsStringSync();
    expect(source, isNot(contains("_currentUserCity ?? 'Berlin'")));
    expect(source, contains('configuredUserCity(_currentUserCity)'));
  });
}
