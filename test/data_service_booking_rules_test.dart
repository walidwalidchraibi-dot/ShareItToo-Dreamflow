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

    test('handover start rejects unknown request id without state mutation',
        () async {
      final before = await DataService.getHandoverReturnState('missing-handover');

      await DataService.setHandoverActive('missing-handover', active: true);

      final after = await DataService.getHandoverReturnState('missing-handover');

      expect(before, after);
      expect(after['handoverActive'], isFalse);
      expect(after['returnActive'], isFalse);
    });

    test('handover start rejects non-accepted request without state mutation',
        () async {
      await DataService.updateRentalRequestStatus(
        requestId: 'req-pickup',
        status: 'running',
      );
      final before = await DataService.getHandoverReturnState('req-pickup');

      await DataService.setHandoverActive('req-pickup', active: true);

      final after = await DataService.getHandoverReturnState('req-pickup');
      final request = await DataService.getRentalRequestById('req-pickup');

      expect(after, before);
      expect(after['handoverActive'], isFalse);
      expect(after['returnActive'], isFalse);
      expect(request!.status, 'running');
    });

    test('handover start activates accepted request without changing booking status',
        () async {
      final beforeRequest = await DataService.getRentalRequestById('req-pickup');

      await DataService.setHandoverActive('req-pickup', active: true);

      final afterState = await DataService.getHandoverReturnState('req-pickup');
      final afterRequest = await DataService.getRentalRequestById('req-pickup');

      expect(afterState['handoverActive'], isTrue);
      expect(afterState['returnActive'], isFalse);
      expect(afterRequest!.status, 'accepted');
      expect(beforeRequest!.status, 'accepted');
    });

    test('handover start rejects repeated activation without state mutation',
        () async {
      await DataService.setHandoverActive('req-pickup', active: true);
      final before = await DataService.getHandoverReturnState('req-pickup');

      await DataService.setHandoverActive('req-pickup', active: true);

      final after = await DataService.getHandoverReturnState('req-pickup');
      final request = await DataService.getRentalRequestById('req-pickup');

      expect(after, before);
      expect(after['handoverActive'], isTrue);
      expect(after['returnActive'], isFalse);
      expect(request!.status, 'accepted');
    });

    test('return start rejects unknown request id without state mutation',
        () async {
      final before = await DataService.getHandoverReturnState('missing-return');

      await DataService.setReturnActive('missing-return', active: true);

      final after = await DataService.getHandoverReturnState('missing-return');

      expect(before, after);
      expect(after['handoverActive'], isFalse);
      expect(after['returnActive'], isFalse);
    });

    test('return start rejects non-running request without state mutation',
        () async {
      await DataService.updateRentalRequestStatus(
        requestId: 'req-return',
        status: 'accepted',
      );
      final before = await DataService.getHandoverReturnState('req-return');

      await DataService.setReturnActive('req-return', active: true);

      final after = await DataService.getHandoverReturnState('req-return');
      final request = await DataService.getRentalRequestById('req-return');

      expect(after, before);
      expect(after['handoverActive'], isFalse);
      expect(after['returnActive'], isFalse);
      expect(request!.status, 'accepted');
    });

    test('return start activates running request without changing booking status',
        () async {
      final beforeRequest = await DataService.getRentalRequestById('req-return');

      await DataService.setReturnActive('req-return', active: true);

      final afterState = await DataService.getHandoverReturnState('req-return');
      final afterRequest = await DataService.getRentalRequestById('req-return');

      expect(afterState['handoverActive'], isFalse);
      expect(afterState['returnActive'], isTrue);
      expect(afterRequest!.status, 'running');
      expect(beforeRequest!.status, 'running');
    });

    test('return start rejects repeated activation without state mutation',
        () async {
      await DataService.setReturnActive('req-return', active: true);
      final before = await DataService.getHandoverReturnState('req-return');

      await DataService.setReturnActive('req-return', active: true);

      final after = await DataService.getHandoverReturnState('req-return');
      final request = await DataService.getRentalRequestById('req-return');

      expect(after, before);
      expect(after['handoverActive'], isFalse);
      expect(after['returnActive'], isTrue);
      expect(request!.status, 'running');
    });

    test('pickup transition rejects requests whose status is not accepted',
        () async {
      await DataService.updateRentalRequestStatus(
        requestId: 'req-pickup',
        status: 'running',
      );
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

      expect(result.success, isFalse);
      expect(
          result.errorMessage, contains('Übergabe ist gerade nicht verfügbar'));
      expect(request!.status, 'running');
      expect(request.handoverConfirmation, isNull);
    });

    test(
        'pickup transition rejects wrong renter role even when status is accepted',
        () async {
      await DataService.setHandoverActive('req-pickup', active: true);
      for (var i = 0; i < DataService.minimumRequiredPhotos; i++) {
        await DataService.incrementHandoverPhotos('req-pickup');
      }

      final result = await DataService.confirmPickupTransition(
        requestId: 'req-pickup',
        confirmedByUserId: owner.id,
        method: 'manual',
        confirmationContextVerified: true,
        galleryAcknowledged: true,
      );

      final request = await DataService.getRentalRequestById('req-pickup');

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('nur für den Mieter'));
      expect(request!.status, 'accepted');
      expect(request.handoverConfirmation, isNull);
    });

    test(
        'pickup transition rejects accepted request without active handover flow',
        () async {
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

      expect(result.success, isFalse);
      expect(result.errorMessage,
          contains('Bitte starte die Übergabe zuerst im Chat'));
      expect(request!.status, 'accepted');
      expect(request.handoverConfirmation, isNull);
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

    test(
        'pickup transition rejects repeated confirmation after booking is already running',
        () async {
      await DataService.setHandoverActive('req-pickup', active: true);
      for (var i = 0; i < DataService.minimumRequiredPhotos; i++) {
        await DataService.incrementHandoverPhotos('req-pickup');
      }

      final first = await DataService.confirmPickupTransition(
        requestId: 'req-pickup',
        confirmedByUserId: renter.id,
        method: 'manual',
        confirmationContextVerified: true,
        galleryAcknowledged: true,
      );
      final afterFirst = await DataService.getRentalRequestById('req-pickup');

      final second = await DataService.confirmPickupTransition(
        requestId: 'req-pickup',
        confirmedByUserId: renter.id,
        method: 'manual',
        confirmationContextVerified: true,
        galleryAcknowledged: true,
      );

      final afterSecond = await DataService.getRentalRequestById('req-pickup');

      expect(first.success, isTrue);
      expect(afterFirst!.status, 'running');
      expect(second.success, isFalse);
      expect(
          second.errorMessage, contains('Übergabe ist gerade nicht verfügbar'));
      expect(afterSecond!.status, 'running');
      expect(afterSecond.handoverConfirmation?['confirmedByRole'], 'renter');
    });

    test('return transition rejects requests whose status is not running',
        () async {
      await DataService.updateRentalRequestStatus(
        requestId: 'req-return',
        status: 'completed',
      );
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

      expect(result.success, isFalse);
      expect(
          result.errorMessage, contains('Rückgabe ist gerade nicht verfügbar'));
      expect(request!.status, 'completed');
      expect(request.returnConfirmation, isNull);
    });

    test(
        'return transition rejects wrong owner role even when status is running',
        () async {
      await DataService.setReturnActive('req-return', active: true);
      for (var i = 0; i < DataService.minimumRequiredPhotos; i++) {
        await DataService.incrementReturnPhotos('req-return');
      }

      final result = await DataService.confirmReturnTransition(
        requestId: 'req-return',
        confirmedByUserId: renter.id,
        method: 'manual',
        confirmationContextVerified: true,
        galleryAcknowledged: true,
        reviewPauseSource: 'test',
      );

      final request = await DataService.getRentalRequestById('req-return');

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('nur für den Vermieter'));
      expect(request!.status, 'running');
      expect(request.returnConfirmation, isNull);
    });

    test('return transition rejects running request without active return flow',
        () async {
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

      expect(result.success, isFalse);
      expect(result.errorMessage,
          contains('Bitte starte die Rückgabe zuerst im Chat'));
      expect(request!.status, 'running');
      expect(request.returnConfirmation, isNull);
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

    test(
        'return transition rejects repeated confirmation after booking is already completed',
        () async {
      await DataService.setReturnActive('req-return', active: true);
      for (var i = 0; i < DataService.minimumRequiredPhotos; i++) {
        await DataService.incrementReturnPhotos('req-return');
      }

      final first = await DataService.confirmReturnTransition(
        requestId: 'req-return',
        confirmedByUserId: owner.id,
        method: 'manual',
        confirmationContextVerified: true,
        galleryAcknowledged: true,
        reviewPauseSource: 'test',
      );
      final afterFirst = await DataService.getRentalRequestById('req-return');

      final second = await DataService.confirmReturnTransition(
        requestId: 'req-return',
        confirmedByUserId: owner.id,
        method: 'manual',
        confirmationContextVerified: true,
        galleryAcknowledged: true,
        reviewPauseSource: 'test',
      );

      final afterSecond = await DataService.getRentalRequestById('req-return');

      expect(first.success, isTrue);
      expect(afterFirst!.status, 'completed');
      expect(second.success, isFalse);
      expect(
          second.errorMessage, contains('Rückgabe ist gerade nicht verfügbar'));
      expect(afterSecond!.status, 'completed');
      expect(afterSecond.returnConfirmation?['confirmedByRole'], 'owner');
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
