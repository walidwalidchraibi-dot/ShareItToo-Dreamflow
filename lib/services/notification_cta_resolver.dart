import 'package:lendify/models/rental_request.dart';
import 'package:lendify/services/data_service.dart';

enum NotificationTargetKind {
  none,
  ownerRequestDetail,
  ownerRequestsOverview,
  ownerBookingDetail,
  renterBookingDetail,
}

class NotificationCtaResolution {
  final NotificationTargetKind target;
  final String sitCategory;
  final String? ctaLabel;
  final String? requestId;

  const NotificationCtaResolution({
    required this.target,
    required this.sitCategory,
    this.ctaLabel,
    this.requestId,
  });
}

class NotificationCtaResolver {
  static String deriveSitCategory(Map<String, dynamic> notification) {
    String lower(Object? value) =>
        value == null ? '' : value.toString().toLowerCase();
    final raw = lower(notification['category']);
    final title = lower(notification['title']);
    final body = lower(notification['body']);
    final entityType = lower(notification['entityType']);
    final cta = lower(notification['ctaLabel']);

    bool matchesAny(Iterable<String> needles) =>
        needles.any((needle) => title.contains(needle) || body.contains(needle));

    if (raw == 'bookings') {
      if (matchesAny(const ['übergabe', 'rückgabe', 'handover', 'qr-code', 'qr code'])) {
        return 'handover';
      }
      if (cta == 'anfrage prüfen' ||
          matchesAny(const ['mietanfrage', 'vermietung', 'deiner anzeige'])) {
        return 'rentals';
      }
      return 'bookings';
    }
    return raw.isNotEmpty ? raw : (entityType == 'booking' ? 'bookings' : 'system');
  }

  static Future<NotificationCtaResolution> resolve({
    required Map<String, dynamic> notification,
    required String currentUserId,
  }) async {
    String str(Object? value) => value == null ? '' : value.toString().trim();
    String lower(Object? value) => str(value).toLowerCase();

    final sitCategory = deriveSitCategory(notification);
    final entityType = lower(notification['entityType']);
    final entityId = str(notification['entityId']);
    final requestId = str(notification['requestId']).isNotEmpty
        ? str(notification['requestId'])
        : ((entityType == 'booking') ? entityId : '');
    final title = lower(notification['title']);
    final body = lower(notification['body']);
    final cta = lower(notification['ctaLabel']);

    final looksLikeOwnerRequest = cta == 'anfrage prüfen' ||
        title.contains('mietanfrage') ||
        body.contains('deiner anzeige') ||
        sitCategory == 'rentals';

    if ((entityType == 'booking' || sitCategory == 'bookings' || sitCategory == 'rentals') &&
        requestId.isNotEmpty) {
      final RentalRequest? req = await DataService.getRentalRequestById(requestId);
      if (req == null) {
        if (looksLikeOwnerRequest) {
          return const NotificationCtaResolution(
            target: NotificationTargetKind.ownerRequestsOverview,
            sitCategory: 'rentals',
            ctaLabel: 'Zu Vermietungen',
          );
        }
        return const NotificationCtaResolution(
          target: NotificationTargetKind.none,
          sitCategory: 'bookings',
        );
      }
      final isOwner = req.ownerId == currentUserId;
      if (req.status == 'pending' && isOwner) {
        return NotificationCtaResolution(
          target: NotificationTargetKind.ownerRequestDetail,
          sitCategory: 'rentals',
          ctaLabel: 'Anfrage prüfen',
          requestId: req.id,
        );
      }
      if (req.status == 'accepted') {
        return NotificationCtaResolution(
          target: isOwner
              ? NotificationTargetKind.ownerBookingDetail
              : NotificationTargetKind.renterBookingDetail,
          sitCategory: isOwner ? 'rentals' : 'bookings',
          ctaLabel: isOwner ? 'Zur Vermietung' : 'Zur Buchung',
          requestId: req.id,
        );
      }
    }

    if (looksLikeOwnerRequest) {
      return const NotificationCtaResolution(
        target: NotificationTargetKind.ownerRequestsOverview,
        sitCategory: 'rentals',
        ctaLabel: 'Zu Vermietungen',
      );
    }

    return NotificationCtaResolution(
      target: NotificationTargetKind.none,
      sitCategory: sitCategory,
    );
  }
}
