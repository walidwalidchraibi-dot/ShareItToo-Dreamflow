import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/data_service.dart';

import 'support/test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataService refund policy', () {
    test('unified cancellation policy returns 100 percent until two calendar days before start', () {
      final start = DateTime(2026, 7, 29, 12);

      expect(
        DataService.refundRatio(
          policy: 'unified',
          start: start,
          cancelAt: DateTime(2026, 7, 27, 23, 59),
        ),
        1.0,
      );
      expect(
        DataService.refundRatio(
          policy: 'unified',
          start: start,
          cancelAt: DateTime(2026, 7, 28, 0, 0),
        ),
        0.5,
      );
      expect(
        DataService.refundRatio(
          policy: 'unified',
          start: start,
          cancelAt: DateTime(2026, 7, 29, 0, 0),
        ),
        0.0,
      );
    });
  });

  group('DataService booking transitions', () {
    late final owner = buildTestUser('owner-1', name: 'Walid');
    late final renter = buildTestUser('renter-1', name: 'Julia');
    late final item = buildTestItem(id: 'item-1', ownerId: 'owner-1');

    setUp(() async {
      await seedCoreBookingState(
        owner: owner,
        renter: renter,
        item: item,
        requests: [
          buildTestRequest(
            id: 'req-pickup',
            itemId: item.id,
            ownerId: owner.id,
            renterId: renter.id,
            status: 'accepted',
          ),
          buildTestRequest(
            id: 'req-return',
            itemId: item.id,
            ownerId: owner.id,
            renterId: renter.id,
            status: 'running',
          ),
          buildTestRequest(
            id: 'req-review',
            itemId: item.id,
            ownerId: owner.id,
            renterId: renter.id,
            status: 'running',
            needsReview: true,
          ),
        ],
      );
    });

    test('pickup transition requires active flow and at least four handover photos', () async {
      await DataService.setHandoverActive('req-pickup', active: true);
      await DataService.incrementHandoverPhotos('req-pickup');
      await DataService.incrementHandoverPhotos('req-pickup');
      await DataService.incrementHandoverPhotos('req-pickup');

      final result = await DataService.confirmPickupTransition(
        requestId: 'req-pickup',
        confirmedByUserId: renter.id,
        method: 'qr',
        confirmationContextVerified: true,
        galleryAcknowledged: true,
      );

      final request = await DataService.getRentalRequestById('req-pickup');

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('mindestens 4 Fotos'));
      expect(request!.status, 'accepted');
    });

    test('pickup transition moves accepted booking to running after verified renter confirmation', () async {
      await DataService.setHandoverActive('req-pickup', active: true);
      for (var i = 0; i < DataService.minimumRequiredPhotos; i++) {
        await DataService.incrementHandoverPhotos('req-pickup');
      }

      final result = await DataService.confirmPickupTransition(
        requestId: 'req-pickup',
        confirmedByUserId: renter.id,
        method: 'manual',
        confirmationContextVerified: true,
        galleryAcknowledged: true,
      );

      final request = await DataService.getRentalRequestById('req-pickup');
      final state = await DataService.getHandoverReturnState('req-pickup');

      expect(result.success, isTrue);
      expect(request!.status, 'running');
      expect(request.handoverConfirmation?['confirmedByRole'], 'renter');
      expect(request.handoverConfirmation?['method'], 'manual');
      expect(state['handoverActive'], isFalse);
    });

    test('return transition pauses completion when booking is marked needsReview', () async {
      await DataService.setReturnActive('req-review', active: true);
      for (var i = 0; i < DataService.minimumRequiredPhotos; i++) {
        await DataService.incrementReturnPhotos('req-review');
      }

      final result = await DataService.confirmReturnTransition(
        requestId: 'req-review',
        confirmedByUserId: owner.id,
        method: 'qr',
        confirmationContextVerified: true,
        galleryAcknowledged: true,
        reviewPauseSource: 'test',
      );

      final request = await DataService.getRentalRequestById('req-review');
      final state = await DataService.getHandoverReturnState('req-review');

      expect(result.success, isFalse);
      expect(result.pausedForReview, isTrue);
      expect(request!.status, 'running');
      expect(request.returnConfirmation, isNull);
      expect(state['returnActive'], isTrue);
    });

    test('return transition completes running booking after owner confirmation and required photos', () async {
      await DataService.setReturnActive('req-return', active: true);
      for (var i = 0; i < DataService.minimumRequiredPhotos; i++) {
        await DataService.incrementReturnPhotos('req-return');
      }

      final result = await DataService.confirmReturnTransition(
        requestId: 'req-return',
        confirmedByUserId: owner.id,
        method: 'manual',
        confirmationContextVerified: true,
        galleryAcknowledged: true,
        reviewPauseSource: 'test',
      );

      final request = await DataService.getRentalRequestById('req-return');
      final state = await DataService.getHandoverReturnState('req-return');

      expect(result.success, isTrue);
      expect(result.pausedForReview, isFalse);
      expect(request!.status, 'completed');
      expect(request.returnConfirmation?['confirmedByRole'], 'owner');
      expect(request.returnConfirmation?['method'], 'manual');
      expect(state['returnActive'], isFalse);
    });
  });

  group('DataService price breakdown', () {
    test('delivery return and express fees affect renter total and owner payout as implemented', () {
      final item = buildTestItem(
        id: 'item-priced',
        ownerId: 'owner-1',
        pricePerDay: 20,
        lat: 52.52,
        lng: 13.405,
      );
      final request = buildTestRequest(
        id: 'req-priced',
        itemId: item.id,
        ownerId: 'owner-1',
        renterId: 'renter-1',
        expressRequested: true,
        expressStatus: 'accepted',
        ownerPicksUpAtReturnChosen: true,
        deliveryLat: 52.53,
        deliveryLng: 13.405,
        returnLat: 52.53,
        returnLng: 13.405,
      );

      final breakdown = DataService.priceBreakdownForRequest(
        item: item,
        req: request,
        deliverySel: const {'hinweg': true, 'rueckweg': true, 'express': true},
      );

      expect(breakdown.dropoffFee, 3.0);
      expect(breakdown.returnFee, 3.0);
      expect(breakdown.expressApplied, 5.0);
      expect(breakdown.platformFee, 4.0);
      expect(breakdown.totalRenter, 55.5);
      expect(breakdown.payoutOwner, 51.0);
    });
  });
}
