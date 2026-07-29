import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/invoices_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ownerMain = buildTestUser('owner-main', name: 'Owner Main');
  final ownerA = buildTestUser('owner-a', name: 'Owner A');
  final ownerB = buildTestUser('owner-b', name: 'Owner B');
  final ownerC = buildTestUser('owner-c', name: 'Owner C');
  final renterA = buildTestUser('renter-a', name: 'Renter A');
  final renterMain = buildTestUser('renter-main', name: 'Renter Main');
  final outsider = buildTestUser('outsider-main', name: 'Outsider');

  final baseUsers = [
    ownerMain,
    ownerA,
    ownerB,
    ownerC,
    renterA,
    renterMain,
    outsider,
  ];

  final baseItems = [
    buildTestItem(
        id: 'item-owner-main', ownerId: ownerMain.id, title: 'Main Drill'),
    buildTestItem(
        id: 'item-owner-a', ownerId: ownerA.id, title: 'Owner A Camera'),
    buildTestItem(
        id: 'item-owner-b', ownerId: ownerB.id, title: 'Owner B Monitor'),
    buildTestItem(
        id: 'item-owner-c', ownerId: ownerC.id, title: 'Owner C Light'),
    buildTestItem(
        id: 'item-renter-a', ownerId: renterA.id, title: 'Renter A Bike'),
    buildTestItem(
        id: 'item-renter-main',
        ownerId: renterMain.id,
        title: 'Renter Main Router'),
    buildTestItem(
        id: 'item-outsider', ownerId: outsider.id, title: 'Outsider Speaker'),
  ];

  Future<void> seedQaBase({required String currentUserId}) async {
    final currentUser = baseUsers.singleWhere((u) => u.id == currentUserId);
    SharedPreferences.setMockInitialValues({
      'users': jsonEncode(baseUsers.map((u) => u.toJson()).toList()),
      'items': jsonEncode(baseItems.map((i) => i.toJson()).toList()),
      'rental_requests': '[]',
      'message_threads_v1': '[]',
      'notifications': '[]',
      'review_reminders_v1': '[]',
      'multi_reviews_v1': '[]',
      'currentUser': jsonEncode(currentUser.toJson()),
    });
  }

  Future<void> triggerQaSeed(String currentUserId) async {
    await DataService.setCurrentUser(
      baseUsers.singleWhere((u) => u.id == currentUserId),
    );
    final me = await DataService.getCurrentUser();
    expect(me, isNotNull);
    expect(me!.id, currentUserId);
  }

  test('qa renter lane seeds accepted/running/completed/needsReview smoke set',
      () async {
    await seedQaBase(currentUserId: renterMain.id);
    await triggerQaSeed(renterMain.id);

    final requests =
        await DataService.getRentalRequestsForRenter(renterMain.id);
    final ids = requests.map((r) => r.id).toSet();

    expect(ids, contains('qa_req_accepted_${renterMain.id}'));
    expect(ids, contains('qa_req_running_${renterMain.id}'));
    expect(ids, contains('qa_req_completed_${renterMain.id}'));
    expect(ids, contains('qa_req_review_${renterMain.id}'));
    expect(ids, contains('qa_req_pending_${renterMain.id}'));

    final acceptedThread = await DataService.getMessageThreadByRequestId(
      'qa_req_accepted_${renterMain.id}',
    );
    expect(acceptedThread, isNotNull);

    final invoices = await InvoicesService.getInvoicesForCurrentUser();
    expect(
      invoices.where((d) =>
          d.requestId == 'qa_req_completed_${renterMain.id}' &&
          d.type.name == 'invoice'),
      isNotEmpty,
    );
    expect(
      invoices.where((d) => d.requestId == 'qa_req_review_${renterMain.id}'),
      isEmpty,
    );
  });

  test(
      'qa owner lane supports handover pickup return completion and held-doc smoke',
      () async {
    await seedQaBase(currentUserId: ownerMain.id);
    await triggerQaSeed(ownerMain.id);

    final ownerRequests =
        await DataService.getRentalRequestsForOwner(ownerMain.id);
    final ownerIds = ownerRequests.map((r) => r.id).toSet();
    expect(ownerIds, contains('qa_owner_pending_${ownerMain.id}'));
    expect(ownerIds, contains('qa_owner_upcoming_pickup_${ownerMain.id}'));
    expect(ownerIds, contains('qa_owner_upcoming_delivery_${ownerMain.id}'));
    expect(ownerIds, contains('qa_owner_running_${ownerMain.id}'));
    expect(ownerIds, contains('qa_owner_completed_clean_${ownerMain.id}'));
    expect(ownerIds, contains('qa_owner_completed_problem_${ownerMain.id}'));

    expect(
      await DataService.setHandoverActive(
        'qa_owner_upcoming_pickup_${ownerMain.id}',
        active: true,
      ),
      isTrue,
    );
    for (var i = 0; i < DataService.minimumRequiredPhotos; i++) {
      await DataService.incrementHandoverPhotos(
        'qa_owner_upcoming_pickup_${ownerMain.id}',
      );
    }

    await triggerQaSeed(ownerA.id);
    final pickup = await DataService.confirmPickupTransition(
      requestId: 'qa_owner_upcoming_pickup_${ownerMain.id}',
      confirmedByUserId: ownerA.id,
      method: 'manual',
      confirmationContextVerified: true,
      galleryAcknowledged: true,
    );
    expect(pickup.success, isTrue);
    expect(
      (await DataService.getRentalRequestById(
              'qa_owner_upcoming_pickup_${ownerMain.id}'))!
          .status,
      'running',
    );

    await triggerQaSeed(ownerC.id);
    expect(
      await DataService.setReturnActive(
        'qa_owner_running_${ownerMain.id}',
        active: true,
      ),
      isTrue,
    );
    for (var i = 0; i < DataService.minimumRequiredPhotos; i++) {
      await DataService.incrementReturnPhotos(
        'qa_owner_running_${ownerMain.id}',
      );
    }

    await triggerQaSeed(ownerMain.id);
    final completion = await DataService.confirmReturnTransition(
      requestId: 'qa_owner_running_${ownerMain.id}',
      confirmedByUserId: ownerMain.id,
      method: 'manual',
      confirmationContextVerified: true,
      galleryAcknowledged: true,
      reviewPauseSource: 'qa_smoke_test',
    );
    expect(completion.success, isTrue);
    expect(
      (await DataService.getRentalRequestById(
              'qa_owner_running_${ownerMain.id}'))!
          .status,
      'completed',
    );

    final ownerInvoices =
        await InvoicesService.getInvoicesForUser(ownerMain.id);
    expect(
      ownerInvoices.where((d) =>
          d.requestId == 'qa_owner_completed_clean_${ownerMain.id}' &&
          d.type.name == 'payment'),
      isNotEmpty,
    );
    expect(
      ownerInvoices.where(
          (d) => d.requestId == 'qa_owner_completed_problem_${ownerMain.id}'),
      isEmpty,
    );
  });

  test('real outsider stays blocked from foreign deep-links and foreign docs',
      () async {
    await seedQaBase(currentUserId: ownerMain.id);
    await triggerQaSeed(ownerMain.id);
    await triggerQaSeed(outsider.id);

    final foreignThreadById = await DataService.getMessageThreadById(
      'qa_thread_accepted_${ownerMain.id}',
    );
    final foreignThreadByRequest =
        await DataService.getMessageThreadByRequestId(
      'qa_req_accepted_${ownerMain.id}',
    );
    final outsiderInvoices = await InvoicesService.getInvoicesForCurrentUser();

    expect(foreignThreadById, isNull);
    expect(foreignThreadByRequest, isNull);
    expect(
      outsiderInvoices
          .where((d) => d.requestId == 'qa_req_completed_${ownerMain.id}'),
      isEmpty,
    );
  });
}
