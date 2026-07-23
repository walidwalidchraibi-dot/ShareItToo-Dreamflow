import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/screens/notification_detail_screen.dart';
import 'package:lendify/screens/notifications_screen.dart';
import 'package:lendify/screens/ongoing_owner_detail_screen.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/services/localization_service.dart';
import 'package:lendify/services/notification_cta_resolver.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

User buildUser(String id, {required String name}) => User(
      id: id,
      displayName: name,
      email: '@example.com',
      city: 'Berlin',
      preferredLanguage: 'de',
      isVerified: true,
      isBanned: false,
      role: 'user',
      avgRating: 4.9,
      reviewCount: 12,
      createdAt: DateTime(2026, 1, 1),
    );

Item buildItem({required String id, required String ownerId, required String title}) => Item(
      id: id,
      ownerId: ownerId,
      title: title,
      description: 'Test item',
      categoryId: 'electronics',
      subcategory: 'storage',
      tags: const [],
      pricePerDay: 15,
      currency: 'EUR',
      priceUnit: 'day',
      priceRaw: 15,
      deposit: 50,
      autoApplyDiscounts: false,
      longRentalDiscounts: const [],
      photos: const ['https://example.com/qnap.png'],
      locationText: 'Berlin',
      lat: 52.52,
      lng: 13.40,
      geohash: 'u33dc1',
      condition: 'gut',
      minDays: 1,
      maxDays: 14,
      createdAt: DateTime(2026, 1, 1),
      isActive: true,
      verificationStatus: 'verified',
      city: 'Berlin',
      country: 'DE',
      status: 'active',
      timesLent: 0,
    );

RentalRequest buildRequest({
  required String id,
  required String itemId,
  required String ownerId,
  required String renterId,
  required String status,
  DateTime? start,
  DateTime? end,
}) => RentalRequest(
      id: id,
      itemId: itemId,
      ownerId: ownerId,
      renterId: renterId,
      start: start ?? DateTime(2026, 7, 26),
      end: end ?? DateTime(2026, 7, 29),
      status: status,
      message: 'Test request',
      createdAt: DateTime(2026, 7, 20),
    );

Future<void> seedBase() async {
  final owner = buildUser('u1', name: 'Walid Chraibi');
  final renter = buildUser('u5', name: 'Julia Wagner');
  final item = buildItem(id: 'item-u1', ownerId: 'u1', title: 'QNAP NAS');
  final pending = buildRequest(id: 'req-pending', itemId: item.id, ownerId: owner.id, renterId: renter.id, status: 'pending');
  final accepted = buildRequest(id: 'req-accepted', itemId: item.id, ownerId: owner.id, renterId: renter.id, status: 'accepted');

  SharedPreferences.setMockInitialValues({
    'users': jsonEncode([owner.toJson(), renter.toJson()]),
    'items': jsonEncode([item.toJson()]),
    'rental_requests': jsonEncode([pending.toJson(), accepted.toJson()]),
    'notifications': jsonEncode([
      {
        'id': 'notif-owner-request',
        'userId': 'u1',
        'category': 'bookings',
        'priority': 2,
        'title': 'Neue Mietanfrage eingegangen',
        'body': 'Julia Wagner möchte „QNAP NAS“ vom 26.07.2026 bis 29.07.2026 mieten.',
        'entityType': 'booking',
        'entityId': 'req-pending',
        'requestId': 'req-pending',
        'listingId': 'item-u1',
        'counterpartyUserId': 'u5',
        'counterpartyName': 'Julia Wagner',
        'role': 'owner',
        'ctaLabel': 'Anfrage prüfen',
        'archived': false,
        'ts': DateTime(2026, 7, 23, 10, 0).toIso8601String(),
        'read': false,
      }
    ]),
    'notification_preferences_v1': jsonEncode({
      'showImportant': true,
      'showBookings': true,
      'showMessages': true,
      'showSupport': true,
      'showPayments': true,
      'showReviews': true,
      'showSystem': true,
      'showSecurity': true,
      'groupByCategory': true,
      'unreadFirst': false,
    }),
    'currentUser': jsonEncode(owner.toJson()),
    'qa_messages_notifs_seeded_v3_for_u1': true,
    'qa_messages_notifs_seeded_v3_for_u5': true,
  });
  await DataService.setCurrentUser(owner);
}

