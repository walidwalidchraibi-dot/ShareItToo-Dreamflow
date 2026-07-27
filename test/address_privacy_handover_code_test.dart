import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/address_privacy.dart';
import 'package:lendify/services/handover_code.dart';

void main() {
  group('AddressPrivacy', () {
    test('reveals exact pickup address only from six hours before accepted handover', () {
      final handoverAt = DateTime(2026, 7, 29, 18);

      expect(
        AddressPrivacy.shouldRevealExactAddress(
          isAccepted: true,
          handoverAt: handoverAt,
          now: handoverAt.subtract(const Duration(hours: 6, minutes: 1)),
        ),
        isFalse,
      );
      expect(
        AddressPrivacy.shouldRevealExactAddress(
          isAccepted: true,
          handoverAt: handoverAt,
          now: handoverAt.subtract(const Duration(hours: 6)),
        ),
        isTrue,
      );
      expect(
        AddressPrivacy.shouldRevealExactAddress(
          isAccepted: false,
          handoverAt: handoverAt,
          now: handoverAt,
        ),
        isFalse,
      );
    });

    test('approximates house numbers into a nearby range', () {
      expect(
        AddressPrivacy.approximate('Hauptstraße 17, 10115 Berlin'),
        'Hauptstraße 10–20, 10115 Berlin',
      );
      expect(
        AddressPrivacy.nearbySentence(
          kindLabel: 'Abholung',
          address: 'Musterweg 93, Berlin',
        ),
        'Abholung in der Nähe von Musterweg 90–100, Berlin',
      );
    });
  });

  group('HandoverCodeService', () {
    test('creates deterministic six digit codes per segment and presenter role', () {
      final start = DateTime(2026, 7, 29, 18);
      final pickupOwner = HandoverCodeService.codeForTitleAndStart(
        title: 'Canon EOS R5',
        start: start,
        bookingId: 'req-1',
        segment: HandoverCodeService.segmentPickup,
        presenterRole: HandoverCodeService.presenterOwner,
      );
      final returnRenter = HandoverCodeService.codeForTitleAndStart(
        title: 'Canon EOS R5',
        start: start,
        bookingId: 'req-1',
        segment: HandoverCodeService.segmentReturn,
        presenterRole: HandoverCodeService.presenterRenter,
      );

      expect(RegExp(r'^\d{6}$').hasMatch(pickupOwner), isTrue);
      expect(RegExp(r'^\d{6}$').hasMatch(returnRenter), isTrue);
      expect(pickupOwner, isNot(returnRenter));
      expect(
        HandoverCodeService.codeForTitleAndStart(
          title: 'Canon EOS R5',
          start: start,
          bookingId: 'req-1',
          segment: HandoverCodeService.segmentPickup,
          presenterRole: HandoverCodeService.presenterOwner,
        ),
        pickupOwner,
      );
    });

    test('qr payload parsing validates segment role code and booking binding', () {
      const code = '123456';
      final payload = HandoverCodeService.qrPayload(
        segment: HandoverCodeService.segmentPickup,
        presenterRole: HandoverCodeService.presenterOwner,
        code: code,
        bookingId: 'req-77',
      );

      final parsed = HandoverCodeService.parseQrPayload(payload);

      expect(parsed, isNotNull);
      expect(parsed!.segment, HandoverCodeService.segmentPickup);
      expect(parsed.presenterRole, HandoverCodeService.presenterOwner);
      expect(parsed.code, code);
      expect(parsed.bookingId, 'req-77');
      expect(
        HandoverCodeService.isExpectedQrPayload(
          payload,
          segment: HandoverCodeService.segmentPickup,
          presenterRole: HandoverCodeService.presenterOwner,
          code: code,
          bookingId: 'req-77',
        ),
        isTrue,
      );
      expect(
        HandoverCodeService.isExpectedQrPayload(
          payload,
          segment: HandoverCodeService.segmentReturn,
          presenterRole: HandoverCodeService.presenterOwner,
          code: code,
          bookingId: 'req-77',
        ),
        isFalse,
      );
    });
  });
}
