import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guest cart persists items and projects without creating a reservation',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final project = await DataService.addRentalCartProject(
      title: 'Renovierung',
      answers: <String, dynamic>{'room': 'Küche'},
    );
    final item = buildTestItem(id: 'listing-1', ownerId: 'owner-1');
    final saved = await DataService.addRentalCartItem(
      item: item,
      range: DateTimeRange(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 4),
      ),
      projectId: project.id,
    );

    expect(saved.localDeviceOnly, isTrue);
    expect(saved.reservationCreated, isFalse);
    expect(saved.projects.single.title, 'Renovierung');
    expect(saved.items.single.listingId, item.id);
    expect(saved.items.single.projectId, project.id);
    expect(saved.items.single.quoteStatus, 'needs_recheck');

    final prefs = await SharedPreferences.getInstance();
    final itemDocument = jsonDecode(prefs.getString('rental_cart_v1')!) as Map;
    final projectDocument =
        jsonDecode(prefs.getString('project_cart_v1')!) as Map;
    expect(itemDocument['reservationCreated'], isFalse);
    expect(itemDocument['items'], hasLength(1));
    expect(projectDocument['projects'], hasLength(1));

    final withoutProject =
        await DataService.removeRentalCartProject(project.id);
    expect(withoutProject.projects, isEmpty);
    expect(withoutProject.items.single.projectId, isNull);

    final empty =
        await DataService.removeRentalCartItem(withoutProject.items.single.id);
    expect(empty.items, isEmpty);
    expect(empty.reservationCreated, isFalse);
  });

  test('privacy export fails closed for malformed guest cart data', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'rental_cart_v1': '{"items":"not-a-list"}',
      'project_cart_v1': '{"projects":[]}',
    });

    await expectLater(
      DataService.exportSavedItemsForPrivacy(),
      throwsA(isA<FormatException>()),
    );
  });

  test('pending guest sync cannot cross account boundaries', () {
    expect(
      DataService.canSyncGuestCartToAccount(
        pendingAccountId: null,
        currentAccountId: 'account-a',
      ),
      isTrue,
    );
    expect(
      DataService.canSyncGuestCartToAccount(
        pendingAccountId: 'account-a',
        currentAccountId: 'account-a',
      ),
      isTrue,
    );
    expect(
      DataService.canSyncGuestCartToAccount(
        pendingAccountId: 'account-a',
        currentAccountId: 'account-b',
      ),
      isFalse,
    );
    expect(
      DataService.canReadLocalRentalCart(
        pendingAccountId: 'account-a',
        currentAccountId: 'account-b',
      ),
      isFalse,
    );
    expect(
      DataService.canReadLocalRentalCart(
        pendingAccountId: 'account-a',
        currentAccountId: null,
      ),
      isFalse,
    );
    expect(
      DataService.canReadLocalRentalCart(
        pendingAccountId: 'account-a',
        currentAccountId: 'account-a',
      ),
      isTrue,
    );
  });
}