Widget wrap(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationController()),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await seedBase();
  });

  test('kein self-rental, walid owner, julia renter, qnap payload exakt', () async {
    final n = (await DataService.getNotificationFeedForUser('u1')).first;
    final req = await DataService.getRentalRequestById('req-pending');

    expect(req, isNotNull);
    expect(req!.ownerId, 'u1');
    expect(req.renterId, 'u5');
    expect(req.ownerId, isNot(req.renterId));
    expect(n['listingId'], 'item-u1');
    expect(n['counterpartyUserId'], 'u5');
    expect(n['counterpartyName'], 'Julia Wagner');
    expect(n['requestId'], 'req-pending');
    expect(n['entityId'], 'req-pending');
    expect(n['role'], 'owner');
    expect(n['body'], contains('Julia Wagner möchte „QNAP NAS“'));
  });

  test('anfrage prüfen führt zu ownerRequestDetail', () async {
    final result = await NotificationCtaResolver.resolve(
      notification: (await DataService.getNotificationFeedForUser('u1')).first,
      currentUserId: 'u1',
    );

    expect(result.target, NotificationTargetKind.ownerRequestDetail);
    expect(result.ctaLabel, 'Anfrage prüfen');
    expect(result.requestId, 'req-pending');
  });

  test('fehlende requestId fällt auf ownerRequestsOverview zurück', () async {
    final result = await NotificationCtaResolver.resolve(
      notification: {
        'category': 'bookings',
        'title': 'Neue Mietanfrage eingegangen',
        'body': 'Julia Wagner möchte „QNAP NAS“ mieten.',
        'entityType': 'booking',
        'ctaLabel': 'Anfrage prüfen',
      },
      currentUserId: 'u1',
    );
    expect(result.target, NotificationTargetKind.ownerRequestsOverview);
  });

  testWidgets('vermietungen-tab enthält owner request, buchungen-tab nicht', (tester) async {
    await tester.pumpWidget(wrap(const NotificationsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Vermietungen'), findsOneWidget);
    await tester.tap(find.text('Vermietungen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Julia Wagner möchte „QNAP NAS“', findRichText: true, skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Buchungen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Julia Wagner möchte „QNAP NAS“', findRichText: true, skipOffstage: false), findsNothing);
  });

  testWidgets('pending owner detail zeigt akzeptieren ablehnen und kein anfrage zurückziehen', (tester) async {
    await tester.pumpWidget(wrap(const OngoingOwnerDetailScreen(requestId: 'req-pending', titleOverride: 'Mietanfrage')));
    await tester.pumpAndSettle();

    expect(find.text('Akzeptieren'), findsOneWidget);
    expect(find.text('Ablehnen'), findsOneWidget);
    expect(find.text('Anfrage zurückziehen'), findsNothing);
  });

  testWidgets('owner notification detail nutzt vermieter-terminologie', (tester) async {
    final notification = (await DataService.getNotificationFeedForUser('u1')).first;
    await tester.pumpWidget(wrap(NotificationDetailScreen(notification: notification, onCta: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Neue Mietanfrage eingegangen'), findsOneWidget);
    expect(find.text('Anfrage prüfen'), findsOneWidget);
    expect(find.textContaining('Du hast eine neue Mietanfrage zu deiner Anzeige erhalten.', findRichText: true, skipOffstage: false), findsWidgets);
    expect(find.textContaining('Öffne die Buchung', findRichText: true, skipOffstage: false), findsNothing);
  });

  test('accepted owner request -> kommende vermietung, renter bleibt buchung', () async {
    final ownerResult = await NotificationCtaResolver.resolve(
      notification: {
        'category': 'bookings',
        'title': 'Buchung bestätigt',
        'body': 'Du hast die Anfrage für „QNAP NAS“ angenommen. Öffne die Vermietung für Übergabe & Rückgabe.',
        'entityType': 'booking',
        'entityId': 'req-accepted',
        'requestId': 'req-accepted',
        'ctaLabel': 'Zur Vermietung',
      },
      currentUserId: 'u1',
    );
    final renterResult = await NotificationCtaResolver.resolve(
      notification: {
        'category': 'bookings',
        'title': 'Mietanfrage angenommen',
        'body': 'Deine Anfrage für „QNAP NAS“ wurde angenommen. Öffne die Buchung für Details.',
        'entityType': 'booking',
        'entityId': 'req-accepted',
        'requestId': 'req-accepted',
        'ctaLabel': 'Zur Buchung',
      },
      currentUserId: 'u5',
    );

    expect(ownerResult.target, NotificationTargetKind.ownerBookingDetail);
    expect(ownerResult.ctaLabel, 'Zur Vermietung');
    expect(renterResult.target, NotificationTargetKind.renterBookingDetail);
    expect(renterResult.ctaLabel, 'Zur Buchung');
  });
}
