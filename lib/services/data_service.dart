import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lendify/services/auth_service.dart';
import 'package:lendify/services/backend_config.dart';
import 'package:lendify/services/backend_repository.dart';
import 'package:lendify/services/handover_code.dart';
import 'package:lendify/services/developer_preview_service.dart';
import 'package:lendify/services/blocked_users_service.dart';
import 'package:lendify/services/qa_runtime_service.dart';
import 'package:lendify/services/shared_persistence_sync.dart';
import 'package:lendify/services/private_pilot_pricing.dart';
import 'package:lendify/services/private_pilot_cancellation_policy.dart';
import 'package:lendify/services/private_pilot_return_policy.dart';
import 'package:lendify/config/private_pilot_config.dart';
import 'package:lendify/models/category.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/review.dart';
import 'package:lendify/models/multi_criteria_review.dart';
import 'package:lendify/services/review_metrics_service.dart';
import 'package:lendify/models/message.dart';
import 'package:lendify/models/security.dart';
import 'package:lendify/utils/booking_flow_policy.dart';
import 'package:lendify/utils/total_subtitle.dart';

class RentalRequestTransitionResult {
  final bool success;
  final bool pausedForReview;
  final String? errorMessage;

  const RentalRequestTransitionResult._({
    required this.success,
    required this.pausedForReview,
    this.errorMessage,
  });

  const RentalRequestTransitionResult.success()
      : this._(success: true, pausedForReview: false);

  const RentalRequestTransitionResult.failure(String message)
      : this._(success: false, pausedForReview: false, errorMessage: message);

  const RentalRequestTransitionResult.paused(String message)
      : this._(success: false, pausedForReview: true, errorMessage: message);
}

class DataService {
  static const bool _allowDemoSeedDataInRuntime = false;
  static const String _categoriesKey = 'categories';
  static const String _itemsKey = 'items';
  static const String _usersKey = 'users';
  static const String _currentUserKey = 'currentUser';
  static const String _accountDeletedKey = 'account_deleted_v1';
  static const String _bookingSelectionsKey = 'booking_selections';
  static const String _rentalRequestsKey = 'rental_requests';
  static const String _timelineEventsKey = 'timeline_events';
  static const String _notificationsKey = 'notifications';
  static const String _reviewRemindersKey = 'review_reminders_v1';
  static const String _reviewsKey = 'reviews';
  static const String _multiReviewsKey = 'multi_reviews_v1';
  static const String _feedbacksKey = 'feedbacks';
  static const String _seedFiveFlagKey = 'seed_five_showcase_applied';
  static const String _purgedToOwnedFlagKey = 'purged_to_owned_once';
  static const String _requestsLastSeenKey = 'requests_last_seen_by_owner';
  static const String _readRequestsKey =
      'read_requests_v1'; // userId -> Set<requestId>
  static const String _handoverFailCountsKey = 'handover_fail_counts';
  static const String _handoverBannersKey = 'handover_banners';
  static const String _rideCompKey = 'ride_compensation_v1';
  // Wishlists
  static const String _wishlistsMetaKey = 'wishlists_meta_v1';
  static const String _wishlistAssignKey = 'wishlist_assign_v1';
  static const String _messageThreadsKey = 'message_threads_v1';
  static const String _demoNotifSeedFlagPrefix = 'demo_notif_seeded_for_';
  static const String _qaMessagesAndNotifsSeedFlagPrefix =
      'qa_messages_notifs_seeded_v3_for_';
  static final Set<String> _qaSeedUsersInProgress = <String>{};

  /// Read-only backend refreshes update the local cache but must not announce
  /// another logical data change. Announcing those cache writes makes every
  /// listening screen fetch again, which can create a refresh feedback loop.
  @visibleForTesting
  static bool shouldAnnounceMessageThreadCacheWrite({
    required bool readOnlyRemoteRefresh,
  }) =>
      !readOnlyRemoteRefresh;

  @visibleForTesting
  static bool canExposeCachedCurrentUser({
    required bool backendEnabled,
    required bool hasSession,
  }) =>
      !backendEnabled || hasSession;

  @visibleForTesting
  static User? cachedCurrentUserForSession({
    required String? encodedUser,
    required AuthSession? session,
  }) {
    if (session == null || encodedUser == null || encodedUser.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(encodedUser);
      if (decoded is! Map) return null;
      final user = User.fromJson(Map<String, dynamic>.from(decoded));
      final sessionUserId = (session.userId ?? '').trim();
      if (sessionUserId.isEmpty || user.id.trim() != sessionUserId) return null;
      final sessionEmail = session.email.trim().toLowerCase();
      if (sessionEmail.isEmpty ||
          user.email.trim().toLowerCase() != sessionEmail) {
        return null;
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  static Future<User?> getCachedCurrentUserForSession(
      AuthSession? session) async {
    if (session == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      return cachedCurrentUserForSession(
        encodedUser: prefs.getString(_currentUserKey),
        session: session,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _persistMessageThreads(
    SharedPreferences prefs,
    List<dynamic> threads, {
    bool announceChange = true,
  }) async {
    final payload = threads
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    await prefs.setString(_messageThreadsKey, jsonEncode(payload));
    if (announceChange) {
      SharedPersistenceSync.notify(SharedPersistenceSync.messageThreadsKey);
    }
  }

  static Future<String?> _readMessageThreads(
    SharedPreferences prefs, {
    Duration remoteTimeout = const Duration(seconds: 20),
  }) async {
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      try {
        final remote = await BackendRepository.getMessageThreads(
          timeout: remoteTimeout,
        );
        final encoded = jsonEncode(remote);
        await prefs.setString(_messageThreadsKey, encoded);
        return encoded;
      } catch (error) {
        debugPrint('[DataService] remote message load failed: $error');
      }
    }
    return prefs.getString(_messageThreadsKey);
  }

  // Security
  static const String _securitySettingsKey = 'security_settings_v1';
  static const String _signedInDevicesKey = 'signed_in_devices_v1';

  static Future<SecuritySettings> getSecuritySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_securitySettingsKey);
      if (raw == null || raw.isEmpty) {
        return const SecuritySettings(enabled: false, method: 'sms');
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SecuritySettings.fromJson(map);
    } catch (e) {
      debugPrint('[DataService] getSecuritySettings failed: $e');
      return const SecuritySettings(enabled: false, method: 'sms');
    }
  }

  static Future<void> setSecuritySettings(SecuritySettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _securitySettingsKey,
        jsonEncode(settings.toJson()),
      );
    } catch (e) {
      debugPrint('[DataService] setSecuritySettings failed: $e');
    }
  }

  static Future<List<SecurityDevice>> getSignedInDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_signedInDevicesKey);
      if (raw == null || raw.isEmpty) {
        final seeded = _seedSignedInDevices();
        await prefs.setString(
          _signedInDevicesKey,
          jsonEncode(seeded.map((e) => e.toJson()).toList()),
        );
        return seeded;
      }
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      final parsed = <SecurityDevice>[];
      for (final e in list) {
        if (e is Map) {
          parsed.add(
            SecurityDevice.fromJson(e.map((k, v) => MapEntry(k.toString(), v))),
          );
        }
      }
      return parsed;
    } catch (e) {
      debugPrint('[DataService] getSignedInDevices failed: $e');
      return const [];
    }
  }

  static Future<void> setSignedInDevices(List<SecurityDevice> devices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _signedInDevicesKey,
        jsonEncode(devices.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[DataService] setSignedInDevices failed: $e');
    }
  }

  static List<SecurityDevice> _seedSignedInDevices() {
    final now = DateTime.now();
    return [
      SecurityDevice(
        id: 'this',
        name: 'Dieses Gerät',
        location: 'Aktuell',
        lastActive: now,
        isThisDevice: true,
      ),
      SecurityDevice(
        id: 'dev_2',
        name: 'Chrome Browser',
        location: 'Stuttgart',
        lastActive: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      SecurityDevice(
        id: 'dev_3',
        name: 'iPhone',
        location: 'Berlin',
        lastActive: now.subtract(const Duration(hours: 6)),
      ),
    ];
  }

  // Runtime timers for express confirmation deadlines (not persisted). We also
  // run a sweep on data fetch to enforce timeouts across sessions.
  static final Map<String, Timer> _expressTimers = {};

  // Transient event to communicate that a listing was created or saved as draft.
  // Consumed by ExploreScreen to show a confirmation popup after navigation.
  static (Item item, bool draft)? _lastCreateEvent;
  static void setLastCreateEvent(Item item, {required bool draft}) {
    _lastCreateEvent = (item, draft);
  }

  /// Owner-side pickup/handover confirmation failure counter
  /// We persist how many times the Vermieter failed to confirm pickup (e.g. QR scan mismatch or
  /// wrong manual code) keyed by bookingId so the Mieter can be offered a manual confirm after 3 tries.
  static Future<int> getPickupFailCountForBooking(String bookingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_handoverFailCountsKey);
      if (raw == null || raw.isEmpty) return 0;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final v = map[bookingId];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> incrementPickupFailForBooking(String bookingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_handoverFailCountsKey);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        try {
          map = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          map = {};
        }
      }
      final current =
          (map[bookingId] is num) ? (map[bookingId] as num).toInt() : 0;
      final next = current + 1;
      map[bookingId] = next;
      await prefs.setString(_handoverFailCountsKey, jsonEncode(map));
      return next;
    } catch (_) {
      return 0;
    }
  }

  static (Item, bool)? takeLastCreateEvent() {
    final e = _lastCreateEvent;
    _lastCreateEvent = null;
    return e;
  }

  /// Set a one-time banner text for a booking to be shown on next open.
  /// Stored under a lightweight map keyed by bookingId.
  static Future<void> setHandoverBanner({
    required String bookingId,
    required String message,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_handoverBannersKey);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        try {
          map = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          map = {};
        }
      }
      map[bookingId] = {'msg': message, 'ts': DateTime.now().toIso8601String()};
      await prefs.setString(_handoverBannersKey, jsonEncode(map));
    } catch (e) {
      // ignore but log for debug
      debugPrint('[DataService] setHandoverBanner failed: $e');
    }
  }

  /// Returns and removes the banner text for a booking if present.
  static Future<String?> takeHandoverBanner(String bookingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_handoverBannersKey);
      if (raw == null || raw.isEmpty) return null;
      Map<String, dynamic> map;
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
      final entry = map[bookingId];
      if (entry is Map) {
        final msg = (entry['msg'] as String?) ?? '';
        map.remove(bookingId);
        await prefs.setString(_handoverBannersKey, jsonEncode(map));
        return msg.isNotEmpty ? msg : null;
      }
      return null;
    } catch (e) {
      // ignore but log for debug
      debugPrint('[DataService] takeHandoverBanner failed: $e');
      return null;
    }
  }

  // Persisted availability selection per item
  static Future<(DateTime? start, DateTime? end)> getSavedDateRange(
    String itemId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingSelectionsKey);
    if (raw == null || raw.isEmpty) return (null, null);
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entry = map[itemId];
      if (entry is Map) {
        final s = entry['start'] as String?;
        final e = entry['end'] as String?;
        return (
          s != null ? DateTime.tryParse(s) : null,
          e != null ? DateTime.tryParse(e) : null,
        );
      }
    } catch (_) {}
    return (null, null);
  }

  static Future<void> setSavedDateRange(
    String itemId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingSelectionsKey);
    Map<String, dynamic> map = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        map = {};
      }
    }
    // Merge into existing per-item object instead of overwriting it so we
    // don't drop previously saved delivery selections.
    final existing =
        (map[itemId] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
            <String, dynamic>{};
    existing['start'] = start.toIso8601String();
    existing['end'] = end.toIso8601String();
    map[itemId] = existing;
    await prefs.setString(_bookingSelectionsKey, jsonEncode(map));
  }

  static Future<void> clearSavedDateRange(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingSelectionsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map.containsKey(itemId)) {
        map.remove(itemId);
        await prefs.setString(_bookingSelectionsKey, jsonEncode(map));
      }
    } catch (_) {}
  }

  /// Clears only the saved delivery selection for a given item without touching other items.
  static Future<void> clearSavedDeliverySelection(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingSelectionsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entry = map[itemId];
      if (entry is Map) {
        final existing = Map<String, dynamic>.from(entry);
        if (existing.containsKey('delivery')) {
          existing.remove('delivery');
          if (existing.isEmpty) {
            map.remove(itemId);
          } else {
            map[itemId] = existing;
          }
          await prefs.setString(_bookingSelectionsKey, jsonEncode(map));
        }
      }
    } catch (_) {}
  }

  /// Computes long-term discount for a given item and rental length.
  /// Returns a tuple: (finalTotal, baseTotal, appliedPercent, discountAmount).
  /// - baseTotal = item.pricePerDay * days
  /// - appliedPercent is 0 when no tier matches or disabled
  /// - discountAmount is positive value in EUR
  static (
    double finalTotal,
    double baseTotal,
    double appliedPercent,
    double discountAmount,
  ) computeTotalWithDiscounts({required Item item, required int days}) {
    final quote = PrivatePilotPricing.quoteForItem(item: item, days: days);
    return (
      PrivatePilotPricing.minorToEuros(quote.rentalSubtotalMinor),
      PrivatePilotPricing.minorToEuros(quote.baseRentalMinor),
      quote.discountBasisPoints / 100,
      PrivatePilotPricing.minorToEuros(quote.discountMinor),
    );
  }

  /// Platform contribution ("Plattformbeitrag").
  /// Input: rentalSubtotal (after any rental discounts), excluding delivery/express.
  /// The private-pilot contribution is always exactly 10% of the discounted
  /// rental subtotal. It is calculated in integer cents with one documented
  /// half-up rounding step and has no minimum fee.
  static double platformContributionForRental(double rentalSubtotal) {
    final rentalMinor = PrivatePilotPricing.eurosToMinor(rentalSubtotal);
    return PrivatePilotPricing.minorToEuros(
      PrivatePilotPricing.platformFeeMinor(rentalMinor),
    );
  }

  /// Unified pricing breakdown for an existing rental request.
  ///
  /// Returns a record with:
  /// - days: number of rental days (min 1)
  /// - basePerDay, baseTotal, discountAmount, rentalSubtotal
  /// - platformFee (computed ONLY on rentalSubtotal)
  /// - dropoffFee (owner delivers at pickup) and returnFee (owner picks up at return)
  /// - expressApplied: For the RENTER total we include Express immediately
  ///   when selected/requested (transient deliverySel.express, req.expressRequested
  ///   or already accepted). This makes the renter’s Gesamtbetrag stable across
  ///   Ausstehend → Kommend → Laufend → Abgeschlossen.
  ///   For OWNER payout we only count Express when it is accepted.
  /// - total includes additional 10% applied on Express surcharge (if applied)
  /// - totalRenter (what renter pays)
  /// - payoutOwner (what owner receives; platform fee does not reduce delivery/express)
  static ({
    int days,
    double basePerDay,
    double baseTotal,
    double discountAmount,
    double rentalSubtotal,
    double platformFee,
    double dropoffFee,
    double returnFee,
    double expressApplied,
    double totalRenter,
    double payoutOwner,
  }) priceBreakdownForRequest({
    required Item item,
    required RentalRequest req,
    Map<String, dynamic>? deliverySel,
  }) {
    // Days
    final int days = (req.end.difference(req.start).inHours / 24).ceil().clamp(
          1,
          365,
        );
    final priced = computeTotalWithDiscounts(item: item, days: days);
    final double basePerDay = item.pricePerDay;
    final double baseTotal = priced.$2; // before discount
    final double discountAmount = priced.$4; // absolute EUR
    final double rentalSubtotal = priced.$1; // after discount
    final double platformFee = platformContributionForRental(rentalSubtotal);

    // Infer delivery responsibilities robustly (persisted flags first, then fallbacks)
    final bool inferredOwnerDeliversByTransient =
        (deliverySel?['hinweg'] == true);
    final bool inferredOwnerDeliversByExpress =
        req.expressRequested || (req.expressStatus != null);
    final bool inferredOwnerDeliversByAddress =
        ((req.deliveryAddressLine ?? '').toString().trim().isNotEmpty) ||
            ((req.deliveryCity ?? '').toString().trim().isNotEmpty);
    final bool ownerDelivers = req.ownerDeliversAtDropoffChosen ||
        inferredOwnerDeliversByTransient ||
        inferredOwnerDeliversByExpress ||
        inferredOwnerDeliversByAddress;

    final bool inferredOwnerPicksUpByTransient =
        (deliverySel?['rueckweg'] == true);
    final bool ownerPicksUp =
        req.ownerPicksUpAtReturnChosen || inferredOwnerPicksUpByTransient;

    double estimateKm({double? lat, double? lng, String? line, String? city}) {
      if (lat != null && lng != null) {
        return estimateDistanceKm(item.lat, item.lng, lat, lng);
      }
      if ((line ?? '').trim().isNotEmpty) {
        return estimateDistanceKmFromAddressLine(
          item.lat,
          item.lng,
          line!.trim(),
        );
      }
      if ((city ?? '').trim().isNotEmpty) {
        return estimateDistanceKmToCity(item.lat, item.lng, city!.trim());
      }
      return 0.0;
    }

    final double dropoffKm = estimateKm(
      lat: req.deliveryLat ??
          (deliverySel?['deliveryLat'] as num?)?.toDouble() ??
          (deliverySel?['lat'] as num?)?.toDouble(),
      lng: req.deliveryLng ??
          (deliverySel?['deliveryLng'] as num?)?.toDouble() ??
          (deliverySel?['lng'] as num?)?.toDouble(),
      line: req.deliveryAddressLine ??
          (deliverySel?['deliveryAddressLine'] as String?) ??
          (deliverySel?['addressLine'] as String?),
      city: req.deliveryCity ??
          (deliverySel?['deliveryCity'] as String?) ??
          (deliverySel?['city'] as String?),
    );
    final double returnKm = estimateKm(
      lat: req.returnLat ??
          (deliverySel?['returnLat'] as num?)?.toDouble() ??
          req.deliveryLat ??
          (deliverySel?['lat'] as num?)?.toDouble(),
      lng: req.returnLng ??
          (deliverySel?['returnLng'] as num?)?.toDouble() ??
          req.deliveryLng ??
          (deliverySel?['lng'] as num?)?.toDouble(),
      line: req.returnAddressLine ??
          (deliverySel?['returnAddressLine'] as String?) ??
          req.deliveryAddressLine ??
          (deliverySel?['addressLine'] as String?),
      city: req.returnCity ??
          (deliverySel?['returnCity'] as String?) ??
          req.deliveryCity ??
          (deliverySel?['city'] as String?),
    );

    double dropoffFee = 0.0;
    double returnFee = 0.0;
    if (PrivatePilotConfig.deliveryEnabled && ownerDelivers) {
      dropoffFee = deliveryFeeForDistanceKm(dropoffKm);
    }
    if (PrivatePilotConfig.deliveryEnabled && ownerPicksUp) {
      returnFee = deliveryFeeForDistanceKm(returnKm);
    }

    // Express: renter sees the surcharge as soon as it is selected/requested.
    // We consider three sources:
    //  - transient UI selection deliverySel['express']
    //  - request.expressRequested (persisted)
    //  - request.expressStatus == 'accepted' (persisted)
    final bool expressSelectedTransient = (deliverySel?['express'] == true);
    final bool expressAccepted =
        req.expressRequested && (req.expressStatus == 'accepted');
    final bool expressRequestedOrSelected =
        expressSelectedTransient || req.expressRequested || expressAccepted;
    final double expressApplied =
        PrivatePilotConfig.deliveryEnabled && expressRequestedOrSelected
            ? req.expressFee
            : 0.0;
    // New rule: add 10% of the Express surcharge to the renter total
    final double expressPlatformPart = expressApplied > 0
        ? double.parse((expressApplied * 0.10).toStringAsFixed(2))
        : 0.0;

    final double totalRenter = double.parse(
      (rentalSubtotal +
              platformFee +
              dropoffFee +
              returnFee +
              expressApplied +
              expressPlatformPart)
          .toStringAsFixed(2),
    );
    // Owner payout should only include express when accepted
    final double payoutOwner = double.parse(
      (rentalSubtotal +
              dropoffFee +
              returnFee +
              (PrivatePilotConfig.deliveryEnabled && expressAccepted
                  ? req.expressFee
                  : 0.0))
          .toStringAsFixed(2),
    );

    return (
      days: days,
      basePerDay: basePerDay,
      baseTotal: double.parse(baseTotal.toStringAsFixed(2)),
      discountAmount: double.parse(discountAmount.toStringAsFixed(2)),
      rentalSubtotal: double.parse(rentalSubtotal.toStringAsFixed(2)),
      platformFee: double.parse(platformFee.toStringAsFixed(2)),
      dropoffFee: dropoffFee,
      returnFee: returnFee,
      expressApplied: double.parse(expressApplied.toStringAsFixed(2)),
      totalRenter: totalRenter,
      payoutOwner: payoutOwner,
    );
  }

  // Add or update an item in local storage
  static Future<Item> addItem(Item item) async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString(_itemsKey);
    final List<dynamic> list = itemsJson == null ? [] : jsonDecode(itemsJson);
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final remote = await BackendRepository.createListing(item.toJson());
      final saved = Item.fromJson(remote);
      list.removeWhere(
        (entry) =>
            entry is Map && entry['id']?.toString() == saved.id.toString(),
      );
      list.add(saved.toJson());
      await prefs.setString(_itemsKey, jsonEncode(list));
      return saved;
    }
    // Compute next numeric id
    int maxId = 0;
    for (final e in list) {
      final idStr = (e as Map)['id']?.toString() ?? '0';
      final id = int.tryParse(idStr) ?? 0;
      if (id > maxId) maxId = id;
    }
    final nextId = (maxId + 1).toString();
    final toStore = Item(
      id: nextId,
      ownerId: item.ownerId,
      title: item.title,
      description: item.description,
      categoryId: item.categoryId,
      subcategory: item.subcategory,
      tags: item.tags,
      pricePerDay: item.pricePerDay,
      currency: item.currency,
      priceUnit: item.priceUnit,
      priceRaw: item.priceRaw,
      autoApplyDiscounts: item.autoApplyDiscounts,
      longRentalDiscounts: item.longRentalDiscounts,
      photos: item.photos,
      locationText: item.locationText,
      lat: item.lat,
      lng: item.lng,
      geohash: item.geohash,
      condition: item.condition,
      minDays: item.minDays,
      maxDays: item.maxDays,
      createdAt: item.createdAt,
      isActive: item.isActive,
      verificationStatus: item.verificationStatus,
      city: item.city,
      country: item.country,
      status: item.status,
      endedAt: item.endedAt,
      timesLent: item.timesLent,
      offersDeliveryAtDropoff: item.offersDeliveryAtDropoff,
      offersPickupAtReturn: item.offersPickupAtReturn,
      offersExpressAtDropoff: item.offersExpressAtDropoff,
      maxDeliveryKmAtDropoff: item.maxDeliveryKmAtDropoff,
      maxPickupKmAtReturn: item.maxPickupKmAtReturn,
      cancellationPolicy: item.cancellationPolicy,
    );
    list.add(toStore.toJson());

    Future<void> persist(List<dynamic> payload) async {
      await prefs.setString(_itemsKey, jsonEncode(payload));
    }

    // Try to persist, falling back to photo sanitation when web storage quota is exceeded.
    try {
      await persist(list);
    } catch (e) {
      debugPrint(
        '[DataService] addItem persist failed, attempting to shrink payload: $e',
      );
      // 1) Remove oversized inline images and keep at most three uploaded URLs.
      List<dynamic> shrunk = list.map((raw) {
        try {
          final m = Map<String, dynamic>.from(raw as Map);
          final photos = (m['photos'] as List?)
                  ?.map((p) => p?.toString() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toList() ??
              <String>[];
          final limited = <String>[];
          int idx = 0;
          for (final p in photos) {
            if (idx >= 3) break;
            if (!p.startsWith('data:')) {
              limited.add(p);
            }
            idx++;
          }
          m['photos'] = limited;
          return m;
        } catch (_) {
          return raw;
        }
      }).toList();
      try {
        await persist(shrunk);
      } catch (e2) {
        debugPrint(
          '[DataService] addItem persist still failing after shrink: $e2',
        );
        // 2) Last resort: strip photos entirely to guarantee saving
        final stripped = shrunk.map((raw) {
          try {
            final m = Map<String, dynamic>.from(raw as Map);
            m['photos'] = <String>[];
            return m;
          } catch (_) {
            return raw;
          }
        }).toList();
        await persist(stripped);
      }
    }
    return toStore;
  }

  static Future<List<Category>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getString(_categoriesKey);
    if (categoriesJson == null) {
      await _initializeSampleData();
      return getCategories();
    }
    final List<dynamic> categoriesList = jsonDecode(categoriesJson);
    final List<Category> categories =
        categoriesList.map((json) => Category.fromJson(json)).toList();

    // Ensure newly added demo categories are present for all users (no lazy backfill).
    final seeds = _buildDemoCategories();
    final orderById = {for (int i = 0; i < seeds.length; i++) seeds[i].id: i};

    bool mutated = false;
    for (final seed in seeds) {
      final exists = categories.any((c) => c.id == seed.id);
      if (!exists) {
        categories.add(seed);
        mutated = true;
      }
    }

    categories.sort((a, b) {
      final ai = orderById[a.id] ?? seeds.length;
      final bi = orderById[b.id] ?? seeds.length;
      if (ai != bi) return ai.compareTo(bi);
      return a.name.compareTo(b.name);
    });

    if (mutated) {
      await prefs.setString(
        _categoriesKey,
        jsonEncode(categories.map((c) => c.toJson()).toList()),
      );
    }

    if (PrivatePilotConfig.enabled) {
      return categories
          .where((category) => PrivatePilotConfig.categoryAllowed(category.id))
          .toList(growable: false);
    }
    return categories;
  }

  static Future<List<Item>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      try {
        final remote = await BackendRepository.getListings();
        final items = <Item>[];
        for (final entry in remote) {
          try {
            items.add(Item.fromJson(entry));
          } catch (error) {
            debugPrint('[DataService] skipped invalid remote listing: $error');
          }
        }
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await prefs.setString(
          _itemsKey,
          jsonEncode(items.map((item) => item.toJson()).toList()),
        );
        return items;
      } catch (error) {
        debugPrint('[DataService] remote listings load failed: $error');
        rethrow;
      }
    }
    final itemsJson = prefs.getString(_itemsKey);
    if (itemsJson == null) {
      await _initializeSampleData();
      return getItems();
    }
    List<dynamic> itemsList;
    try {
      itemsList = jsonDecode(itemsJson);
    } catch (e) {
      // If decoding fails entirely, reset with fresh demo data
      await _initializeSampleData();
      return getItems();
    }

    // If storage exists but is empty (e.g., after a one-time purge), reseed demo listings
    // so the app doesn't appear broken on Explore/My Listings.
    if (itemsList.isEmpty) {
      try {
        await resetItemsAndSeedFive(force: true);
      } catch (e) {
        debugPrint('[DataService] getItems reseed-on-empty failed: $e');
        await _initializeSampleData();
      }
      return getItems();
    }

    // Parse defensively: skip corrupted entries instead of failing the whole load
    final List<Item> parsed = [];
    bool mutated = false;
    for (final raw in itemsList) {
      try {
        final map = Map<String, dynamic>.from(raw as Map);
        parsed.add(Item.fromJson(map));
      } catch (e) {
        // Skip bad entry and mark mutated so we can sanitize storage
        mutated = true;
        debugPrint(
          '[DataService] Skipped corrupted item entry: $e',
        );
      }
    }
    if (mutated) {
      await prefs.setString(
        _itemsKey,
        jsonEncode(parsed.map((e) => e.toJson()).toList()),
      );
    }
    List<Item> items = parsed;

    // Auto-clean: delete "ended" items older than 60 days
    final now = DateTime.now();
    final filtered = <Item>[];
    bool mutatedAging = false;
    for (final it in items) {
      if (it.status == 'ended' && it.endedAt != null) {
        final diff = now.difference(it.endedAt!).inDays;
        if (diff >= 60) {
          mutatedAging = true;
          continue;
        }
      }
      filtered.add(it);
    }
    if (mutatedAging) {
      await prefs.setString(
        _itemsKey,
        jsonEncode(filtered.map((e) => e.toJson()).toList()),
      );
      items = filtered;
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// One-time operation: delete all existing items and keep only those owned by the
  /// current user. Used to switch the app into a mode where only user-created
  /// listings are present and tested.
  static Future<void> ensureOnlyUserItemsOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_purgedToOwnedFlagKey) ?? false;
    if (done) return;

    // Clear all items; from now on, only user-created listings will populate this store.
    await prefs.setString(_itemsKey, jsonEncode([]));

    // Clear related stores so UI/state doesn't reference removed items.
    await prefs.remove(_rentalRequestsKey);
    await prefs.remove(_bookingSelectionsKey);
    await prefs.remove(_timelineEventsKey);
    await prefs.remove(_savedItemsKey);

    await prefs.setBool(_purgedToOwnedFlagKey, true);
  }

  /// Ensures the local store contains at least some listings.
  ///
  /// This is a safety net for cases where a previous debug build purged the demo
  /// dataset (resulting in an empty Explore feed).
  ///
  /// - If items are missing: normal demo init will happen on first read.
  /// - If items exist but are an empty list: we seed a small showcase dataset.
  static Future<void> ensureListingsSeededIfEmpty() async {
    if (!_allowDemoSeedDataInRuntime) {
      debugPrint(
        '[DataService] ensureListingsSeededIfEmpty skipped (demo seed disabled)',
      );
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_itemsKey);
      if (raw == null || raw.trim().isEmpty) {
        debugPrint('[DataService] No items found -> seeding showcase listings');
        await prefs.setBool(_purgedToOwnedFlagKey, false);
        await resetItemsAndSeedFive(force: true);
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.isEmpty) {
        debugPrint(
          '[DataService] Items store empty -> seeding showcase listings',
        );
        await prefs.setBool(_purgedToOwnedFlagKey, false);
        await resetItemsAndSeedFive(force: true);
      }
    } catch (e) {
      debugPrint('[DataService] ensureListingsSeededIfEmpty failed: $e');
    }
  }

  /// Clears all persisted listings and seeds exactly five showcase items
  /// that reflect the latest delivery/return and express logic.
  /// If [force] is false, it will only run once per device based on a flag.
  static Future<void> resetItemsAndSeedFive({bool force = false}) async {
    if (!_allowDemoSeedDataInRuntime) {
      debugPrint(
        '[DataService] resetItemsAndSeedFive skipped (demo seed disabled)',
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final already = prefs.getBool(_seedFiveFlagKey) ?? false;
    if (!force && already) return;

    // Ensure categories and users exist
    if (prefs.getString(_categoriesKey) == null ||
        prefs.getString(_usersKey) == null) {
      await _initializeSampleData();
    }

    // Load needed references
    final categories = await getCategories();
    final users = await getUsers();

    // Build five curated items
    final five = _buildFiveShowcaseItems(users, categories);

    await prefs.setString(
      _itemsKey,
      jsonEncode(five.map((e) => e.toJson()).toList()),
    );
    // Clear related volatile demo stores so UI reflects new dataset
    await prefs.remove(_rentalRequestsKey);
    await prefs.remove(_bookingSelectionsKey);
    await prefs.remove(_timelineEventsKey);
    await prefs.remove(_savedItemsKey);

    await prefs.setBool(_seedFiveFlagKey, true);
  }

  static Future<List<User>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);
    if (usersJson == null) {
      await _initializeSampleData();
      return getUsers();
    }
    final List<dynamic> usersList = jsonDecode(usersJson);
    bool mutated = false;
    final fixed = usersList.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      if (!map.containsKey('createdAt') ||
          map['createdAt'] == null ||
          (map['createdAt'] as String).isEmpty) {
        map['createdAt'] = DateTime.now().toIso8601String();
        mutated = true;
      }
      if (!map.containsKey('avgRating') || map['avgRating'] == null) {
        map['avgRating'] = 0.0;
        mutated = true;
      }
      if (!map.containsKey('reviewCount') || map['reviewCount'] == null) {
        map['reviewCount'] = 0;
        mutated = true;
      }
      final isDeactivated = map['isDeactivated'] == true;
      final id = map['id']?.toString();
      if (!isDeactivated && id != null) {
        final override = _seedForId(id);
        if (override != null) {
          if (map['displayName'] != override.$1) {
            map['displayName'] = override.$1;
            mutated = true;
          }
          if (map['photoURL'] != override.$2) {
            map['photoURL'] = override.$2;
            mutated = true;
          }
        }
      }
      return map;
    }).toList();

    var users = fixed.map((json) => User.fromJson(json)).toList();
    users = await _applyCentralReviewStatsToUsers(users);

    final correctedJson = users.map((user) => user.toJson()).toList();
    if (mutated || jsonEncode(fixed) != jsonEncode(correctedJson)) {
      await prefs.setString(_usersKey, jsonEncode(correctedJson));
    }
    return users;
  }

  static Future<User?> getCurrentUser() async {
    if (QaRuntimeService.isEnabled) {
      final runtimeUser = QaRuntimeService.runtimeUserJson;
      if (runtimeUser != null) {
        final user = User.fromJson(runtimeUser);
        await _ensureQaMessagesAndNotificationsForUserOnce(user.id);
        return user;
      }

      final users = await getUsers();
      final user = users.firstWhere(
        (candidate) => candidate.id == QaRuntimeService.personaId,
        orElse: () => users.firstWhere((candidate) => candidate.id == 'u1'),
      );
      QaRuntimeService.setRuntimeUserJson(user.toJson());
      await _ensureQaMessagesAndNotificationsForUserOnce(user.id);
      return user;
    }

    // Developer preview mode: allow simulating guest/first launch without touching persisted user data.
    try {
      final preview = await DeveloperPreviewController.readStateOnce();
      if (preview == DeveloperUserState.firstLaunch ||
          preview == DeveloperUserState.loggedOut) {
        return null;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final deleted = prefs.getBool(_accountDeletedKey) ?? false;
    if (deleted) {
      // When the user has deleted their account, do not re-seed demo data.
      return null;
    }

    Future<String?> safeReadCurrentUser() async {
      try {
        return prefs.getString(_currentUserKey);
      } catch (e) {
        debugPrint(
          '[DataService] currentUser malformed; clearing persisted value: $e',
        );
        try {
          await prefs.remove(_currentUserKey);
        } catch (_) {}
        return null;
      }
    }

    String? userJson = await safeReadCurrentUser();
    AuthSession? backendSession;
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final session = await AuthService.readSession();
      backendSession = session;
      if (!canExposeCachedCurrentUser(
        backendEnabled: true,
        hasSession: session != null,
      )) {
        if (userJson != null && userJson.isNotEmpty) {
          await prefs.remove(_currentUserKey);
        }
        return null;
      }
      if (session == null) return null;
      var localUserId = '';
      if (userJson != null && userJson.isNotEmpty) {
        try {
          localUserId = (jsonDecode(userJson) as Map)['id']?.toString() ?? '';
        } catch (_) {}
      }
      if (localUserId != session.userId) {
        await syncCurrentUserForSessionEmail(session.email);
        userJson = await safeReadCurrentUser();
      }
    }
    if (userJson == null || userJson.isEmpty) {
      final session = backendSession ?? await AuthService.readSession();
      if (session != null) {
        await syncCurrentUserForSessionEmail(session.email);
        userJson = await safeReadCurrentUser();
      }
    }
    if (userJson == null || userJson.isEmpty) {
      if (!_allowDemoSeedDataInRuntime) {
        debugPrint(
          '[DataService] getCurrentUser skipped demo init (demo seed disabled)',
        );
        return null;
      }
      try {
        await _initializeSampleData();
      } catch (e) {
        debugPrint('[DataService] getCurrentUser init demo failed: $e');
      }
      final again = await safeReadCurrentUser();
      if (again == null || again.isEmpty) return null;
      return User.fromJson(jsonDecode(again) as Map<String, dynamic>);
    }

    final Map<String, dynamic> map =
        jsonDecode(userJson) as Map<String, dynamic>;
    bool mutated = false;
    if (!map.containsKey('createdAt') ||
        (map['createdAt'] == null || (map['createdAt'] as String).isEmpty)) {
      map['createdAt'] = DateTime.now().toIso8601String();
      mutated = true;
    }
    if (!map.containsKey('avgRating') || map['avgRating'] == null) {
      map['avgRating'] = 0.0;
      mutated = true;
    }
    if (!map.containsKey('reviewCount') || map['reviewCount'] == null) {
      map['reviewCount'] = 0;
      mutated = true;
    }

    final isDeactivated = map['isDeactivated'] == true;
    if (!isDeactivated) {
      final id = map['id']?.toString();
      if (id != null) {
        final override = _seedForId(id);
        if (override != null && map['photoURL'] != override.$2) {
          map['photoURL'] = override.$2;
          mutated = true;
        }
      }
    }

    var user = User.fromJson(map);

    try {
      final users = await getUsers();
      final corrected = users
          .where((u) => u.id == user.id)
          .cast<User?>()
          .firstWhere((u) => u != null, orElse: () => null);
      if (corrected != null &&
          (corrected.avgRating != user.avgRating ||
              corrected.reviewCount != user.reviewCount)) {
        user = user.copyWith(
          avgRating: corrected.avgRating,
          reviewCount: corrected.reviewCount,
        );
        mutated = true;
      }
    } catch (_) {}

    // Developer preview mode: optionally force verification flag on the current user.
    try {
      final preview = await DeveloperPreviewController.readStateOnce();
      if (preview == DeveloperUserState.verifiedUser &&
          user.isVerified != true) {
        user = user.copyWith(
          isVerified: true,
          emailVerified: true,
          phoneVerified: true,
        );
        mutated = true;
      }
      if (preview == DeveloperUserState.loggedIn && user.isVerified == true) {
        user = user.copyWith(isVerified: false);
        mutated = true;
      }
    } catch (_) {}
    if (mutated) {
      await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    }
    await _ensureQaMessagesAndNotificationsForUserOnce(user.id);
    return user;
  }

  static Future<void> applyQaFixturesForScreenAudit() async {
    final me = await getCurrentUser();
    if (me == null || me.id.isEmpty || !kDebugMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_qaMessagesAndNotifsSeedFlagPrefix${me.id}');
    await _ensureQaMessagesAndNotificationsForUserOnce(me.id);
  }

  static Future<void> _ensureDemoNotificationsForUserOnce(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_demoNotifSeedFlagPrefix$userId';
      final done = prefs.getBool(key) ?? false;
      if (done) return;

      final now = DateTime.now();
      // A small, realistic starter feed covering the MVP categories.
      await addStructuredNotification(
        userId: userId,
        category: 'platform',
        priority: 5,
        title: 'Willkommen bei ShareItToo',
        body:
            'Hier findest du alle Updates zu Buchungen, Chats, Bewertungen und Zahlungen.',
        entityType: 'system',
        entityId: 'welcome_${now.microsecondsSinceEpoch}',
        ctaLabel: '',
        critical: false,
        timestamp: now,
      );
      await addStructuredNotification(
        userId: userId,
        category: 'security',
        priority: 1,
        title: 'Sicherheits‑Check',
        body:
            'Aktiviere bei Gelegenheit deine Verifizierung, um mehr Vertrauen zu schaffen.',
        entityType: 'system',
        entityId: 'security_tip_${now.microsecondsSinceEpoch}',
        ctaLabel: '',
        critical: false,
        timestamp: now.subtract(const Duration(hours: 3)),
      );
      await addStructuredNotification(
        userId: userId,
        category: 'payments',
        priority: 2,
        title: 'Zahlungsmethode hinzufügen',
        body:
            'Hinterlege eine Zahlungsmethode, damit Buchungen später schneller gehen.',
        entityType: 'payment',
        entityId: 'payment_methods',
        ctaLabel: 'Öffnen',
        timestamp: now.subtract(const Duration(days: 1, hours: 1)),
      );
      await addStructuredNotification(
        userId: userId,
        category: 'reviews',
        priority: 4,
        title: 'Bewertungen sammeln',
        body:
            'Nach jeder abgeschlossenen Miete kannst du eine Bewertung abgeben.',
        entityType: 'system',
        entityId: 'review_tip_${now.microsecondsSinceEpoch}',
        ctaLabel: '',
        timestamp: now.subtract(const Duration(days: 3, hours: 2)),
      );
      await addStructuredNotification(
        userId: userId,
        category: 'messages',
        priority: 3,
        title: 'Tipp: Schnelle Abstimmung',
        body: 'Nutze Chats, um Übergabe und Rückgabe effizient zu planen.',
        entityType: 'system',
        entityId: 'chat_tip_${now.microsecondsSinceEpoch}',
        ctaLabel: '',
        timestamp: now.subtract(const Duration(days: 12, hours: 5)),
      );

      await addStructuredNotification(
        userId: userId,
        category: 'messages',
        priority: 3,
        title: 'Neue Nachricht',
        body: 'Du hast eine neue Nachricht – antworte direkt aus dem Feed.',
        entityType: 'system',
        entityId: 'demo_message_${now.microsecondsSinceEpoch}',
        actions: const [
          {'id': 'reply', 'label': 'Antworten'},
        ],
        timestamp: now.subtract(const Duration(minutes: 18)),
      );

      await prefs.setBool(key, true);
    } catch (e) {
      debugPrint(
        '[DataService] _ensureDemoNotificationsForUserOnce failed: $e',
      );
    }
  }

  static const bool _launchQaSeedingEnabled = true;

  static Future<void> _ensureQaMessagesAndNotificationsForUserOnce(
    String userId,
  ) async {
    if (userId.isEmpty || !kDebugMode || !_launchQaSeedingEnabled) return;
    if (_qaSeedUsersInProgress.contains(userId)) return;
    _qaSeedUsersInProgress.add(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_qaMessagesAndNotifsSeedFlagPrefix$userId';
      final done = prefs.getBool(key) ?? false;
      if (done) return;

      User? me;
      if (QaRuntimeService.isEnabled) {
        final runtimeUser = QaRuntimeService.runtimeUserJson;
        if (runtimeUser != null) {
          try {
            me = User.fromJson(runtimeUser);
          } catch (_) {}
        }
      } else {
        final rawCurrentUser = prefs.getString(_currentUserKey);
        if (rawCurrentUser == null || rawCurrentUser.isEmpty) return;
        try {
          me = User.fromJson(
            Map<String, dynamic>.from(jsonDecode(rawCurrentUser) as Map),
          );
        } catch (_) {}
      }
      if (me == null || me.id != userId) return;

      final users = await getUsers();
      final items = await getItems();
      if (users.isEmpty || items.isEmpty) return;

      final otherUsers = users.where((u) => u.id != userId).toList();
      if (otherUsers.isEmpty) return;

      final User ownerA = otherUsers[0];
      final User ownerB = otherUsers.length > 1 ? otherUsers[1] : otherUsers[0];
      final User ownerC = otherUsers.length > 2 ? otherUsers[2] : otherUsers[0];
      final User renterA = otherUsers.length > 3 ? otherUsers[3] : ownerB;

      Item? firstOwnedBy(String ownerId) {
        for (final item in items) {
          if (item.ownerId == ownerId) return item;
        }
        return null;
      }

      Item? firstOwnedByWithPhoto(String ownerId) {
        for (final item in items) {
          if (item.ownerId == ownerId && item.photos.isNotEmpty) return item;
        }
        return firstOwnedBy(ownerId);
      }

      final acceptedItem = firstOwnedByWithPhoto(ownerA.id) ?? items.first;
      final runningItem = firstOwnedByWithPhoto(ownerB.id) ?? acceptedItem;
      final completedItem = firstOwnedBy(ownerC.id) ?? runningItem;
      final ownerTemplate =
          firstOwnedByWithPhoto(me.id) ?? firstOwnedBy(me.id) ?? items.first;
      final now = DateTime.now();

      Item ownerQaItem({
        required String id,
        required String title,
        bool offersDeliveryAtDropoff = false,
        bool offersPickupAtReturn = false,
      }) {
        return Item(
          id: id,
          ownerId: userId,
          title: title,
          description: 'Lokaler QA-Fixture-Artikel für Owner-Screen-Audits.',
          categoryId: ownerTemplate.categoryId,
          subcategory: ownerTemplate.subcategory,
          tags: ownerTemplate.tags,
          pricePerDay: ownerTemplate.pricePerDay,
          currency: ownerTemplate.currency,
          priceUnit: ownerTemplate.priceUnit,
          priceRaw: ownerTemplate.priceRaw,
          autoApplyDiscounts: ownerTemplate.autoApplyDiscounts,
          longRentalDiscounts: ownerTemplate.longRentalDiscounts,
          photos: ownerTemplate.photos,
          locationText: ownerTemplate.locationText,
          lat: ownerTemplate.lat,
          lng: ownerTemplate.lng,
          geohash: ownerTemplate.geohash,
          condition: ownerTemplate.condition,
          minDays: ownerTemplate.minDays,
          maxDays: ownerTemplate.maxDays,
          createdAt: now.subtract(const Duration(days: 1)),
          isActive: true,
          verificationStatus: ownerTemplate.verificationStatus,
          city: ownerTemplate.city,
          country: ownerTemplate.country,
          status: 'active',
          timesLent: ownerTemplate.timesLent,
          offersDeliveryAtDropoff: offersDeliveryAtDropoff,
          offersPickupAtReturn: offersPickupAtReturn,
          offersExpressAtDropoff: ownerTemplate.offersExpressAtDropoff,
          maxDeliveryKmAtDropoff: ownerTemplate.maxDeliveryKmAtDropoff,
          maxPickupKmAtReturn: ownerTemplate.maxPickupKmAtReturn,
          cancellationPolicy: ownerTemplate.cancellationPolicy,
        );
      }

      final ownerPendingItem = ownerQaItem(
        id: 'qa_owner_item_pending_$userId',
        title: 'QNAP NAS',
      );
      final ownerUpcomingPickupItem = ownerQaItem(
        id: 'qa_owner_item_upcoming_pickup_$userId',
        title: 'QA Werkzeug Abholung durch Mieter',
      );
      final ownerUpcomingDeliveryItem = ownerQaItem(
        id: 'qa_owner_item_upcoming_delivery_$userId',
        title: 'QA Monitor Lieferung durch Vermieter',
        offersDeliveryAtDropoff: true,
      );
      final ownerRunningItem = ownerQaItem(
        id: 'qa_owner_item_running_$userId',
        title: 'QA Stativ laufende Anmietung',
        offersDeliveryAtDropoff: true,
        offersPickupAtReturn: true,
      );
      final ownerCompletedCleanItem = ownerQaItem(
        id: 'qa_owner_item_completed_clean_$userId',
        title: 'QA Kamera abgeschlossen',
      );
      final ownerCompletedProblemItem = ownerQaItem(
        id: 'qa_owner_item_completed_problem_$userId',
        title: 'QA E-Scooter Prüfung läuft',
      );

      final User? sharedOwner = users
          .where((u) => u.id == 'u1')
          .cast<User?>()
          .firstWhere((u) => u != null, orElse: () => null);
      final User? sharedRenter = users
          .where((u) => u.id == 'u2')
          .cast<User?>()
          .firstWhere((u) => u != null, orElse: () => null);
      final Item? sharedOwnerTemplate = sharedOwner == null
          ? null
          : (firstOwnedByWithPhoto(sharedOwner.id) ??
              firstOwnedBy(sharedOwner.id));
      final sharedItem = (sharedOwner != null && sharedRenter != null)
          ? Item(
              id: 'qa_shared_item_u1_u2',
              ownerId: sharedOwner.id,
              title: 'QA Gemeinsame Übergabe Abholung',
              description:
                  'Lokaler QA-Fixture-Artikel für den gemeinsamen Owner↔Renter-Verifikationsfall.',
              categoryId: (sharedOwnerTemplate ?? acceptedItem).categoryId,
              subcategory: (sharedOwnerTemplate ?? acceptedItem).subcategory,
              tags: (sharedOwnerTemplate ?? acceptedItem).tags,
              pricePerDay: (sharedOwnerTemplate ?? acceptedItem).pricePerDay,
              currency: (sharedOwnerTemplate ?? acceptedItem).currency,
              priceUnit: (sharedOwnerTemplate ?? acceptedItem).priceUnit,
              priceRaw: (sharedOwnerTemplate ?? acceptedItem).priceRaw,
              autoApplyDiscounts:
                  (sharedOwnerTemplate ?? acceptedItem).autoApplyDiscounts,
              longRentalDiscounts:
                  (sharedOwnerTemplate ?? acceptedItem).longRentalDiscounts,
              photos: (sharedOwnerTemplate ?? acceptedItem).photos,
              locationText: (sharedOwnerTemplate ?? acceptedItem).locationText,
              lat: (sharedOwnerTemplate ?? acceptedItem).lat,
              lng: (sharedOwnerTemplate ?? acceptedItem).lng,
              geohash: (sharedOwnerTemplate ?? acceptedItem).geohash,
              condition: (sharedOwnerTemplate ?? acceptedItem).condition,
              minDays: (sharedOwnerTemplate ?? acceptedItem).minDays,
              maxDays: (sharedOwnerTemplate ?? acceptedItem).maxDays,
              createdAt: now.subtract(const Duration(days: 1, hours: 2)),
              isActive: true,
              verificationStatus:
                  (sharedOwnerTemplate ?? acceptedItem).verificationStatus,
              city: (sharedOwnerTemplate ?? acceptedItem).city,
              country: (sharedOwnerTemplate ?? acceptedItem).country,
              status: 'active',
              timesLent: (sharedOwnerTemplate ?? acceptedItem).timesLent,
              offersDeliveryAtDropoff: false,
              offersPickupAtReturn: false,
              offersExpressAtDropoff:
                  (sharedOwnerTemplate ?? acceptedItem).offersExpressAtDropoff,
              maxDeliveryKmAtDropoff:
                  (sharedOwnerTemplate ?? acceptedItem).maxDeliveryKmAtDropoff,
              maxPickupKmAtReturn:
                  (sharedOwnerTemplate ?? acceptedItem).maxPickupKmAtReturn,
              cancellationPolicy:
                  (sharedOwnerTemplate ?? acceptedItem).cancellationPolicy,
            )
          : null;

      final acceptedRequest = RentalRequest(
        id: 'qa_req_accepted_$userId',
        itemId: acceptedItem.id,
        ownerId: acceptedItem.ownerId,
        renterId: userId,
        start: now.add(const Duration(days: 2, hours: 4)),
        end: now.add(const Duration(days: 5, hours: 2)),
        status: 'accepted',
        message:
            'QA PS5 Lieferung — bestätigter Kommend-Testfall für den lokalen Screen-Audit.',
        deliveryAddressLine: 'Torstraße 17',
        deliveryCity: 'Berlin',
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        quotedTotalRenter: 89.0,
        quotedSubtitle: 'inkl. SIT-Servicegebühr',
      );
      final runningRequest = RentalRequest(
        id: 'qa_req_running_$userId',
        itemId: runningItem.id,
        ownerId: runningItem.ownerId,
        renterId: userId,
        start: now.subtract(const Duration(days: 1, hours: 2)),
        end: now.add(const Duration(days: 2, hours: 6)),
        status: 'running',
        message:
            'qa_booking_running — laufender Audit-Fall mit sichtbarer Abholung und Rückgabe.',
        deliveryAddressLine: 'Rosenthaler Straße 44',
        deliveryCity: 'Berlin',
        createdAt: now.subtract(const Duration(days: 3)),
        handoverConfirmation: {
          'confirmedAt':
              now.subtract(const Duration(days: 1, hours: 3)).toIso8601String(),
          'method': 'manual',
        },
        quotedTotalRenter: 126.0,
        quotedSubtitle: 'inkl. SIT-Servicegebühr',
      );
      final completedRequest = RentalRequest(
        id: 'qa_req_completed_$userId',
        itemId: completedItem.id,
        ownerId: completedItem.ownerId,
        renterId: userId,
        start: now.subtract(const Duration(days: 10)),
        end: now.subtract(const Duration(days: 7, hours: 3)),
        status: 'completed',
        message:
            'Danke nochmal — das Licht hat für das Shooting perfekt funktioniert.',
        createdAt: now.subtract(const Duration(days: 12)),
        returnConfirmation: {
          'confirmedAt':
              now.subtract(const Duration(days: 7, hours: 2)).toIso8601String(),
          'method': 'manual',
        },
        quotedTotalRenter: 74.0,
        quotedSubtitle: 'historischer Testfall',
      );
      final needsReviewRequest = RentalRequest(
        id: 'qa_req_review_$userId',
        itemId: completedItem.id,
        ownerId: completedItem.ownerId,
        renterId: userId,
        start: now.subtract(const Duration(days: 6)),
        end: now.subtract(const Duration(days: 4, hours: 4)),
        status: 'completed',
        message:
            'QA E-Scooter Prüfung läuft — abgeschlossener Vorgang mit Review-Hold.',
        createdAt: now.subtract(const Duration(days: 6, hours: 8)),
        needsReview: true,
        reviewReason: 'Zusätzliche Prüfung nach Rückgabe',
        reviewSource: 'qa_demo_seed',
        reviewRequestedAt: now.subtract(const Duration(days: 4, hours: 2)),
        quotedTotalRenter: 61.0,
        quotedSubtitle: 'mit Review-Hold Testfall',
      );
      final pendingRequest = RentalRequest(
        id: 'qa_req_pending_$userId',
        itemId: acceptedItem.id,
        ownerId: acceptedItem.ownerId,
        renterId: userId,
        start: now.add(const Duration(days: 4)),
        end: now.add(const Duration(days: 6, hours: 8)),
        status: 'pending',
        message: 'Wäre Abholung am Freitag gegen 18:30 für dich passend?',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 20)),
        quotedTotalRenter: 58.0,
        quotedSubtitle: 'Anfrage noch offen',
      );
      final ownerPendingRequest = RentalRequest(
        id: 'qa_owner_pending_$userId',
        itemId: ownerPendingItem.id,
        ownerId: userId,
        renterId: renterA.id,
        start: now.add(const Duration(days: 3, hours: 6)),
        end: now.add(const Duration(days: 5, hours: 12)),
        status: 'pending',
        message: 'Neue Mietanfrage für den lokalen Owner-Audit.',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 35)),
        quotedTotalRenter: 67.0,
        quotedSubtitle: 'eingehende Mietanfrage',
      );
      final ownerUpcomingPickupRequest = RentalRequest(
        id: 'qa_owner_upcoming_pickup_$userId',
        itemId: ownerUpcomingPickupItem.id,
        ownerId: userId,
        renterId: ownerA.id,
        start: now.add(const Duration(days: 1, hours: 4)),
        end: now.add(const Duration(days: 3, hours: 4)),
        status: 'accepted',
        message:
            'Bestätigte Owner-Anmietung mit Selbstabholung durch den Mieter.',
        createdAt: now.subtract(const Duration(days: 1, hours: 6)),
        ownerDeliversAtDropoffChosen: false,
        quotedTotalRenter: 82.0,
        quotedSubtitle: 'kommend / abholung',
      );
      final ownerUpcomingDeliveryRequest = RentalRequest(
        id: 'qa_owner_upcoming_delivery_$userId',
        itemId: ownerUpcomingDeliveryItem.id,
        ownerId: userId,
        renterId: ownerB.id,
        start: now.add(const Duration(days: 2, hours: 2)),
        end: now.add(const Duration(days: 4, hours: 8)),
        status: 'accepted',
        message:
            'Bestätigte Owner-Anmietung mit Lieferung durch den Vermieter.',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        ownerDeliversAtDropoffChosen: true,
        quotedTotalRenter: 119.0,
        quotedSubtitle: 'kommend / lieferung',
      );
      final ownerRunningRequest = RentalRequest(
        id: 'qa_owner_running_$userId',
        itemId: ownerRunningItem.id,
        ownerId: userId,
        renterId: ownerC.id,
        start: now.subtract(const Duration(days: 1, hours: 3)),
        end: now.add(const Duration(days: 1, hours: 10)),
        status: 'running',
        message: 'Laufende Owner-Anmietung für den Audit.',
        createdAt: now.subtract(const Duration(days: 2, hours: 6)),
        ownerDeliversAtDropoffChosen: true,
        ownerPicksUpAtReturnChosen: true,
        handoverConfirmation: {
          'confirmedAt':
              now.subtract(const Duration(days: 1, hours: 4)).toIso8601String(),
          'method': 'manual',
        },
        quotedTotalRenter: 134.0,
        quotedSubtitle: 'laufend',
      );
      final ownerCompletedCleanRequest = RentalRequest(
        id: 'qa_owner_completed_clean_$userId',
        itemId: ownerCompletedCleanItem.id,
        ownerId: userId,
        renterId: renterA.id,
        start: now.subtract(const Duration(days: 8)),
        end: now.subtract(const Duration(days: 5, hours: 2)),
        status: 'completed',
        message: 'Sauber abgeschlossene Owner-Anmietung für den Audit.',
        createdAt: now.subtract(const Duration(days: 9, hours: 1)),
        returnConfirmation: {
          'confirmedAt':
              now.subtract(const Duration(days: 5, hours: 1)).toIso8601String(),
          'method': 'manual',
        },
        needsReview: false,
        quotedTotalRenter: 73.0,
        quotedSubtitle: 'abgeschlossen / clean',
      );
      final ownerCompletedProblemRequest = RentalRequest(
        id: 'qa_owner_completed_problem_$userId',
        itemId: ownerCompletedProblemItem.id,
        ownerId: userId,
        renterId: ownerB.id,
        start: now.subtract(const Duration(days: 6, hours: 4)),
        end: now.subtract(const Duration(days: 3, hours: 6)),
        status: 'completed',
        message: 'Owner-Review-Hold-Fall für den Audit.',
        createdAt: now.subtract(const Duration(days: 6, hours: 8)),
        returnConfirmation: {
          'confirmedAt':
              now.subtract(const Duration(days: 3, hours: 5)).toIso8601String(),
          'method': 'manual',
        },
        needsReview: true,
        reviewReason: 'Zusätzliche Prüfung nach Rückgabe',
        reviewSource: 'qa_demo_seed',
        reviewRequestedAt: now.subtract(const Duration(days: 3, hours: 4)),
        quotedTotalRenter: 96.0,
        quotedSubtitle: 'abgeschlossen / prüfung',
      );

      final sharedOwnerRenterRequest =
          (sharedOwner != null && sharedRenter != null && sharedItem != null)
              ? RentalRequest(
                  id: 'qa_shared_request_u1_u2',
                  itemId: sharedItem.id,
                  ownerId: sharedOwner.id,
                  renterId: sharedRenter.id,
                  start: now.add(const Duration(days: 1, hours: 3)),
                  end: now.add(const Duration(days: 3, hours: 2)),
                  status: 'accepted',
                  message:
                      'Gemeinsamer QA-Fall für Owner↔Renter-Live-Verifikation mit Abholung durch den Mieter.',
                  createdAt: now.subtract(const Duration(hours: 20)),
                  ownerDeliversAtDropoffChosen: false,
                  quotedTotalRenter: 88.0,
                  quotedSubtitle: 'shared qa / pickup',
                )
              : null;

      final itemJson = prefs.getString(_itemsKey);
      final List<dynamic> itemList = itemJson != null && itemJson.isNotEmpty
          ? (jsonDecode(itemJson) as List)
          : <dynamic>[];
      itemList.removeWhere((e) {
        if (e is! Map) return false;
        final id = (e['id'] ?? '').toString();
        return id.startsWith('qa_owner_item_') &&
            ((e['ownerId'] ?? '').toString() == userId);
      });
      itemList.removeWhere((e) {
        if (e is! Map) return false;
        return (e['id'] ?? '').toString() == 'qa_shared_item_u1_u2';
      });
      itemList.addAll([
        ownerPendingItem.toJson(),
        ownerUpcomingPickupItem.toJson(),
        ownerUpcomingDeliveryItem.toJson(),
        ownerRunningItem.toJson(),
        ownerCompletedCleanItem.toJson(),
        ownerCompletedProblemItem.toJson(),
        if (sharedItem != null) sharedItem.toJson(),
      ]);
      await prefs.setString(_itemsKey, jsonEncode(itemList));

      final requests = await _getAllRentalRequests();
      requests.removeWhere((r) {
        final isRenterOrOwnerQa = r.id.startsWith('qa_req_') &&
            (r.renterId == userId || r.ownerId == userId);
        final isOwnerQa = r.id.startsWith('qa_owner_') && r.ownerId == userId;
        return isRenterOrOwnerQa || isOwnerQa;
      });
      requests.removeWhere((r) => r.id == 'qa_shared_request_u1_u2');
      requests.addAll([
        acceptedRequest,
        runningRequest,
        completedRequest,
        needsReviewRequest,
        pendingRequest,
        ownerPendingRequest,
        ownerUpcomingPickupRequest,
        ownerUpcomingDeliveryRequest,
        ownerRunningRequest,
        ownerCompletedCleanRequest,
        ownerCompletedProblemRequest,
        if (sharedOwnerRenterRequest != null) sharedOwnerRenterRequest,
      ]);
      await _saveAllRentalRequests(requests);

      final rawThreads = await _readMessageThreads(prefs);
      final List<dynamic> threadList =
          rawThreads != null && rawThreads.isNotEmpty
              ? (jsonDecode(rawThreads) as List)
              : <dynamic>[];
      threadList.removeWhere((e) {
        if (e is! Map) return false;
        final id = (e['id'] ?? '').toString();
        return id.startsWith('qa_thread_') ||
            id.startsWith('qa_support_thread_');
      });

      MessageThread buildThread({
        required String id,
        required String requestId,
        required String itemId,
        required String itemTitle,
        required String user1Id,
        required String user2Id,
        String? threadType,
        String? bookingStatus,
        DateTime? handoverAt,
        DateTime? returnAt,
        bool? otherUserOnline,
        DateTime? otherUserLastActive,
        List<String> archivedForUserIds = const <String>[],
        required List<Message> messages,
        required DateTime createdAt,
        DateTime? lastMessageAt,
      }) =>
          MessageThread(
            id: id,
            requestId: requestId,
            itemId: itemId,
            itemTitle: itemTitle,
            user1Id: user1Id,
            user2Id: user2Id,
            threadType: threadType,
            bookingStatus: bookingStatus,
            handoverAt: handoverAt,
            returnAt: returnAt,
            otherUserOnline: otherUserOnline,
            otherUserLastActive: otherUserLastActive,
            archivedForUserIds: archivedForUserIds,
            messages: messages,
            createdAt: createdAt,
            lastMessageAt: lastMessageAt,
          );

      final acceptedMsgs = <Message>[
        Message(
          id: 'qa_msg_acc_1',
          senderId: 'system',
          text: 'Buchung bestätigt — ihr könnt jetzt die Übergabe planen.',
          timestamp: now.subtract(const Duration(hours: 9)),
          isRead: true,
        ),
        Message(
          id: 'qa_msg_acc_2',
          senderId: ownerA.id,
          text:
              'Hi Walid, ich habe alles vorbereitet. Passt dir Donnerstag 18:30 für die Übergabe?',
          timestamp: now.subtract(const Duration(hours: 8, minutes: 40)),
          isRead: true,
        ),
        Message(
          id: 'qa_msg_acc_3',
          senderId: userId,
          text: 'Ja, perfekt. Ich bin pünktlich da.',
          timestamp: now.subtract(const Duration(hours: 8, minutes: 12)),
          isRead: true,
        ),
        Message(
          id: 'qa_msg_acc_4',
          senderId: ownerA.id,
          text:
              'Super — die Adresse bleibt bis kurz vor der Übergabe geschützt sichtbar. Ich schicke dir rechtzeitig die letzten Details.',
          timestamp: now.subtract(const Duration(hours: 7, minutes: 50)),
          isRead: false,
        ),
      ];
      final runningMsgs = <Message>[
        Message(
          id: 'qa_msg_run_1',
          senderId: 'system',
          text:
              'Übergabe bestätigt — dieser Chat eignet sich für Rückgabezeit und kurze Abstimmung.',
          timestamp: now.subtract(const Duration(days: 1, hours: 4)),
          isRead: true,
        ),
        Message(
          id: 'qa_msg_run_2',
          senderId: ownerB.id,
          text: 'Zeitvorschlag Rückgabe: Samstag 11:00 vor dem Studioeingang.',
          timestamp: now.subtract(const Duration(hours: 20)),
          isRead: true,
        ),
        Message(
          id: 'qa_msg_run_3',
          senderId: userId,
          text: 'Klappt. Ich bin 10 Minuten früher da.',
          timestamp: now.subtract(const Duration(hours: 19, minutes: 42)),
          isRead: true,
        ),
        Message(
          id: 'qa_msg_run_4',
          senderId: 'system',
          text:
              'Hinweis: Teile sensible Adressdaten nur im vorgesehenen Übergabe-Kontext. Der Kernprozess bleibt über ShareItToo dokumentiert.',
          timestamp: now.subtract(const Duration(hours: 19, minutes: 10)),
          isRead: true,
        ),
        Message(
          id: 'qa_msg_run_5',
          senderId: ownerB.id,
          text:
              'Falls du unterwegs festhängst, gib einfach kurz Bescheid. Ich kann notfalls 15 Minuten warten, damit die Rückgabe trotzdem sauber dokumentiert bleibt und wir keine Hektik kurz vor Schluss haben.',
          timestamp: now.subtract(const Duration(hours: 18, minutes: 55)),
          isRead: false,
        ),
      ];
      final completedMsgs = <Message>[
        Message(
          id: 'qa_msg_compl_1',
          senderId: 'system',
          text:
              'Diese Miete ist abgeschlossen. Bewertungen und Dokumentation bleiben weiterhin einsehbar.',
          timestamp: now.subtract(const Duration(days: 7, hours: 3)),
          isRead: true,
        ),
        Message(
          id: 'qa_msg_compl_2',
          senderId: ownerC.id,
          text: 'Danke dir — alles kam vollständig zurück.',
          timestamp: now.subtract(
            const Duration(days: 7, hours: 2, minutes: 40),
          ),
          isRead: true,
        ),
        Message(
          id: 'qa_msg_compl_3',
          senderId: userId,
          text: 'Top, danke für die unkomplizierte Übergabe.',
          timestamp: now.subtract(
            const Duration(days: 7, hours: 2, minutes: 10),
          ),
          isRead: true,
        ),
      ];
      final supportMsgs = <Message>[
        Message(
          id: 'qa_msg_sup_1',
          senderId: 'support',
          text: 'Hallo Walid, wir haben dein Support-Thema aufgenommen.',
          timestamp: now.subtract(const Duration(hours: 6)),
          isRead: true,
        ),
        Message(
          id: 'qa_msg_sup_2',
          senderId: userId,
          text:
              'Danke. Ich wollte nur prüfen, ob die neue Benachrichtigungsansicht sauber reagiert.',
          timestamp: now.subtract(const Duration(hours: 5, minutes: 30)),
          isRead: true,
        ),
        Message(
          id: 'qa_msg_sup_3',
          senderId: 'support',
          text:
              'Perfekt — dieser QA-Fall ist bewusst lokal markiert und verschickt nichts extern.',
          timestamp: now.subtract(const Duration(hours: 5, minutes: 8)),
          isRead: false,
        ),
      ];
      final archivedMsgs = <Message>[
        Message(
          id: 'qa_msg_arch_1',
          senderId: ownerA.id,
          text:
              'Das ist ein archivierter Testfall mit langem Vorschautext, damit die Listenansicht Zeilenumbruch, Abschneiden und Status-Kontext sauber zeigt, auch wenn ein Artikelbild gerade nicht vorhanden ist.',
          timestamp: now.subtract(const Duration(days: 2, hours: 5)),
          isRead: true,
        ),
      ];

      final sharedMsgs = <Message>[
        Message(
          id: 'qa_msg_shared_1',
          senderId: 'system',
          text:
              'Gemeinsamer QA-Fall aktiviert — beide Seiten sollen denselben Thread und dieselbe Buchung sehen.',
          timestamp: now.subtract(const Duration(hours: 18)),
          isRead: true,
        ),
        if (sharedOwner != null)
          Message(
            id: 'qa_msg_shared_2',
            senderId: sharedOwner.id,
            text: 'Perfekt — ich bereite die Übergabe für morgen vor.',
            timestamp: now.subtract(const Duration(hours: 17, minutes: 24)),
            isRead: true,
          ),
        if (sharedRenter != null)
          Message(
            id: 'qa_msg_shared_3',
            senderId: sharedRenter.id,
            text: 'Top, ich hole den Artikel selbst ab und bestätige vor Ort.',
            timestamp: now.subtract(const Duration(hours: 17, minutes: 2)),
            isRead: true,
          ),
      ];

      final acceptedThread = buildThread(
        id: 'qa_thread_accepted_$userId',
        requestId: acceptedRequest.id,
        itemId: acceptedItem.id,
        itemTitle: acceptedItem.title,
        user1Id: userId,
        user2Id: acceptedItem.ownerId,
        bookingStatus: 'accepted',
        handoverAt: acceptedRequest.start.subtract(const Duration(hours: 1)),
        returnAt: acceptedRequest.end.subtract(const Duration(hours: 2)),
        otherUserOnline: true,
        messages: acceptedMsgs,
        createdAt: now.subtract(const Duration(days: 1)),
        lastMessageAt: acceptedMsgs.last.timestamp,
      );
      final runningThread = buildThread(
        id: 'qa_thread_running_$userId',
        requestId: runningRequest.id,
        itemId: runningItem.id,
        itemTitle: runningItem.title,
        user1Id: userId,
        user2Id: runningItem.ownerId,
        bookingStatus: 'running',
        handoverAt: runningRequest.start.subtract(const Duration(hours: 1)),
        returnAt: runningRequest.end.subtract(const Duration(hours: 3)),
        otherUserOnline: false,
        otherUserLastActive: now.subtract(const Duration(minutes: 14)),
        messages: runningMsgs,
        createdAt: now.subtract(const Duration(days: 3, hours: 1)),
        lastMessageAt: runningMsgs.last.timestamp,
      );
      final completedThread = buildThread(
        id: 'qa_thread_completed_$userId',
        requestId: completedRequest.id,
        itemId: completedItem.id,
        itemTitle: completedItem.title,
        user1Id: userId,
        user2Id: completedItem.ownerId,
        bookingStatus: 'completed',
        otherUserOnline: false,
        otherUserLastActive: now.subtract(const Duration(days: 6)),
        messages: completedMsgs,
        createdAt: now.subtract(const Duration(days: 8)),
        lastMessageAt: completedMsgs.last.timestamp,
      );
      final supportThread = buildThread(
        id: 'qa_support_thread_$userId',
        requestId: 'qa_support_request_$userId',
        itemId: 'support',
        itemTitle: 'Support',
        user1Id: userId,
        user2Id: 'support',
        threadType: 'support',
        otherUserOnline: true,
        messages: supportMsgs,
        createdAt: now.subtract(const Duration(hours: 7)),
        lastMessageAt: supportMsgs.last.timestamp,
      );
      final archivedThread = buildThread(
        id: 'qa_thread_archived_$userId',
        requestId: needsReviewRequest.id,
        itemId: 'qa_missing_item_$userId',
        itemTitle: 'Objektiv ohne Bildvorschau',
        user1Id: userId,
        user2Id: needsReviewRequest.ownerId,
        bookingStatus: 'completed',
        otherUserOnline: false,
        otherUserLastActive: now.subtract(const Duration(days: 2, hours: 1)),
        archivedForUserIds: [userId],
        messages: archivedMsgs,
        createdAt: now.subtract(const Duration(days: 2, hours: 6)),
        lastMessageAt: archivedMsgs.last.timestamp,
      );

      final sharedThread =
          (sharedOwnerRenterRequest != null && sharedItem != null)
              ? buildThread(
                  id: 'qa_shared_thread_u1_u2',
                  requestId: sharedOwnerRenterRequest.id,
                  itemId: sharedItem.id,
                  itemTitle: sharedItem.title,
                  user1Id: sharedOwner!.id,
                  user2Id: sharedRenter!.id,
                  bookingStatus: 'accepted',
                  handoverAt: sharedOwnerRenterRequest.start
                      .subtract(const Duration(hours: 1)),
                  returnAt: sharedOwnerRenterRequest.end
                      .subtract(const Duration(hours: 2)),
                  otherUserOnline: true,
                  messages: sharedMsgs,
                  createdAt: now.subtract(const Duration(hours: 19)),
                  lastMessageAt: sharedMsgs.last.timestamp,
                )
              : null;

      threadList.removeWhere((e) {
        if (e is! Map) return false;
        return (e['id'] ?? '').toString() == 'qa_shared_thread_u1_u2';
      });
      threadList.addAll([
        acceptedThread.toJson(),
        runningThread.toJson(),
        completedThread.toJson(),
        supportThread.toJson(),
        archivedThread.toJson(),
        if (sharedThread != null) sharedThread.toJson(),
      ]);
      await _persistMessageThreads(prefs, threadList);

      final rawNotifs = prefs.getString(_notificationsKey);
      final List<dynamic> notifList = rawNotifs != null && rawNotifs.isNotEmpty
          ? (jsonDecode(rawNotifs) as List)
          : <dynamic>[];
      notifList.removeWhere((e) {
        if (e is! Map) return false;
        return ((e['id'] ?? '').toString().startsWith('qa_notif_')) ||
            (((e['entityId'] ?? '').toString().startsWith('qa_')) &&
                (e['userId']?.toString() == userId));
      });

      Map<String, dynamic> qaNotif({
        required String id,
        required String category,
        required int priority,
        required String title,
        required String body,
        required String entityType,
        required String entityId,
        required DateTime ts,
        bool read = false,
        bool critical = false,
        String? ctaLabel,
        Map<String, dynamic>? payload,
      }) =>
          {
            'id': id,
            'userId': userId,
            'category': category,
            'priority': priority,
            'title': title,
            'body': body,
            'entityType': entityType,
            'entityId': entityId,
            'ctaLabel': ctaLabel,
            ...?payload,
            'critical': critical,
            'archived': false,
            'ts': ts.toIso8601String(),
            'read': read,
          };

      notifList.addAll([
        qaNotif(
          id: 'qa_notif_pending_$userId',
          category: 'bookings',
          priority: 2,
          title: 'Neue Mietanfrage eingegangen',
          body:
              '${renterA.displayName} möchte „${ownerPendingItem.title}“ vom ${ownerPendingRequest.start.day.toString().padLeft(2, '0')}.${ownerPendingRequest.start.month.toString().padLeft(2, '0')}.${ownerPendingRequest.start.year} bis ${ownerPendingRequest.end.day.toString().padLeft(2, '0')}.${ownerPendingRequest.end.month.toString().padLeft(2, '0')}.${ownerPendingRequest.end.year} mieten.',
          entityType: 'booking',
          entityId: ownerPendingRequest.id,
          ts: now.subtract(const Duration(hours: 2, minutes: 10)),
          read: false,
          ctaLabel: 'Anfrage prüfen',
          payload: {
            'requestId': ownerPendingRequest.id,
            'listingId': ownerPendingItem.id,
            'counterpartyUserId': renterA.id,
            'counterpartyName': renterA.displayName,
            'role': 'owner',
          },
        ),
        qaNotif(
          id: 'qa_notif_accepted_$userId',
          category: 'bookings',
          priority: 2,
          title: 'Anfrage bestätigt',
          body:
              'Die Buchung für „${acceptedItem.title}“ ist bestätigt. Prüfe die Abstimmung im Chat.',
          entityType: 'booking',
          entityId: acceptedRequest.id,
          ts: now.subtract(const Duration(hours: 8, minutes: 30)),
          read: false,
          ctaLabel: 'Buchung öffnen',
        ),
        qaNotif(
          id: 'qa_notif_message_$userId',
          category: 'messages',
          priority: 3,
          title: 'Neue Nachricht erhalten',
          body:
              'Mila hat dir zur Rückgabe noch eine kurze Nachricht geschickt.',
          entityType: 'thread',
          entityId: runningThread.id,
          ts: now.subtract(const Duration(hours: 1, minutes: 12)),
          read: false,
          ctaLabel: 'Chat öffnen',
        ),
        qaNotif(
          id: 'qa_notif_handover_$userId',
          category: 'bookings',
          priority: 2,
          title: 'Übergabe-Erinnerung',
          body:
              'Die bestätigte Übergabe für „${acceptedItem.title}“ startet heute Abend.',
          entityType: 'booking',
          entityId: acceptedRequest.id,
          ts: now.subtract(const Duration(hours: 5, minutes: 40)),
          read: true,
          ctaLabel: 'Details ansehen',
        ),
        qaNotif(
          id: 'qa_notif_return_$userId',
          category: 'bookings',
          priority: 2,
          title: 'Rückgabe im Blick behalten',
          body:
              'Deine laufende Miete endet bald. Prüfe die geplante Rückgabezeit im Detail.',
          entityType: 'booking',
          entityId: runningRequest.id,
          ts: now.subtract(const Duration(hours: 3, minutes: 5)),
          read: false,
          ctaLabel: 'Rückgabe prüfen',
        ),
        qaNotif(
          id: 'qa_notif_payment_$userId',
          category: 'payments',
          priority: 2,
          title: 'Auszahlung & Zahlungsmittel',
          body:
              'Dieser lokale QA-Fall zeigt dir die Zahlungs- und Auszahlungseinstiege ohne echte Bewegung.',
          entityType: 'payment',
          entityId: 'payment_methods',
          ts: now.subtract(const Duration(days: 1, hours: 2)),
          read: true,
          ctaLabel: 'Zahlungen öffnen',
        ),
        qaNotif(
          id: 'qa_notif_security_$userId',
          category: 'security',
          priority: 1,
          title: 'Verifizierung prüfen',
          body:
              'Teste hier die Sicherheits- und Verifizierungsoberfläche mit einer klaren CTA.',
          entityType: 'verification',
          entityId: 'qa_verification',
          ts: now.subtract(const Duration(days: 1, hours: 6)),
          read: false,
          critical: true,
          ctaLabel: 'Sicherheit öffnen',
        ),
        qaNotif(
          id: 'qa_notif_support_$userId',
          category: 'support',
          priority: 3,
          title: 'Support-Status aktualisiert',
          body:
              'Der lokale QA-Supportfall hat neue Informationen für dich bereit.',
          entityType: 'support',
          entityId: 'qa_support_case',
          ts: now.subtract(const Duration(hours: 4, minutes: 15)),
          read: true,
          ctaLabel: 'Support öffnen',
        ),
        qaNotif(
          id: 'qa_notif_review_$userId',
          category: 'reviews',
          priority: 4,
          title: 'Vorgang wartet auf Prüfung',
          body:
              'Ein abgeschlossener Testfall bleibt vorerst im Review-Hold, damit du diese Oberfläche prüfen kannst.',
          entityType: 'booking',
          entityId: needsReviewRequest.id,
          ts: now.subtract(const Duration(days: 2, hours: 3)),
          read: false,
          ctaLabel: 'Fall öffnen',
        ),
      ]);

      await prefs.setString(_notificationsKey, jsonEncode(notifList));
      await prefs.setBool(key, true);
    } catch (e) {
      debugPrint(
        '[DataService] _ensureQaMessagesAndNotificationsForUserOnce failed: $e',
      );
    } finally {
      _qaSeedUsersInProgress.remove(userId);
    }
  }

  static Future<void> setCurrentUser(User user) async {
    if (QaRuntimeService.isEnabled) {
      QaRuntimeService.setRuntimeUserJson(user.toJson());
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    var effectiveUser = user;
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final remote = await BackendRepository.updateCurrentProfile(
        user.toJson(),
      );
      effectiveUser = User.fromJson(remote);
    }
    await prefs.setString(
      _currentUserKey,
      jsonEncode(effectiveUser.toJson()),
    );
    await _upsertCachedUser(prefs, effectiveUser);
  }

  static Future<void> clearCurrentUser() async {
    if (QaRuntimeService.isEnabled) {
      QaRuntimeService.clearRuntimeUser();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  static Future<void> syncCurrentUserForSessionEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return;

    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final remote = await BackendRepository.getCurrentProfile();
      final user = User.fromJson(remote);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
      await _upsertCachedUser(prefs, user);
      return;
    }

    final users = await getUsers();
    User? match;
    for (final user in users) {
      if (user.email.trim().toLowerCase() == normalized) {
        match = user;
        break;
      }
    }

    match ??= normalized == 'demo@shareittoo.app' && users.isNotEmpty
        ? users.first
        : null;

    if (match != null) {
      await setCurrentUser(match);
    }
  }

  static Future<void> _upsertCachedUser(
    SharedPreferences prefs,
    User user,
  ) async {
    List<dynamic> users = <dynamic>[];
    final raw = prefs.getString(_usersKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) users = decoded;
      } catch (_) {}
    }
    final index = users.indexWhere(
      (entry) => entry is Map && entry['id']?.toString() == user.id,
    );
    if (index >= 0) {
      users[index] = user.toJson();
    } else {
      users.add(user.toJson());
    }
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  static Future<void> clearCurrentUserAndMarkDeleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_accountDeletedKey, true);
      await prefs.remove(_currentUserKey);
      debugPrint(
        '[DataService] Account marked deleted and current user cleared',
      );
    } catch (e) {
      debugPrint('[DataService] clearCurrentUserAndMarkDeleted failed: $e');
    }
  }

  static Future<void> anonymizeAndDeactivateUser({
    required String userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);
      if (usersJson == null || usersJson.isEmpty) return;
      final decoded = jsonDecode(usersJson);
      if (decoded is! List) return;

      final now = DateTime.now();
      bool mutated = false;
      for (int i = 0; i < decoded.length; i++) {
        if (decoded[i] is! Map) continue;
        final map = Map<String, dynamic>.from(decoded[i] as Map);
        if (map['id']?.toString() != userId) continue;

        map['displayName'] = 'Gelöschter Nutzer';
        map['photoURL'] = null;
        map['bio'] = null;
        map['interests'] = const <String>[];
        map['languages'] = const <String>[];
        map['email'] = 'deleted+$userId@shareittoo.invalid';
        map['phone'] = null;
        map['emailVerified'] = false;
        map['phoneVerified'] = false;
        map['isVerified'] = false;
        map['workTitle'] = null;
        map['hobbies'] = null;
        map['homeLocation'] = null;
        map['favoriteSong'] = null;
        map['showWork'] = false;
        map['showHobbies'] = false;
        map['showHomeLocation'] = false;
        map['showBioPublic'] = false;
        map['showFavoriteSong'] = false;
        map['homeLat'] = null;
        map['homeLng'] = null;
        map['birthDate'] = null;
        map['socialX'] = null;
        map['socialFacebook'] = null;
        map['socialInstagram'] = null;
        map['socialTiktok'] = null;
        map['socialSnapchat'] = null;

        map['addressStreet'] = null;
        map['addressHouseNumber'] = null;
        map['addressPostalCode'] = null;
        map['addressCity'] = null;
        map['addressCountry'] = null;
        map['addressExtra'] = null;

        map['isDeactivated'] = true;
        map['deactivatedAt'] = now.toIso8601String();

        decoded[i] = map;
        mutated = true;
        break;
      }

      if (mutated) {
        await prefs.setString(_usersKey, jsonEncode(decoded));
        debugPrint('[DataService] User $userId anonymized/deactivated');
      }
    } catch (e) {
      debugPrint('[DataService] anonymizeAndDeactivateUser failed: $e');
    }
  }

  static Future<void> deactivateAllListingsForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getString(_itemsKey);
      if (itemsJson == null || itemsJson.isEmpty) return;
      final decoded = jsonDecode(itemsJson);
      if (decoded is! List) return;

      bool mutated = false;
      for (int i = 0; i < decoded.length; i++) {
        if (decoded[i] is! Map) continue;
        final map = Map<String, dynamic>.from(decoded[i] as Map);
        if (map['ownerId']?.toString() != userId) continue;

        if ((map['status']?.toString() ?? 'active') == 'ended') continue;
        map['status'] = 'ended';
        map['isActive'] = false;
        map['endedAt'] = DateTime.now().toIso8601String();
        decoded[i] = map;
        mutated = true;
      }

      if (mutated) {
        await prefs.setString(_itemsKey, jsonEncode(decoded));
        debugPrint('[DataService] Deactivated all listings for user $userId');
      }
    } catch (e) {
      debugPrint('[DataService] deactivateAllListingsForUser failed: $e');
    }
  }

  static Future<void> archiveAllMessageThreadsForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = BackendConfig.enabled && !QaRuntimeService.isEnabled
          ? prefs.getString(_messageThreadsKey)
          : await _readMessageThreads(prefs);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      bool mutated = false;
      for (int i = 0; i < decoded.length; i++) {
        if (decoded[i] is! Map) continue;
        final map = Map<String, dynamic>.from(decoded[i] as Map);
        final u1 = map['user1Id']?.toString();
        final u2 = map['user2Id']?.toString();
        if (u1 != userId && u2 != userId) continue;

        final archived = (map['archivedForUserIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
        if (!archived.contains(userId)) {
          archived.add(userId);
          map['archivedForUserIds'] = archived;
          decoded[i] = map;
          mutated = true;
        }
      }

      if (mutated) {
        await _persistMessageThreads(prefs, decoded);
        debugPrint(
          '[DataService] Archived all message threads for user $userId',
        );
      }
    } catch (e) {
      debugPrint('[DataService] archiveAllMessageThreadsForUser failed: $e');
    }
  }

  static const String _savedItemsKey = 'saved_item_ids';

  static Future<void> updateItemStatus({
    required String itemId,
    required String status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? remoteListing;
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      remoteListing = await BackendRepository.updateListingStatus(
        id: itemId,
        status: status,
      );
    }
    final itemsJson = prefs.getString(_itemsKey);
    final List<dynamic> list = itemsJson == null ? [] : jsonDecode(itemsJson);
    bool mutated = false;
    for (int i = 0; i < list.length; i++) {
      final map = Map<String, dynamic>.from(list[i] as Map);
      if (map['id'].toString() == itemId.toString()) {
        final isActive = status == 'active';
        map['status'] = status;
        map['isActive'] = isActive;
        if (status == 'ended') {
          map['endedAt'] = DateTime.now().toIso8601String();
        }
        mutated = true;
        list[i] = map;
        break;
      }
    }
    if (!mutated && remoteListing != null) {
      list.add(remoteListing);
      mutated = true;
    }
    if (mutated) {
      await prefs.setString(_itemsKey, jsonEncode(list));
    }
  }

  static Future<void> updateItem(Item updated) async {
    final prefs = await SharedPreferences.getInstance();
    var effectiveUpdated = updated;
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final remote = await BackendRepository.updateListing(updated.toJson());
      effectiveUpdated = Item.fromJson(remote);
    }
    final itemsJson = prefs.getString(_itemsKey);
    final List<dynamic> list = itemsJson == null ? [] : jsonDecode(itemsJson);
    bool mutated = false;
    for (int i = 0; i < list.length; i++) {
      final map = Map<String, dynamic>.from(list[i] as Map);
      if (map['id'].toString() == effectiveUpdated.id.toString()) {
        list[i] = effectiveUpdated.toJson();
        mutated = true;
        break;
      }
    }
    if (!mutated) list.add(effectiveUpdated.toJson());
    Future<void> persist(List<dynamic> payload) async {
      await prefs.setString(_itemsKey, jsonEncode(payload));
    }

    try {
      await persist(list);
    } catch (e) {
      debugPrint(
        '[DataService] updateItem persist failed, attempting to shrink payload: $e',
      );
      // Shrink photos across all items without inventing replacement listings or media.
      List<dynamic> shrunk = list.map((raw) {
        try {
          final m = Map<String, dynamic>.from(raw as Map);
          final photos = (m['photos'] as List?)
                  ?.map((p) => p?.toString() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toList() ??
              <String>[];
          final limited = <String>[];
          int idx = 0;
          for (final p in photos) {
            if (idx >= 3) break;
            if (!p.startsWith('data:')) {
              limited.add(p);
            }
            idx++;
          }
          m['photos'] = limited;
          return m;
        } catch (_) {
          return raw;
        }
      }).toList();
      try {
        await persist(shrunk);
      } catch (e2) {
        debugPrint(
          '[DataService] updateItem persist still failing after shrink: $e2',
        );
        final stripped = shrunk.map((raw) {
          try {
            final m = Map<String, dynamic>.from(raw as Map);
            m['photos'] = <String>[];
            return m;
          } catch (_) {
            return raw;
          }
        }).toList();
        await persist(stripped);
      }
    }
  }

  static Future<void> deleteItemById(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      await BackendRepository.deleteListing(itemId);
    }
    final itemsJson = prefs.getString(_itemsKey);
    if (itemsJson == null) return;
    final List<dynamic> list = jsonDecode(itemsJson);
    final before = list.length;
    list.removeWhere((e) => (e as Map)['id'].toString() == itemId.toString());
    if (list.length != before) {
      await prefs.setString(_itemsKey, jsonEncode(list));
    }
  }

  static bool isPublicCatalogItem(Item item) =>
      item.status == 'active' && item.isActive == true;

  static Future<List<Item>> getPublicItems() async {
    final items = await getItems();
    final blockedUserIds =
        (await BlockedUsersService.getBlockedUserIds()).toSet();
    final filtered = items
        .where(isPublicCatalogItem)
        .where((item) => !blockedUserIds.contains(item.ownerId))
        .toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  static Future<List<Item>> searchPublicItems({
    String? query,
    List<String> categoryIds = const <String>[],
    List<String> conditions = const <String>[],
    double? minPrice,
    double? maxPrice,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String sort = 'newest',
    int limit = 100,
  }) async {
    List<Item> items;
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final remote = await BackendRepository.searchListings(
        query: query,
        categoryIds: categoryIds,
        conditions: conditions,
        minPrice: minPrice,
        maxPrice: maxPrice,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        sort: sort,
        limit: limit,
      );
      items = <Item>[];
      for (final entry in remote) {
        try {
          items.add(Item.fromJson(entry));
        } catch (error) {
          debugPrint('[DataService] skipped invalid search result: $error');
        }
      }
    } else {
      final normalizedQuery = query?.trim().toLowerCase() ?? '';
      final boundedLimit = limit.clamp(1, 100).toInt();
      items = (await getPublicItems()).where((item) {
        if (normalizedQuery.isNotEmpty &&
            !item.title.toLowerCase().contains(normalizedQuery) &&
            !item.description.toLowerCase().contains(normalizedQuery) &&
            !item.tags
                .any((tag) => tag.toLowerCase().contains(normalizedQuery))) {
          return false;
        }
        if (categoryIds.isNotEmpty && !categoryIds.contains(item.categoryId)) {
          return false;
        }
        if (conditions.isNotEmpty && !conditions.contains(item.condition)) {
          return false;
        }
        if (minPrice != null && item.pricePerDay < minPrice) return false;
        if (maxPrice != null && item.pricePerDay > maxPrice) return false;
        if (latitude != null && longitude != null && radiusKm != null) {
          final distance =
              estimateDistanceKm(item.lat, item.lng, latitude, longitude);
          if (distance > radiusKm) return false;
        }
        return true;
      }).toList();
      if (sort == 'price_asc') {
        items.sort(
            (left, right) => left.pricePerDay.compareTo(right.pricePerDay));
      } else if (sort == 'price_desc') {
        items.sort(
            (left, right) => right.pricePerDay.compareTo(left.pricePerDay));
      } else if (sort == 'distance' && latitude != null && longitude != null) {
        items.sort((left, right) => estimateDistanceKm(
                left.lat, left.lng, latitude, longitude)
            .compareTo(
                estimateDistanceKm(right.lat, right.lng, latitude, longitude)));
      } else {
        items.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      }
      items = items.take(boundedLimit).toList();
    }
    final blockedUserIds =
        (await BlockedUsersService.getBlockedUserIds()).toSet();
    return items
        .where((item) => !blockedUserIds.contains(item.ownerId))
        .toList();
  }

  static Future<Set<String>> getSavedItemIds() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList(_savedItemsKey) ?? <String>[];
    final assignRaw = prefs.getString(_wishlistAssignKey);
    final wishlistIds = <String>{};
    if (assignRaw != null && assignRaw.isNotEmpty) {
      try {
        final Map<String, dynamic> map = jsonDecode(assignRaw);
        wishlistIds.addAll(map.keys.map((e) => e.toString()));
      } catch (_) {
        // ignore
      }
    }
    final out = <String>{...legacy, ...wishlistIds};
    return out;
  }

  static Future<void> toggleSavedItem(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_savedItemsKey) ?? <String>[];
    if (current.contains(itemId)) {
      current.remove(itemId);
    } else {
      current.add(itemId);
    }
    await prefs.setStringList(_savedItemsKey, current);
  }

  // ===== Wishlists (manual selection) =====
  /// IDs for the three predefined system wishlists
  static const String wlSoonId = 'wl_soon'; // Demnächst benötigt
  static const String wlLaterId = 'wl_later'; // Für später
  static const String wlAgainId = 'wl_again'; // Wieder mieten

  /// Ensure the three default wishlists exist. Non-destructive if already present.
  static Future<void> _ensureDefaultWishlists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? raw = prefs.getString(_wishlistsMetaKey);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          list = jsonDecode(raw);
        } catch (_) {
          list = [];
        }
      }
      bool hasSoon = false, hasLater = false, hasAgain = false;
      for (final e in list) {
        try {
          final m = Map<String, dynamic>.from(e as Map);
          final id = (m['id'] ?? '').toString();
          if (id == wlSoonId) hasSoon = true;
          if (id == wlLaterId) hasLater = true;
          if (id == wlAgainId) hasAgain = true;
        } catch (_) {}
      }
      if (!hasSoon) {
        list.add({
          'id': wlSoonId,
          'name': 'Demnächst benötigt',
          'system': true,
        });
      }
      if (!hasLater) {
        list.add({'id': wlLaterId, 'name': 'Für später', 'system': true});
      }
      if (!hasAgain) {
        list.add({'id': wlAgainId, 'name': 'Wieder mieten', 'system': true});
      }
      await prefs.setString(_wishlistsMetaKey, jsonEncode(list));
    } catch (e) {
      debugPrint(
        '[DataService] _ensureDefaultWishlists error: $e',
      );
    }
  }

  /// Returns all wishlists, with system lists first in the canonical order.
  static Future<List<Map<String, dynamic>>> getWishlists() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDefaultWishlists();
    final raw = prefs.getString(_wishlistsMetaKey);
    List<Map<String, dynamic>> out = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final List list = jsonDecode(raw);
        out = [
          for (final e in list)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
      } catch (e) {
        debugPrint('[DataService] getWishlists decode failed: $e');
      }
    }
    // Sort: system first in order soon, later, again; then custom by name
    out.sort((a, b) {
      final as = a['system'] == true;
      final bs = b['system'] == true;
      if (as && !bs) return -1;
      if (!as && bs) return 1;
      if (as && bs) {
        int rank(String id) => id == wlSoonId
            ? 0
            : (id == wlLaterId ? 1 : (id == wlAgainId ? 2 : 99));
        return rank(
          (a['id'] ?? '').toString(),
        ).compareTo(rank((b['id'] ?? '').toString()));
      }
      return ((a['name'] ?? '').toString()).toLowerCase().compareTo(
            ((b['name'] ?? '').toString()).toLowerCase(),
          );
    });
    return out;
  }

  /// Adds a new custom wishlist with the provided [name]. Returns the new id.
  static Future<String> addCustomWishlist(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDefaultWishlists();
    String id = 'wl_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final raw = prefs.getString(_wishlistsMetaKey);
      List<dynamic> list = raw != null && raw.isNotEmpty ? jsonDecode(raw) : [];
      list.add({'id': id, 'name': name.trim(), 'system': false});
      await prefs.setString(_wishlistsMetaKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[DataService] addCustomWishlist failed: $e');
    }
    return id;
  }

  /// Deletes a custom wishlist by id (no-op for system lists). Also clears its assignments.
  static Future<void> deleteCustomWishlist(String id) async {
    if (id == wlSoonId || id == wlLaterId || id == wlAgainId) {
      return; // cannot delete system
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_wishlistsMetaKey);
      List<dynamic> list = raw != null && raw.isNotEmpty ? jsonDecode(raw) : [];
      list.removeWhere((e) => (e is Map) && ((e['id'] ?? '').toString() == id));
      await prefs.setString(_wishlistsMetaKey, jsonEncode(list));
      // Clear assignments pointing to this list
      final aRaw = prefs.getString(_wishlistAssignKey);
      if (aRaw != null && aRaw.isNotEmpty) {
        try {
          final Map<String, dynamic> map = jsonDecode(aRaw);
          final keys = List<String>.from(map.keys);
          for (final k in keys) {
            if ((map[k] ?? '').toString() == id) map.remove(k);
          }
          await prefs.setString(_wishlistAssignKey, jsonEncode(map));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[DataService] deleteCustomWishlist failed: $e');
    }
  }

  /// Renames a custom wishlist. No-op for system lists.
  static Future<void> renameCustomWishlist({
    required String id,
    required String newName,
  }) async {
    if (id == wlSoonId || id == wlLaterId || id == wlAgainId) {
      return; // cannot rename system
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_wishlistsMetaKey);
      if (raw == null || raw.isEmpty) return;
      final List list = jsonDecode(raw);
      bool mutated = false;
      for (int i = 0; i < list.length; i++) {
        try {
          final m = Map<String, dynamic>.from(list[i] as Map);
          if ((m['id'] ?? '').toString() == id) {
            // Only allow rename when not a system list
            final isSystem = m['system'] == true;
            if (!isSystem) {
              m['name'] = newName.trim();
              list[i] = m;
              mutated = true;
            }
            break;
          }
        } catch (_) {
          /* ignore malformed entry */
        }
      }
      if (mutated) {
        await prefs.setString(_wishlistsMetaKey, jsonEncode(list));
      }
    } catch (e) {
      debugPrint('[DataService] renameCustomWishlist failed: $e');
    }
  }

  /// Returns the wishlist id the item currently belongs to, or null.
  static Future<String?> getWishlistForItem(String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_wishlistAssignKey);
      if (raw == null || raw.isEmpty) return null;
      final Map<String, dynamic> map = jsonDecode(raw);
      final v = map[itemId];
      return v?.toString();
    } catch (e) {
      debugPrint('[DataService] getWishlistForItem failed: $e');
      return null;
    }
  }

  /// Assigns an item to a wishlist (one list at a time).
  static Future<void> setItemWishlist(String itemId, String listId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_wishlistAssignKey);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        try {
          map = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          map = {};
        }
      }
      map[itemId] = listId;
      await prefs.setString(_wishlistAssignKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[DataService] setItemWishlist failed: $e');
    }
  }

  /// Removes an item from any wishlist.
  static Future<void> removeItemFromWishlist(String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_wishlistAssignKey);
      if (raw == null || raw.isEmpty) return;
      final Map<String, dynamic> map = jsonDecode(raw);
      if (map.containsKey(itemId)) {
        map.remove(itemId);
        await prefs.setString(_wishlistAssignKey, jsonEncode(map));
      }
    } catch (e) {
      debugPrint(
        '[DataService] removeItemFromWishlist failed: $e',
      );
    }
  }

  /// Returns items grouped by wishlist id.
  static Future<Map<String, List<Item>>> getItemsByWishlist() async {
    final Map<String, List<Item>> out = {};
    try {
      final items = await getItems();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_wishlistAssignKey);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        try {
          map = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          map = {};
        }
      }
      for (final it in items) {
        final id = (map[it.id]?.toString() ?? '');
        if (id.isEmpty) continue;
        out.putIfAbsent(id, () => []).add(it);
      }
    } catch (e) {
      debugPrint('[DataService] getItemsByWishlist failed: $e');
    }
    return out;
  }

  static Future<void> _initializeSampleData() async {
    final prefs = await SharedPreferences.getInstance();

    final categories = _buildDemoCategories();
    await prefs.setString(
      _categoriesKey,
      jsonEncode(categories.map((c) => c.toJson()).toList()),
    );

    final users = _buildDemoUsers();
    final items = _buildDemoItems(users, categories);
    final reviews = _buildDemoReviews(users);

    // Ensure stored review counts reflect actual demo reviews for consistency across the app.
    final reviewCounts = <String, int>{};
    for (final review in reviews) {
      reviewCounts.update(
        review.reviewedUserId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final usersWithCounts = [
      for (final user in users)
        user.copyWith(reviewCount: reviewCounts[user.id] ?? user.reviewCount),
    ];

    await prefs.setString(
      _usersKey,
      jsonEncode(usersWithCounts.map((u) => u.toJson()).toList()),
    );
    await prefs.setString(
      _itemsKey,
      jsonEncode(items.map((i) => i.toJson()).toList()),
    );
    await prefs.setString(
      _reviewsKey,
      jsonEncode(reviews.map((r) => r.toJson()).toList()),
    );

    // Sample-data bootstrap must not auto-auth a current user.
    // currentUser should only be established by real login/session hydration.
    await prefs.remove(_currentUserKey);
    // Ensure wishlists are initialized once demo data is set up.
    try {
      await _ensureDefaultWishlists();
    } catch (e) {
      debugPrint(
        '[DataService] ensureDefaultWishlists failed: $e',
      );
    }
  }

  // Cities and coordinates (Germany)
  static const Map<String, (double lat, double lng)> _cities = {
    'Berlin': (52.5200, 13.4050),
    'Hamburg': (53.5511, 9.9937),
    'München': (48.1351, 11.5820),
    'Köln': (50.9375, 6.9603),
    'Frankfurt am Main': (50.1109, 8.6821),
    'Stuttgart': (48.7758, 9.1829),
    'Düsseldorf': (51.2277, 6.7735),
    'Leipzig': (51.3397, 12.3731),
    'Hannover': (52.3759, 9.7320),
    'Nürnberg': (49.4521, 11.0767),
    'Bremen': (53.0793, 8.8017),
    'Dortmund': (51.5136, 7.4653),
    'Essen': (51.4556, 7.0116),
    'Duisburg': (51.4344, 6.7623),
    'Bochum': (51.4818, 7.2162),
    'Wuppertal': (51.2562, 7.1508),
    'Bielefeld': (52.0302, 8.5325),
    'Bonn': (50.7374, 7.0982),
    'Münster': (51.9607, 7.6261),
    'Karlsruhe': (49.0069, 8.4037),
    'Mannheim': (49.4875, 8.4660),
    'Augsburg': (48.3705, 10.8978),
    'Wiesbaden': (50.0782, 8.2398),
    'Gelsenkirchen': (51.5177, 7.0857),
    'Mönchengladbach': (51.1805, 6.4428),
    'Braunschweig': (52.2689, 10.5268),
    'Kiel': (54.3233, 10.1228),
    'Aachen': (50.7753, 6.0839),
    'Dresden': (51.0504, 13.7373),
    'Chemnitz': (50.8278, 12.9214),
    'Halle (Saale)': (51.4968, 11.9689),
    'Magdeburg': (52.1205, 11.6276),
    'Freiburg im Breisgau': (47.9990, 7.8421),
    'Krefeld': (51.3388, 6.5853),
    'Lübeck': (53.8655, 10.6866),
    'Oberhausen': (51.4963, 6.8516),
    'Erfurt': (50.9848, 11.0299),
    'Mainz': (49.9929, 8.2473),
    'Rostock': (54.0924, 12.0991),
    'Kassel': (51.3127, 9.4797),
    'Hagen': (51.3671, 7.4633),
    'Saarbrücken': (49.2402, 6.9969),
    'Hamm': (51.6739, 7.8160),
    'Potsdam': (52.3906, 13.0645),
    'Ludwigshafen am Rhein': (49.4774, 8.4452),
    'Oldenburg': (53.1435, 8.2146),
    'Leverkusen': (51.0459, 7.0192),
    'Osnabrück': (52.2799, 8.0472),
    'Solingen': (51.1652, 7.0671),
    'Heidelberg': (49.3988, 8.6724),
    'Herne': (51.5380, 7.2257),
  };

  static Map<String, (double lat, double lng)> getCities() =>
      Map.unmodifiable(_cities);

  // Returns the closest known city name for a given coordinate.
  static String nearestCityName(double lat, double lng) {
    String nearest = _cities.keys.first;
    double best = double.infinity;
    for (final entry in _cities.entries) {
      final d = _haversine(lat, lng, entry.value.$1, entry.value.$2);
      if (d < best) {
        best = d;
        nearest = entry.key;
      }
    }
    return nearest;
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180.0);

  // Delivery helpers
  static double estimateDistanceKm(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) {
    return _haversine(fromLat, fromLng, toLat, toLng);
  }

  static double estimateDistanceKmToCity(
    double fromLat,
    double fromLng,
    String cityName,
  ) {
    final cityPos = _cities[cityName];
    if (cityPos == null) return 0.0;
    return _haversine(fromLat, fromLng, cityPos.$1, cityPos.$2);
  }

  static double deliveryFeeForDistanceKm(double km) {
    // Charged for both ways (Hin- & Rückweg): km × 2 × 0.30 €
    final fee = km * 2 * 0.30; // €0.30 per km, round trip
    return fee < 3.0 ? 3.0 : double.parse(fee.toStringAsFixed(2));
  }

  // Coarse category groups (ordered) for simplified display in UI
  static const List<String> coarseCategoryOrder = [
    'Technik & Elektronik',
    'Werkzeuge & Kleingeräte',
    'Haushalt & Wohnen',
    'Sport & Hobbys',
    'Auto & Mobilität',
    'Garten & Outdoor',
    'Events & Feiern',
    'Baby & Familie',
    'Reisen & Camping',
    'Kleidung & Anlässe',
    'Büro & Lernen',
    'Sonstiges',
  ];

  /// Maps a fine-grained category name (e.g., "Elektronik", "Kameras & Drohnen")
  /// to a coarse, simplified group used for display. Defaults to "Sonstiges".
  static String coarseCategoryFor(String name) {
    final n = name.toLowerCase();
    // Known mappings from demo data to coarse buckets
    if (n.contains('elektronik') ||
        n.contains('computer') ||
        n.contains('kamera') ||
        n.contains('audio') ||
        n.contains('mikro') ||
        n.contains('drohn') ||
        n.contains('gaming') ||
        n.contains('vr') ||
        n.contains('smart')) {
      return 'Technik & Elektronik';
    }
    if (n.contains('werkzeug') ||
        n.contains('maschinen') ||
        n.contains('handwerk') ||
        n.contains('bohr') ||
        n.contains('säge') ||
        n.contains('saege')) {
      return 'Werkzeuge & Kleingeräte';
    }
    if (n.contains('haushalt') ||
        n.contains('haushalts') ||
        n.contains('möbel') ||
        n.contains('moebel') ||
        n.contains('wohnen') ||
        n.contains('beleuchtung') ||
        n.contains('licht')) {
      return 'Haushalt & Wohnen';
    }
    if (n.contains('freizeit') ||
        n.contains('sport') ||
        n.contains('fitness') ||
        n.contains('hobby')) {
      return 'Sport & Hobbys';
    }
    if (n.contains('fahrzeug') ||
        n.contains('teile') ||
        n.contains('fahrräder') ||
        n.contains('fahrraeder') ||
        n.contains('mobilität') ||
        n.contains('mobilitaet') ||
        n.contains('e-mobility') ||
        n.contains('bike') ||
        n.contains('e-scooter') ||
        n.contains('scooter') ||
        n.contains('auto') ||
        n.contains('wagen')) {
      return 'Auto & Mobilität';
    }
    if (n.contains('garten') ||
        n.contains('heimwerken') ||
        n.contains('grill') ||
        n.contains('rasen') ||
        n.contains('outdoor')) {
      return 'Garten & Outdoor';
    }
    if (n.contains('event') ||
        n.contains('feier') ||
        n.contains('party') ||
        n.contains('hochzeit') ||
        n.contains('geburtstag') ||
        n.contains('festival')) {
      return 'Events & Feiern';
    }
    if (n.contains('baby') ||
        n.contains('kinder') ||
        n.contains('familie') ||
        n.contains('spielzeug')) {
      return 'Baby & Familie';
    }
    if (n.contains('camping') ||
        n.contains('zelt') ||
        n.contains('reise') ||
        n.contains('urlaub') ||
        n.contains('rucksack') ||
        n.contains('koffer')) {
      return 'Reisen & Camping';
    }
    if (n.contains('mode') ||
        n.contains('accessoires') ||
        n.contains('schmuck') ||
        n.contains('uhren') ||
        n.contains('kleidung') ||
        n.contains('anzug') ||
        n.contains('kleid') ||
        n.contains('kostüm') ||
        n.contains('kostuem')) {
      return 'Kleidung & Anlässe';
    }
    if (n.contains('büro') ||
        n.contains('buero') ||
        n.contains('gewerbe') ||
        n.contains('office') ||
        n.contains('lernen') ||
        n.contains('schule') ||
        n.contains('studium')) {
      return 'Büro & Lernen';
    }
    if (n.contains('haustier')) {
      return 'Sonstiges';
    }
    return 'Sonstiges';
  }

  static Future<Map<String, dynamic>?> getSavedDeliverySelection(
    String itemId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingSelectionsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entry = map[itemId];
      if (entry is Map && entry['delivery'] is Map) {
        final map = Map<String, dynamic>.from(entry['delivery'] as Map);
        // Backfill: ensure new fields exist
        if (!map.containsKey('addressLine')) map['addressLine'] = '';
        if (!map.containsKey('city')) map['city'] = '';
        if (!map.containsKey('lat')) map['lat'] = null;
        if (!map.containsKey('lng')) map['lng'] = null;
        if (!map.containsKey('express')) map['express'] = false;
        if (!map.containsKey('deliveryAddressLine')) {
          map['deliveryAddressLine'] = map['addressLine'] ?? '';
        }
        if (!map.containsKey('deliveryCity')) {
          map['deliveryCity'] = map['city'] ?? '';
        }
        if (!map.containsKey('deliveryLat')) map['deliveryLat'] = map['lat'];
        if (!map.containsKey('deliveryLng')) map['deliveryLng'] = map['lng'];
        if (!map.containsKey('returnAddressLine')) {
          map['returnAddressLine'] = map['addressLine'] ?? '';
        }
        if (!map.containsKey('returnCity')) {
          map['returnCity'] = map['city'] ?? '';
        }
        if (!map.containsKey('returnLat')) map['returnLat'] = map['lat'];
        if (!map.containsKey('returnLng')) map['returnLng'] = map['lng'];
        return map;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> setSavedDeliverySelection(
    String itemId, {
    required bool hinweg,
    required bool rueckweg,
    String? addressCity,
    String addressLine = '',
    bool express = false,
    double? lat,
    double? lng,
    String? deliveryAddressLine,
    String? deliveryCity,
    double? deliveryLat,
    double? deliveryLng,
    String? returnAddressLine,
    String? returnCity,
    double? returnLat,
    double? returnLng,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingSelectionsKey);
    Map<String, dynamic> map = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        map = {};
      }
    }
    final existing =
        (map[itemId] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
            <String, dynamic>{};
    existing['delivery'] = {
      'hinweg': hinweg,
      'rueckweg': rueckweg,
      'city': addressCity ?? '',
      'addressLine': addressLine,
      'express': express,
      'lat': lat,
      'lng': lng,
      'deliveryAddressLine': deliveryAddressLine ?? addressLine,
      'deliveryCity': deliveryCity ?? addressCity ?? '',
      'deliveryLat': deliveryLat ?? lat,
      'deliveryLng': deliveryLng ?? lng,
      'returnAddressLine': returnAddressLine ?? addressLine,
      'returnCity': returnCity ?? addressCity ?? '',
      'returnLat': returnLat ?? lat,
      'returnLng': returnLng ?? lng,
    };
    map[itemId] = existing;
    await prefs.setString(_bookingSelectionsKey, jsonEncode(map));
  }

  // Extract a known city from a freeform address string, or return empty if not found
  static String deriveCityFromAddress(String address) {
    final a = address.toLowerCase();
    for (final c in _cities.keys) {
      if (a.contains(c.toLowerCase())) return c;
    }
    return '';
  }

  // Estimate distance based on a freeform address by resolving it to the nearest known city token.
  // This is a placeholder until a Maps API is connected; it provides a reasonable local demo.
  static double estimateDistanceKmFromAddressLine(
    double fromLat,
    double fromLng,
    String addressLine,
  ) {
    final city = deriveCityFromAddress(addressLine);
    if (city.isNotEmpty) {
      return estimateDistanceKmToCity(fromLat, fromLng, city);
    }
    // Fallback: use the nearest city to the item coordinate as a proxy (0 km)
    // so that we don't block checkout without maps integration.
    return 0.0;
  }

  static String _rentalDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  // The backend is authoritative in normal operation. The local lane remains
  // only for explicit QA fixtures where no backend is connected.
  static Future<bool> checkAvailability({
    required String itemId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      return BackendRepository.checkListingAvailability(
        listingId: itemId,
        startDate: _rentalDate(start),
        endDate: _rentalDate(end),
      );
    }
    // Quick delay to emulate IO
    await Future<void>.delayed(const Duration(milliseconds: 120));
    // Load all requests and block overlaps with accepted or running bookings
    final all = await _getAllRentalRequests();
    for (final r in all) {
      if (r.itemId != itemId) continue;
      if (r.status != 'accepted' && r.status != 'running') continue;
      // Overlap if requested start < existing.end and requested end > existing.start
      final bool overlap = start.isBefore(r.end) && end.isAfter(r.start);
      if (overlap) return false;
    }
    return true;
  }

  // Ranges that are already booked for an item. A day is considered booked
  // when it is >= start and < end (end-exclusive). Used by the calendar to
  // render red blocked days and prevent overlapping selections.
  static Future<List<DateTimeRange>> getUnavailableRangesForItem(
    String itemId,
  ) async {
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final now = DateTime.now();
      final through = DateTime(now.year + 1, now.month, now.day + 1);
      final availability = await BackendRepository.getListingAvailability(
        listingId: itemId,
        fromDate: _rentalDate(now),
        toDate: _rentalDate(through),
      );
      final entries = availability['unavailable'];
      if (entries is! List) return <DateTimeRange>[];
      return entries.whereType<Map>().map((entry) {
        final start = DateTime.parse(entry['start'].toString()).toLocal();
        final end = DateTime.parse(entry['end'].toString()).toLocal();
        return DateTimeRange(start: start, end: end);
      }).toList();
    }
    final all = await _getAllRentalRequests();
    final ranges = <DateTimeRange>[];
    for (final r in all) {
      if (r.itemId != itemId) continue;
      if (r.status != 'accepted' && r.status != 'running') continue;
      ranges.add(DateTimeRange(start: r.start, end: r.end));
    }
    return ranges;
  }

  static List<Category> _buildDemoCategories() {
    final now = DateTime.now();
    final List<
        (
          String id,
          String name,
          String slug,
          String iconName,
          List<String> subs
        )> data = [
      (
        'cat1',
        'Elektronik',
        'elektronik',
        'devices',
        ['Smartphones', 'Tablets', 'Wearables', 'Audio', 'Zubehör'],
      ),
      (
        'cat2',
        'Computer & IT',
        'computer-it',
        'computer',
        ['Laptops', 'Desktops', 'Monitore', 'Drucker', 'Netzwerk'],
      ),
      (
        'cat3',
        'Kameras & Drohnen',
        'kameras-drohnen',
        'camera_alt',
        ['Kameras', 'Objektive', 'Drohnen', 'Stative', 'Licht'],
      ),
      (
        'cat4',
        'Gaming & VR',
        'gaming-vr',
        'sports_esports',
        ['Konsolen', 'Gaming-PC', 'VR', 'Lenkräder', 'Retro'],
      ),
      (
        'cat5',
        'Haushaltsgeräte',
        'haushaltsgeraete',
        'kitchen',
        [
          'Staubsauger',
          'Mixer',
          'Kaffeemaschinen',
          'Waschmaschinen',
          'Trockner',
        ],
      ),
      (
        'cat6',
        'Möbel & Wohnen',
        'moebel-wohnen',
        'weekend',
        ['Sofas', 'Tische', 'Stühle', 'Beleuchtung', 'Deko'],
      ),
      (
        'cat7',
        'Garten & Heimwerken',
        'garten-heimwerken',
        'grass',
        [
          'Rasenmäher',
          'Heckenscheren',
          'Gartengeräte',
          'Bewässerung',
          'Pflanzkisten',
        ],
      ),
      (
        'cat8',
        'Werkzeuge & Maschinen',
        'werkzeuge-maschinen',
        'construction',
        [
          'Handwerkzeuge',
          'Elektrowerkzeuge',
          'Bohrmaschinen',
          'Sägen',
          'Schleifer',
        ],
      ),
      (
        'cat9',
        'Fahrräder & E-Mobility',
        'fahrraeder-e-mobility',
        'pedal_bike',
        ['Citybikes', 'MTB', 'E-Bikes', 'E-Scooter', 'Zubehör'],
      ),
      (
        'cat10',
        'Fahrzeuge & Teile',
        'fahrzeuge-teile',
        'directions_car',
        ['Kleinwagen', 'SUV', 'Transporter', 'Wohnmobil', 'Anhänger'],
      ),
      (
        'cat11',
        'Freizeit, Sport & Outdoor',
        'freizeit-sport-outdoor',
        'sports_soccer',
        ['Fitness', 'Teamsport', 'Racketsport', 'Radsport', 'Wassersport'],
      ),
      (
        'cat12',
        'Mode & Accessoires',
        'mode-accessoires',
        'checkroom',
        ['Kleidung', 'Taschen', 'Schuhe', 'Schmuck', 'Uhren'],
      ),
      (
        'cat13',
        'Baby, Kinder & Spielzeug',
        'baby-kinder-spielzeug',
        'child_friendly',
        ['Kinderwagen', 'Sitze', 'Spielzeug', 'Tragen', 'Sicherheit'],
      ),
      (
        'cat14',
        'Musikinstrumente & DJ',
        'musikinstrumente-dj',
        'music_note',
        ['Gitarren', 'Tastaturen', 'Schlagzeug', 'Blasinstrumente', 'Studio'],
      ),
      (
        'cat15',
        'Bücher, Filme & Medien',
        'buecher-filme-medien',
        'menu_book',
        ['Bücher', 'Filme', 'Spiele', 'Hörbücher', 'Magazine'],
      ),
      (
        'cat16',
        'Schmuck & Uhren',
        'schmuck-uhren',
        'watch',
        ['Ringe', 'Ketten', 'Uhren', 'Ohrringe', 'Sets'],
      ),
      (
        'cat17',
        'Kunst & Sammlerstücke',
        'kunst-sammlerstuecke',
        'palette',
        ['Gemälde', 'Skulpturen', 'Drucke', 'Figuren', 'Seltenes'],
      ),
      (
        'cat18',
        'Beauty & Gesundheit',
        'beauty-gesundheit',
        'spa',
        ['Kosmetik', 'Pflege', 'Wellness', 'Medizin', 'Zubehör'],
      ),
      (
        'cat19',
        'Haustierbedarf',
        'haustierbedarf',
        'pets',
        ['Hunde', 'Katzen', 'Kleintiere', 'Aquaristik', 'Zubehör'],
      ),
      (
        'cat20',
        'Büro & Gewerbe',
        'buero-gewerbe',
        'business_center',
        ['Bürotechnik', 'Präsentation', 'Werkstatt', 'Lager', 'Zubehör'],
      ),
      (
        'cat22',
        'Events & Feiern',
        'events-feiern',
        'celebration',
        [
          'Party-Deko',
          'Eventtechnik',
          'Tische & Stühle',
          'Pavillons',
          'Buffet & Catering',
        ],
      ),
      (
        'cat23',
        'Reisen & Camping',
        'reisen-camping',
        'travel_explore',
        [
          'Zelte',
          'Schlafsäcke',
          'Rucksäcke & Koffer',
          'Campingküche',
          'Outdoor-Zubehör',
        ],
      ),
      ('cat21', 'Sonstiges', 'sonstiges', 'more_horiz', ['Diverses']),
    ];
    return [
      for (final d in data)
        Category(
          id: d.$1,
          name: d.$2,
          slug: d.$3,
          iconName: d.$4,
          subcategories: d.$5,
          createdAt: now,
        ),
    ];
  }

  static const List<(String id, String name, String photo)> _userSeeds = [
    (
      'u1',
      'Walid Chraibi',
      'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u2',
      'Max Mustermann',
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u3',
      'Sarah Schmidt',
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u4',
      'Thomas Weber',
      'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u5',
      'Julia Wagner',
      'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u6',
      'David König',
      'https://images.unsplash.com/photo-1519345182560-3f2917c472ef?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u7',
      'Anna Keller',
      'https://images.unsplash.com/photo-1520813792240-56fc4a3765a7?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u8',
      'Laura Krüger',
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u9',
      'Daniel Hoffmann',
      'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u10',
      'Sophie Lehmann',
      'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u11',
      'Jonas Maier',
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u12',
      'Lea Schuster',
      'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u13',
      'Felix Braun',
      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u14',
      'Mia Sauer',
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u15',
      'Tobias Busch',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u16',
      'Nina Scholz',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u17',
      'Sebastian Hartmann',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u18',
      'Eva Fuchs',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u19',
      'Paul Engel',
      'https://images.unsplash.com/photo-1531891437562-4301cf35b7e4?w=150&h=150&fit=crop&crop=face',
    ),
    (
      'u20',
      'Clara Wolf',
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&h=150&fit=crop&crop=face',
    ),
  ];

  static (String name, String photo)? _seedForId(String id) {
    for (final seed in _userSeeds) {
      if (seed.$1 == id) return (seed.$2, seed.$3);
    }
    return null;
  }

  static List<User> _buildDemoUsers() {
    final now = DateTime.now();
    final cities = _cities.keys.toList();
    final rnd = Random(42);
    return [
      for (final entry in _userSeeds)
        User(
          id: entry.$1,
          displayName: entry.$2,
          email: '${entry.$1}@shareittoo.demo',
          city: cities[rnd.nextInt(cities.length)],
          country: 'Deutschland',
          preferredLanguage: 'de-DE',
          isVerified: rnd.nextDouble() < 0.7,
          isBanned: false,
          role: 'user',
          avgRating: 4.0 + rnd.nextDouble() * 0.8,
          reviewCount: 0,
          createdAt: now.subtract(Duration(days: rnd.nextInt(1200))),
          photoURL: entry.$3,
          languages: const ['Deutsch'],
        ),
    ];
  }

  static List<Item> _buildDemoItems(
    List<User> users,
    List<Category> categories,
  ) {
    final rnd = Random(99);
    final now = DateTime.now();
    final List<(String city, (double, double) pos)> cities = [
      for (final e in _cities.entries) (e.key, (e.value.$1, e.value.$2)),
    ];

    // Title seeds by category
    final Map<String, List<String>> titles = {
      'cat1': [
        'iPhone 14 Pro',
        'Samsung Galaxy S23',
        'iPad Pro 11"',
        'Kindle Paperwhite',
        'Sony WH-1000XM5',
      ],
      'cat2': [
        'MacBook Air M2',
        '27" Monitor',
        'WiFi 6 Router',
        'QNAP NAS',
        'Laserdrucker',
      ],
      'cat3': [
        'Canon EOS R5',
        'Sony A7 IV',
        'DJI Mini 3 Pro',
        'Fujifilm X-T5',
        'Nikon Z6 II',
      ],
      'cat4': [
        'PS5 Konsole',
        'Gaming-PC',
        'VR Headset',
        'Nintendo Switch',
        'Rennlenkrad',
      ],
      'cat5': [
        'Dyson Staubsauger',
        'KitchenAid Mixer',
        'Jura Kaffeemaschine',
        'Miele Waschmaschine',
        'Bosch Trockner',
      ],
      'cat6': [
        'Samt-Sofa 3-Sitzer',
        'Esstisch Eiche',
        'Design-Lampe',
        'Barhocker',
        'Sideboard',
      ],
      'cat7': [
        'Rasenmäher',
        'Heckenschere',
        'Hochdruckreiniger',
        'Gartenhäcksler',
        'Schubkarre',
      ],
      'cat8': [
        'Bosch Bohrmaschine',
        'Makita Akkuschrauber',
        'DeWalt Kreissäge',
        'Einhell Winkelschleifer',
        'Metabo Stichsäge',
      ],
      'cat9': [
        'E-Bike Trekking',
        'Mountainbike',
        'E-Scooter',
        'Citybike',
        'Rennrad',
      ],
      'cat10': [
        'VW Golf',
        'BMW 3er',
        'Mercedes Sprinter',
        'Wohnmobil Ducato',
        'Dachbox',
      ],
      'cat11': [
        'SUP-Board',
        'Kletterausrüstung',
        '2-Personen Zelt',
        'Ski-Set',
        'Inlineskates',
      ],
      'cat12': [
        'Abendkleid',
        'Ledertasche',
        'Sneaker',
        'Armbanduhr',
        'Sonnenbrille',
      ],
      'cat13': [
        'Kinderwagen',
        'Kindersitz',
        'Laufrad',
        'Babyphone',
        'Tragehilfe',
      ],
      'cat14': [
        'Akustikgitarre',
        'E-Piano',
        'DJ Controller',
        'Saxophon',
        'Studio-Mikrofon',
      ],
      'cat15': [
        'Buchpaket Sci-Fi',
        'Blu-ray Sammlung',
        'Brettspiele',
        'Hörbuch-Set',
        'Manga-Box',
      ],
      'cat16': [
        'Armbanduhr',
        'Halskette',
        'Ohrringe',
        'Perlenkette',
        'Uhrenbox',
      ],
      'cat17': [
        'Gemälde Öl',
        'Skulptur',
        'Vintage Figur',
        'Posterlimit',
        'Vinyl Sammlung',
      ],
      'cat18': [
        'Massagepistole',
        'Infrarotlampe',
        'Haartrockner',
        'Glätteisen',
        'Ionenluftreiniger',
      ],
      'cat19': [
        'Hundetransportbox',
        'Kratzbaum',
        'Aquarien-Set',
        'Hundebuggy',
        'Futterautomat',
      ],
      'cat20': [
        'Beamer',
        'Flipchart',
        'Bohrhammer',
        'Industriesauger',
        'Messestand',
      ],
      'cat21': ['Werkzeugkoffer', 'Überraschungspaket', 'Diverse Dinge'],
    };

    int idCounter = 1;
    final List<Item> items = [];
    final int targetCount = 160 + rnd.nextInt(40); // 160–199

    List<String> photosFor(String key, int seed, String catId) {
      // Use category-specific images with reliable sources
      final Map<String, List<String>> categoryImages = {
        'cat1': [
          // Elektronik
          'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556656793-08538906a9f8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1545127398-14699f92334b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1585060544812-6b45742d762f?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1483736762161-1d107f3c78e1?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556656793-08538906a9f8?w=800&h=800&fit=crop',
        ],
        'cat2': [
          // Computer & IT
          'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1587831990711-23ca6441447b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1484788984921-03950022c9ef?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1517077304055-6e89abbf09b0?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1616628188540-26abf1d75b5b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1587831990711-23ca6441447b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1484788984921-03950022c9ef?w=800&h=800&fit=crop',
        ],
        'cat3': [
          // Kameras & Drohnen
          'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1473496169904-658ba7c44d8a?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1606983340126-99ab4feaa64a?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1486401899868-0e435ed85128?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1495592822108-9e6261896da8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1473496169904-658ba7c44d8a?w=800&h=800&fit=crop',
        ],
        'cat4': [
          // Gaming & VR
          'https://images.unsplash.com/photo-1493711662062-fa541adb3fc8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1592840331013-9c57c6f3a3b8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1574292384054-9a63e9c5cfb0?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1493711662062-fa541adb3fc8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1592840331013-9c57c6f3a3b8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=800&h=800&fit=crop',
        ],
        'cat5': [
          // Haushaltsgeräte
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556909202-f6d704471045?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1570222094114-d054a817e56b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556909202-f6d704471045?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1570222094114-d054a817e56b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=800&fit=crop',
        ],
        'cat8': [
          // Werkzeuge & Maschinen
          'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1609205842104-8e045f7e3e3c?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1544716278-e513176f20a5?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1611269154421-4e27233ac5c7?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1609205842104-8e045f7e3e3c?w=800&h=800&fit=crop',
        ],
        'cat9': [
          // Fahrräder & E-Mobility
          'https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1502744688674-c619d1586c9e?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1544191696-15693074e8b5?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1502744688674-c619d1586c9e?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1544191696-15693074e8b5?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=800&h=800&fit=crop',
        ],
      };

      final images = categoryImages[catId] ??
          [
            'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800&h=800&fit=crop',
            'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800&h=800&fit=crop',
            'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=800&h=800&fit=crop',
            'https://images.unsplash.com/photo-1541807084-5c52b6b3adef?w=800&h=800&fit=crop',
            'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800&h=800&fit=crop',
            'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800&h=800&fit=crop',
            'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=800&h=800&fit=crop',
            'https://images.unsplash.com/photo-1541807084-5c52b6b3adef?w=800&h=800&fit=crop',
            'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800&h=800&fit=crop',
          ];

      return images;
    }

    for (int i = 0; i < targetCount; i++) {
      final cat = categories[rnd.nextInt(categories.length)];
      final city = cities[rnd.nextInt(cities.length)];
      final owner = users[rnd.nextInt(users.length)];
      final titleList = titles[cat.id] ?? ['Top Angebot'];
      final title = titleList[rnd.nextInt(titleList.length)];

      // distance around city center (±20km)
      final dLat = (rnd.nextDouble() - 0.5) * 0.36; // rough ~40km span
      final dLng = (rnd.nextDouble() - 0.5) * 0.56;
      final lat = city.$2.$1 + dLat;
      final lng = city.$2.$2 + dLng;

      // price ranges per category (rough realistic €)
      final basePrice = switch (cat.id) {
        'cat1' => 12 + rnd.nextInt(30), // Elektronik
        'cat2' => 8 + rnd.nextInt(25), // Computer & IT
        'cat3' => 35 + rnd.nextInt(100), // Kameras & Drohnen
        'cat4' => 10 + rnd.nextInt(35), // Gaming & VR
        'cat5' => 10 + rnd.nextInt(35), // Haushaltsgeräte
        'cat6' => 10 + rnd.nextInt(30), // Möbel & Wohnen
        'cat7' => 7 + rnd.nextInt(20), // Garten & Heimwerken
        'cat8' => 8 + rnd.nextInt(20), // Werkzeuge & Maschinen
        'cat9' => 8 + rnd.nextInt(22), // Fahrräder & E-Mobility
        'cat10' => 40 + rnd.nextInt(120), // Fahrzeuge & Teile
        'cat11' => 6 + rnd.nextInt(25), // Freizeit, Sport & Outdoor
        'cat12' => 4 + rnd.nextInt(20), // Mode & Accessoires
        'cat13' => 5 + rnd.nextInt(18), // Baby, Kinder & Spielzeug
        'cat14' => 8 + rnd.nextInt(30), // Musikinstrumente & DJ
        'cat15' => 3 + rnd.nextInt(10), // Bücher, Filme & Medien
        'cat16' => 6 + rnd.nextInt(24), // Schmuck & Uhren
        'cat17' => 8 + rnd.nextInt(27), // Kunst & Sammlerstücke
        'cat18' => 5 + rnd.nextInt(17), // Beauty & Gesundheit
        'cat19' => 4 + rnd.nextInt(14), // Haustierbedarf
        'cat20' => 12 + rnd.nextInt(38), // Büro & Gewerbe
        'cat21' => 10 + rnd.nextInt(30), // Sonstiges
        _ => 10 + rnd.nextInt(30),
      };

      final isNewish = i < 80; // ensure at least 80 latest
      final createdAt = now.subtract(
        Duration(days: isNewish ? rnd.nextInt(10) : 10 + rnd.nextInt(350)),
      );
      final verified = rnd.nextDouble() < 0.6; // ~60%

      // Determine demo delivery offerings
      final bool offerDropoff = rnd.nextDouble() < 0.5; // ~50%
      final bool offerPickup = rnd.nextDouble() < 0.5; // ~50%
      double? maxDropKm;
      double? maxReturnKm;
      if (offerDropoff && rnd.nextBool()) {
        const opts = [5, 7, 10, 12, 15, 20, 25, 30];
        maxDropKm = opts[rnd.nextInt(opts.length)].toDouble();
      }
      if (offerPickup && rnd.nextBool()) {
        const opts = [5, 7, 10, 12, 15, 20, 25, 30];
        maxReturnKm = opts[rnd.nextInt(opts.length)].toDouble();
      }

      final item = Item(
        id: '${idCounter++}',
        ownerId: owner.id,
        title: title,
        description: 'Gut gepflegt, sofort verfügbar. ${cat.name} • ${city.$1}',
        categoryId: cat.id,
        subcategory:
            cat.subcategories.isNotEmpty ? cat.subcategories.first : '-',
        tags: [cat.slug, city.$1],
        pricePerDay: basePrice.toDouble(),
        currency: 'EUR',
        priceUnit: 'day',
        priceRaw: basePrice.toDouble(),
        photos: photosFor(cat.slug, i, cat.id),
        locationText: '${city.$1}-${[
          'Mitte',
          'Nord',
          'Süd',
          'Ost',
          'West'
        ][rnd.nextInt(5)]}',
        lat: lat,
        lng: lng,
        geohash: 'u'
            '${rnd.nextInt(9)}'
            '${rnd.nextInt(9)}'
            '${rnd.nextInt(9)}'
            '${rnd.nextInt(9)}',
        condition: ['new', 'like-new', 'good', 'acceptable'][rnd.nextInt(4)],
        minDays: [null, 1, 2].elementAt(rnd.nextInt(3)),
        maxDays: [null, 7, 14, 30].elementAt(rnd.nextInt(4)),
        createdAt: createdAt,
        isActive: true,
        verificationStatus: verified ? 'approved' : 'pending',
        city: city.$1,
        country: 'Deutschland',
        timesLent: rnd.nextInt(220),
        offersDeliveryAtDropoff: offerDropoff,
        offersPickupAtReturn: offerPickup,
        offersExpressAtDropoff: offerDropoff && rnd.nextBool(),
        // In ~50% of offerings, show a max km (demo)
        maxDeliveryKmAtDropoff: maxDropKm,
        maxPickupKmAtReturn: maxReturnKm,
        cancellationPolicy: ['flexible', 'moderate', 'strict'][rnd.nextInt(3)],
      );
      items.add(item);
    }

    // Ensure at least 60 items have >=9 photos (already 9 by design) and mark them newest
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static List<Item> _buildFiveShowcaseItems(
    List<User> users,
    List<Category> categories,
  ) {
    final now = DateTime.now();
    // Pick a stable owner and cities
    final owner = users.isNotEmpty
        ? users.first
        : User(
            id: 'u1',
            displayName: 'Demo User',
            email: 'demo@demo',
            city: 'Berlin',
            country: 'Deutschland',
            preferredLanguage: 'de-DE',
            isVerified: true,
            isBanned: false,
            role: 'user',
            avgRating: 4.8,
            reviewCount: 12,
            createdAt: now,
            photoURL: '',
            languages: const ['Deutsch'],
          );
    final berlin = _cities['Berlin'] ?? (52.52, 13.405);
    Category cat(String id) => categories.firstWhere(
          (c) => c.id == id,
          orElse: () => categories.first,
        );

    String gh(int i) => 'u${i}3${i}h$i';

    List<Item> items = [
      // 1) E-Bike with delivery at dropoff up to 10km
      Item(
        id: '1',
        ownerId: owner.id,
        title: 'E-Bike Trekking 28"',
        description: 'Top gepflegt, Akku 500Wh, sofort verfügbar.',
        categoryId: 'cat9',
        subcategory: 'E-Bikes',
        tags: const ['bike', 'e-bike', 'berlin'],
        pricePerDay: 19.0,
        currency: 'EUR',
        priceUnit: 'day',
        priceRaw: 19.0,
        photos: const [
          'https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=800&h=800&fit=crop',
        ],
        locationText: 'Berlin-Mitte',
        lat: berlin.$1,
        lng: berlin.$2,
        geohash: gh(1),
        condition: 'like-new',
        minDays: 1,
        maxDays: 14,
        createdAt: now.subtract(const Duration(hours: 2)),
        isActive: true,
        verificationStatus: 'approved',
        city: 'Berlin',
        country: 'Deutschland',
        timesLent: 42,
        offersDeliveryAtDropoff: true,
        offersPickupAtReturn: false,
        offersExpressAtDropoff: true,
        maxDeliveryKmAtDropoff: 10,
        cancellationPolicy: 'flexible',
      ),
      // 2) Kamera mit Abholung bei Rückgabe bis 12km
      Item(
        id: '2',
        ownerId: owner.id,
        title: 'Canon EOS R6 + 24-105mm',
        description: 'Spitzenzustand, inkl. 2 Akkus und Ladegerät.',
        categoryId: 'cat3',
        subcategory: 'Kameras',
        tags: const ['kamera', 'canon', 'berlin'],
        pricePerDay: 45.0,
        currency: 'EUR',
        priceUnit: 'day',
        priceRaw: 45.0,
        photos: const [
          'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=800&h=800&fit=crop',
        ],
        locationText: 'Berlin-Prenzlauer Berg',
        lat: berlin.$1 + 0.01,
        lng: berlin.$2 + 0.01,
        geohash: gh(2),
        condition: 'like-new',
        minDays: 1,
        maxDays: 7,
        createdAt: now.subtract(const Duration(hours: 3)),
        isActive: true,
        verificationStatus: 'approved',
        city: 'Berlin',
        country: 'Deutschland',
        timesLent: 31,
        offersDeliveryAtDropoff: false,
        offersPickupAtReturn: true,
        maxPickupKmAtReturn: 12,
        cancellationPolicy: 'moderate',
      ),
      // 3) PS5 – zeigt keine Lieferoption (reines Selbstabholen)
      Item(
        id: '3',
        ownerId: owner.id,
        title: 'PlayStation 5 Digital Edition',
        description:
            'Mit zweitem Controller, sehr leise, ideal fürs Wochenende.',
        categoryId: 'cat4',
        subcategory: 'Konsolen',
        tags: const ['gaming', 'ps5', 'berlin'],
        pricePerDay: 18.0,
        currency: 'EUR',
        priceUnit: 'day',
        priceRaw: 18.0,
        photos: const [
          'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&h=800&fit=crop',
        ],
        locationText: 'Berlin-Friedrichshain',
        lat: berlin.$1 - 0.01,
        lng: berlin.$2 - 0.01,
        geohash: gh(3),
        condition: 'good',
        minDays: 1,
        maxDays: 10,
        createdAt: now.subtract(const Duration(hours: 5)),
        isActive: true,
        verificationStatus: 'approved',
        city: 'Berlin',
        country: 'Deutschland',
        timesLent: 27,
        cancellationPolicy: 'strict',
      ),
      // 4) Dyson Staubsauger – Lieferung und Abholung mit je 5km
      Item(
        id: '4',
        ownerId: owner.id,
        title: 'Dyson Akku-Staubsauger V11',
        description: 'Sehr sauber, mit Wandhalterung und Extra-Düsen.',
        categoryId: 'cat5',
        subcategory: 'Staubsauger',
        tags: const ['haushalt', 'dyson', 'berlin'],
        pricePerDay: 12.0,
        currency: 'EUR',
        priceUnit: 'day',
        priceRaw: 12.0,
        photos: const [
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=800&fit=crop',
        ],
        locationText: 'Berlin-Charlottenburg',
        lat: berlin.$1 + 0.015,
        lng: berlin.$2 - 0.015,
        geohash: gh(4),
        condition: 'like-new',
        minDays: 1,
        maxDays: 14,
        createdAt: now.subtract(const Duration(hours: 7)),
        isActive: true,
        verificationStatus: 'approved',
        city: 'Berlin',
        country: 'Deutschland',
        timesLent: 15,
        offersDeliveryAtDropoff: true,
        offersPickupAtReturn: true,
        offersExpressAtDropoff: true,
        maxDeliveryKmAtDropoff: 5,
        maxPickupKmAtReturn: 5,
        cancellationPolicy: 'moderate',
      ),
      // 5) Bosch Bohrmaschine – Lieferung bis 7km, keine Abholung
      Item(
        id: '5',
        ownerId: owner.id,
        title: 'Bosch Bohrmaschine Professional',
        description: 'Robust, inkl. Koffer und Bohrer-Set.',
        categoryId: 'cat8',
        subcategory: 'Bohrmaschinen',
        tags: const ['werkzeug', 'bosch', 'berlin'],
        pricePerDay: 10.0,
        currency: 'EUR',
        priceUnit: 'day',
        priceRaw: 10.0,
        photos: const [
          'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&h=800&fit=crop',
        ],
        locationText: 'Berlin-Neukölln',
        lat: berlin.$1 - 0.02,
        lng: berlin.$2 + 0.01,
        geohash: gh(5),
        condition: 'good',
        minDays: 1,
        maxDays: 10,
        createdAt: now.subtract(const Duration(hours: 8)),
        isActive: true,
        verificationStatus: 'approved',
        city: 'Berlin',
        country: 'Deutschland',
        timesLent: 22,
        offersDeliveryAtDropoff: true,
        offersPickupAtReturn: false,
        offersExpressAtDropoff: true,
        maxDeliveryKmAtDropoff: 7,
        cancellationPolicy: 'flexible',
      ),
    ];

    // Ensure order: newest first
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static List<Review> _buildDemoReviews(List<User> users) {
    final now = DateTime.now();
    final existingIds = {for (final u in users) u.id};
    final List<Review> out = [];

    void add(
      String reviewerId,
      String reviewedUserId,
      double rating,
      String comment, {
      int daysAgo = 0,
      int hoursAgo = 0,
    }) {
      if (!existingIds.contains(reviewerId) ||
          !existingIds.contains(reviewedUserId) ||
          reviewerId == reviewedUserId) {
        return;
      }
      out.add(
        Review(
          id: 'r${out.length + 1}',
          reviewerId: reviewerId,
          reviewedUserId: reviewedUserId,
          rating: rating,
          comment: comment,
          createdAt: now.subtract(Duration(days: daysAgo, hours: hoursAgo)),
        ),
      );
    }

    add(
      'u1',
      'u2',
      4.9,
      'Werkzeug war in Top-Zustand, Übergabe super flexibel.',
      daysAgo: 6,
      hoursAgo: 3,
    );
    add(
      'u7',
      'u2',
      5.0,
      'Sehr hilfsbereit und schnelle Antworten auf Rückfragen.',
      daysAgo: 20,
      hoursAgo: 6,
    );
    add(
      'u11',
      'u3',
      4.8,
      'Abholung lief reibungslos, würde wieder bei Sarah mieten.',
      daysAgo: 9,
      hoursAgo: 2,
    );
    add(
      'u5',
      'u3',
      4.7,
      'Kamera war wie beschrieben, inklusive voll geladenem Akku.',
      daysAgo: 32,
      hoursAgo: 4,
    );
    add(
      'u10',
      'u6',
      5.0,
      'David hat sich Zeit für eine kurze Einweisung genommen, top.',
      daysAgo: 12,
      hoursAgo: 5,
    );
    add(
      'u12',
      'u6',
      4.9,
      'Sehr freundlich und flexibel bei der Rückgabe.',
      daysAgo: 45,
      hoursAgo: 7,
    );
    add(
      'u9',
      'u8',
      4.8,
      'Laura hat den Zustand des E-Bikes genau erklärt, alles bestens.',
      daysAgo: 3,
      hoursAgo: 1,
    );
    add(
      'u14',
      'u8',
      5.0,
      'Super Kommunikation und perfektes Zubehör dabei.',
      daysAgo: 14,
      hoursAgo: 8,
    );
    add(
      'u17',
      'u10',
      4.7,
      'Konsole war sauber und sofort einsatzbereit.',
      daysAgo: 27,
      hoursAgo: 6,
    );
    add(
      'u18',
      'u10',
      4.9,
      'Schnelle Übergabe und sehr sympathisch.',
      daysAgo: 58,
      hoursAgo: 3,
    );
    add(
      'u19',
      'u9',
      4.8,
      'MacBook in neuwertigem Zustand, gerne wieder.',
      daysAgo: 16,
      hoursAgo: 2,
    );
    add(
      'u20',
      'u9',
      4.6,
      'Abholung pünktlich und unkompliziert organisiert.',
      daysAgo: 70,
      hoursAgo: 5,
    );
    add(
      'u15',
      'u4',
      4.9,
      'Thomas hat alles ausführlich erklärt, super Service.',
      daysAgo: 22,
      hoursAgo: 4,
    );
    add(
      'u13',
      'u4',
      4.8,
      'Sehr zuverlässige Abstimmung und faire Konditionen.',
      daysAgo: 90,
      hoursAgo: 6,
    );
    add(
      'u8',
      'u5',
      4.7,
      'Julia hat schnell auf Nachrichten reagiert und war flexibel.',
      daysAgo: 11,
      hoursAgo: 7,
    );
    add(
      'u6',
      'u5',
      4.9,
      'Produkt top gepflegt, klare Empfehlung.',
      daysAgo: 61,
      hoursAgo: 2,
    );

    return out;
  }

  static Future<List<Review>> _getAllReviews() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString(_reviewsKey);
    if (raw == null) {
      List<User> seedUsers = const <User>[];
      try {
        final usersJson = prefs.getString(_usersKey);
        if (usersJson != null && usersJson.isNotEmpty) {
          final List<dynamic> usersList = jsonDecode(usersJson);
          seedUsers = usersList
              .map((e) => User.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (_) {}
      final seed = _buildDemoReviews(seedUsers);
      await prefs.setString(
        _reviewsKey,
        jsonEncode(seed.map((e) => e.toJson()).toList()),
      );
      raw = prefs.getString(_reviewsKey);
    }
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => Review.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ===== Multi-criteria reviews (immutable, local storage) =====
  static Future<List<MultiCriteriaReview>> _getAllMultiReviews() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString(_multiReviewsKey);
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return [
        for (final e in list)
          MultiCriteriaReview.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAllMultiReviews(
    List<MultiCriteriaReview> list,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _multiReviewsKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<bool> hasSubmittedReview({
    required String requestId,
    required String reviewerId,
  }) async {
    final all = await _getAllMultiReviews();
    return all.any(
      (r) => r.requestId == requestId && r.reviewerId == reviewerId,
    );
  }

  static Future<MultiCriteriaReview> addMultiReview({
    required String requestId,
    required String itemId,
    required String reviewerId,
    required String reviewedUserId,
    required String direction,
    required List<ReviewCriterion> criteria,
  }) async {
    final all = await _getAllMultiReviews();
    final requests = await _getAllRentalRequests();
    final request = requests.cast<RentalRequest?>().firstWhere(
          (entry) => entry?.id == requestId,
          orElse: () => null,
        );
    if (request == null || request.status != 'completed') {
      throw StateError('Reviews require a completed booking.');
    }
    if (request.needsReview) {
      throw StateError(
          'Reviews are blocked while this booking is under review.');
    }

    final reviewerMatchesDirection =
        (direction == ReviewMetricsService.renterToOwner &&
                request.renterId == reviewerId &&
                request.ownerId == reviewedUserId) ||
            (direction == ReviewMetricsService.ownerToRenter &&
                request.ownerId == reviewerId &&
                request.renterId == reviewedUserId);
    if (!reviewerMatchesDirection || request.itemId != itemId) {
      throw StateError('Review context does not match the completed booking.');
    }

    final nextId = (all.fold<int>(
              0,
              (p, e) =>
                  (int.tryParse(e.id) ?? 0) > p ? (int.tryParse(e.id) ?? 0) : p,
            ) +
            1)
        .toString();
    final normalizedCriteria = ReviewMetricsService.normalizeCriteria(
      criteria,
      direction: direction,
    );
    final review = MultiCriteriaReview(
      id: nextId,
      requestId: requestId,
      itemId: itemId,
      reviewerId: reviewerId,
      reviewedUserId: reviewedUserId,
      direction: direction,
      criteria: normalizedCriteria,
      createdAt: DateTime.now(),
    );

    if (!ReviewMetricsService.isRegularCompleteReview(review)) {
      throw ArgumentError('Review is incomplete or invalid.');
    }
    if (all.any((entry) => entry.id == review.id)) {
      throw StateError('Duplicate review id.');
    }
    if (all.any(
      (entry) => entry.requestId == requestId && entry.reviewerId == reviewerId,
    )) {
      throw StateError('Review already exists for this booking context.');
    }

    all.add(review);
    await _saveAllMultiReviews(all);
    return review;
  }

  static Future<List<MultiCriteriaReview>> getMultiReviewsForUser(
    String userId,
  ) async {
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final remote = await BackendRepository.getUserReviews(userId);
      return remote
          .map((entry) => MultiCriteriaReview.fromJson({
                ...entry,
                'requestId': entry['bookingId'],
              }))
          .toList();
    }
    final all = await _getAllMultiReviews();
    final filtered = all.where((e) => e.reviewedUserId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  static Future<List<MultiCriteriaReview>> getMultiReviewsForUserByItem(
    String userId,
    String itemId,
  ) async {
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final all = await getMultiReviewsForUser(userId);
      return all.where((entry) => entry.itemId == itemId).toList();
    }
    final all = await _getAllMultiReviews();
    final filtered = all
        .where((e) => e.reviewedUserId == userId && e.itemId == itemId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  static Future<List<Review>> getReviewsForUser(String userId) async {
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final remote = await BackendRepository.getUserReviews(userId);
      return remote.map((entry) {
        final notes = (entry['criteria'] as List? ?? const [])
            .whereType<Map>()
            .map((criterion) => criterion['note']?.toString() ?? '')
            .where((note) => note.isNotEmpty)
            .join('\n');
        return Review(
          id: entry['id']?.toString() ?? '',
          reviewerId: entry['reviewerId']?.toString() ?? '',
          reviewedUserId: entry['reviewedUserId']?.toString() ?? userId,
          rating: (entry['rating'] as num?)?.toDouble() ?? 0,
          comment: notes,
          createdAt: DateTime.tryParse(entry['createdAt']?.toString() ?? '') ??
              DateTime.now(),
        );
      }).toList();
    }
    final all = await _getAllReviews();
    final filtered = all
        .where((review) => review.reviewedUserId == userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  static const Map<String, String> _demoReviewItemIdByReviewId = {
    'r1': '5',
    'r2': '1',
    'r3': '2',
    'r4': '2',
    'r5': '4',
    'r6': '4',
    'r7': '1',
    'r8': '1',
    'r9': '3',
    'r10': '3',
    'r11': '2',
    'r12': '2',
    'r13': '5',
    'r14': '5',
    'r15': '4',
    'r16': '4',
  };

  static final Map<String, List<ReviewCriterion>>
      _demoReviewCriteriaByReviewId = {
    'r1': const [
      ReviewCriterion(
        key: 'communication',
        stars: 5,
        note: 'Schnelle Rückmeldung',
      ),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(
        key: 'article_as_described',
        stars: 5,
        note: 'Genau wie beschrieben',
      ),
      ReviewCriterion(
        key: 'handover_return',
        stars: 5,
        note: 'Sehr gepflegt übergeben',
      ),
    ],
    'r2': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
    'r3': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
    'r4': const [
      ReviewCriterion(key: 'communication', stars: 4),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 4),
    ],
    'r5': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
    'r6': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 4),
    ],
    'r7': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 4),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
    'r8': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
    'r9': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
    'r10': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
    'r11': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
    'r12': const [
      ReviewCriterion(key: 'communication', stars: 4),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 4),
      ReviewCriterion(key: 'handover_return', stars: 4),
    ],
    'r13': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
    'r14': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
    'r15': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 4),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
    'r16': const [
      ReviewCriterion(key: 'communication', stars: 5),
      ReviewCriterion(key: 'reliability', stars: 5),
      ReviewCriterion(key: 'article_as_described', stars: 5),
      ReviewCriterion(key: 'handover_return', stars: 5),
    ],
  };

  static MultiCriteriaReview? _buildSyntheticMultiReviewForClassic(
    Review review,
  ) {
    final criteria = _demoReviewCriteriaByReviewId[review.id];
    if (criteria == null) return null;
    return MultiCriteriaReview(
      id: 'seed_${review.id}',
      requestId: 'seed_${review.id}',
      itemId: _demoReviewItemIdByReviewId[review.id] ?? '',
      reviewerId: review.reviewerId,
      reviewedUserId: review.reviewedUserId,
      direction: criteria.any(
        (c) =>
            c.key == 'condition_dropoff' ||
            c.key == 'description_accuracy' ||
            c.key == 'value_for_money',
      )
          ? 'renter_to_owner'
          : 'owner_to_renter',
      criteria: criteria,
      createdAt: review.createdAt,
    );
  }

  static Future<List<ReviewWithUser>> _buildReviewSummaryEntries({
    required List<User> users,
    List<Item> items = const [],
    String? reviewedUserId,
  }) async {
    final classic = await _getAllReviews();
    final multi = await _getAllMultiReviews();
    final byId = {for (final u in users) u.id: u};
    final itemsById = {for (final item in items) item.id: item};
    final entries = <ReviewWithUser>[];

    for (final review in classic) {
      if (reviewedUserId != null && review.reviewedUserId != reviewedUserId) {
        continue;
      }
      final synthetic = _buildSyntheticMultiReviewForClassic(review);
      final normalizedSynthetic = synthetic == null
          ? null
          : ReviewMetricsService.normalizeReview(synthetic);
      final correctedRating = normalizedSynthetic == null
          ? ReviewMetricsService.roundToSingleDecimal(review.rating)
          : (ReviewMetricsService.calculateReviewScore(normalizedSynthetic) ??
              ReviewMetricsService.roundToSingleDecimal(review.rating));
      entries.add(
        ReviewWithUser(
          review: review.copyWith(rating: correctedRating),
          reviewer: byId[review.reviewerId],
          item: itemsById[_demoReviewItemIdByReviewId[review.id] ?? ''],
          requestId: normalizedSynthetic?.requestId,
          multiReview: normalizedSynthetic,
        ),
      );
    }

    for (final review in multi) {
      if (reviewedUserId != null && review.reviewedUserId != reviewedUserId) {
        continue;
      }
      final normalizedReview = ReviewMetricsService.normalizeReview(review);
      final previewComment = _buildCompactReviewPreview(
        normalizedReview.criteria,
      );
      final rating =
          ReviewMetricsService.calculateReviewScore(normalizedReview) ?? 0.0;
      entries.add(
        ReviewWithUser(
          review: Review(
            id: 'mc_${review.id}',
            reviewerId: review.reviewerId,
            reviewedUserId: review.reviewedUserId,
            rating: rating,
            comment: previewComment,
            createdAt: review.createdAt,
          ),
          reviewer: byId[review.reviewerId],
          item: itemsById[review.itemId],
          requestId: review.requestId,
          multiReview: normalizedReview,
        ),
      );
    }

    return ReviewMetricsService.normalizeReviewEntries(entries);
  }

  static Future<List<User>> _applyCentralReviewStatsToUsers(
    List<User> users,
  ) async {
    if (users.isEmpty) return users;
    final entries = await _buildReviewSummaryEntries(users: users);
    final grouped = <String, List<ReviewWithUser>>{};
    for (final entry in entries) {
      grouped
          .putIfAbsent(entry.review.reviewedUserId, () => <ReviewWithUser>[])
          .add(entry);
    }
    return [
      for (final user in users)
        (() {
          final summary = ReviewMetricsService.calculateUserSummary(
            grouped[user.id] ?? const <ReviewWithUser>[],
          );
          return user.copyWith(
            avgRating: summary.averageRating,
            reviewCount: summary.reviewCount,
          );
        })(),
    ];
  }

  static Future<List<ReviewWithUser>> getReviewSummariesForUser(
    String userId,
  ) async {
    final users = await getUsers();
    final items = await getItems();
    return _buildReviewSummaryEntries(
      users: users,
      items: items,
      reviewedUserId: userId,
    );
  }

  static String _buildCompactReviewPreview(
    List<ReviewCriterion> criteria, {
    String? generalComment,
  }) {
    final normalizedGeneralComment = generalComment?.trim();
    if (normalizedGeneralComment != null &&
        normalizedGeneralComment.isNotEmpty) {
      return normalizedGeneralComment;
    }

    const previewOrder = <String>[
      'reliability',
      'article_as_described',
      'handover_return',
      'communication',
    ];

    for (final key in previewOrder) {
      for (final criterion in criteria) {
        if (criterion.key != key) continue;
        final note = criterion.note?.trim();
        if (note != null && note.isNotEmpty) {
          return note;
        }
      }
    }

    return '';
  }

  // Quick helpers
  static Future<Item?> getItemById(String id) async {
    final items = await getItems();
    try {
      return items.firstWhere((e) => e.id.toString() == id.toString());
    } catch (_) {
      return null;
    }
  }

  static Future<User?> getUserById(String id) async {
    final users = await getUsers();
    try {
      return users.firstWhere((e) => e.id.toString() == id.toString());
    } catch (_) {
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        try {
          final remote = await BackendRepository.getPublicProfile(id);
          if (remote != null) {
            final user = User.fromJson(remote);
            final prefs = await SharedPreferences.getInstance();
            await _upsertCachedUser(prefs, user);
            return user;
          }
        } catch (error) {
          debugPrint('[DataService] public profile load failed: $error');
        }
      }
      return null;
    }
  }

  // Rental requests storage (demo, persisted locally)
  static Future<List<RentalRequest>> _getAllRentalRequests() async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint(
        '[DataService] _getAllRentalRequests: SharedPreferences unavailable: $e',
      );
      return [];
    }

    String? raw;
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      try {
        final remote = await BackendRepository.getRentalRequests();
        raw = jsonEncode(remote);
        await prefs.setString(_rentalRequestsKey, raw);
      } catch (error) {
        debugPrint('[DataService] remote request load failed: $error');
      }
    }
    raw ??= prefs.getString(_rentalRequestsKey);
    if (raw == null) {
      // Do not seed demo requests anymore. Persist an empty list by default.
      try {
        await prefs.setString(
          _rentalRequestsKey,
          jsonEncode(<Map<String, dynamic>>[]),
        );
        raw = prefs.getString(_rentalRequestsKey);
      } catch (e) {
        debugPrint(
          '[DataService] _getAllRentalRequests: failed to initialize empty list: $e',
        );
        return [];
      }
    }
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(raw);
      final parsed = <RentalRequest>[];
      for (final e in list) {
        try {
          parsed.add(
            RentalRequest.fromJson(Map<String, dynamic>.from(e as Map)),
          );
        } catch (inner) {
          debugPrint(
            '[DataService] _getAllRentalRequests: skipping corrupted entry: $inner',
          );
        }
      }

      // Auto-sanitize storage so future loads don't keep failing.
      if (parsed.length != list.length) {
        try {
          await prefs.setString(
            _rentalRequestsKey,
            jsonEncode(parsed.map((e) => e.toJson()).toList()),
          );
        } catch (e) {
          debugPrint(
            '[DataService] _getAllRentalRequests: failed to sanitize storage: $e',
          );
        }
      }
      return parsed;
    } catch (e) {
      debugPrint(
        '[DataService] _getAllRentalRequests: failed to decode JSON: $e',
      );
      // Reset to a clean state.
      try {
        await prefs.setString(
          _rentalRequestsKey,
          jsonEncode(<Map<String, dynamic>>[]),
        );
      } catch (e2) {
        debugPrint(
          '[DataService] _getAllRentalRequests: failed to reset corrupted JSON: $e2',
        );
      }
      return [];
    }
  }

  static Future<void> _saveAllRentalRequests(List<RentalRequest> list) async {
    Future<void> persist(List<RentalRequest> payload) async {
      final prefs = await SharedPreferences.getInstance();
      var maps = payload.map((entry) => entry.toJson()).toList();
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        maps = await BackendRepository.syncRentalRequests(maps);
      }
      await prefs.setString(
        _rentalRequestsKey,
        jsonEncode(maps),
      );
      SharedPersistenceSync.notify(SharedPersistenceSync.rentalRequestsKey);
    }

    bool isQuotaError(Object e) {
      final s = e.toString();
      return s.contains('QuotaExceededError') ||
          s.contains('exceeded the quota') ||
          s.contains('QuotaExceeded');
    }

    List<RentalRequest> prune(
      List<RentalRequest> input, {
      required int hardCapNewest,
    }) {
      if (input.isEmpty) return input;
      // Newest first for keeping.
      final newestFirst = [...input]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // Prefer dropping old terminal states first.
      final terminal = <String>{'completed', 'declined', 'cancelled'};
      final kept = <RentalRequest>[];
      final droppedTerminal = <RentalRequest>[];
      for (final r in newestFirst) {
        if (terminal.contains(r.status)) {
          droppedTerminal.add(r);
        } else {
          kept.add(r);
        }
      }
      final merged = [...kept, ...droppedTerminal];
      // Apply cap.
      return merged.take(hardCapNewest).toList();
    }

    try {
      await persist(list);
      return;
    } catch (e) {
      debugPrint('[DataService] _saveAllRentalRequests: failed: $e');
      if (!isQuotaError(e)) rethrow;
    }

    // Web/local storage quota exceeded: prune older requests and retry.
    try {
      final pruned250 = prune(list, hardCapNewest: 250);
      debugPrint(
        '[DataService] _saveAllRentalRequests: quota exceeded, pruning from ${list.length} -> ${pruned250.length} and retrying',
      );
      await persist(pruned250);
      return;
    } catch (e) {
      debugPrint(
        '[DataService] _saveAllRentalRequests: retry after prune(250) failed: $e',
      );
      if (!isQuotaError(e)) rethrow;
    }

    // Last resort: keep only the newest 80.
    try {
      final pruned80 = prune(list, hardCapNewest: 80);
      debugPrint(
        '[DataService] _saveAllRentalRequests: quota still exceeded, pruning to newest ${pruned80.length} and retrying',
      );
      await persist(pruned80);
      return;
    } catch (e) {
      debugPrint(
        '[DataService] _saveAllRentalRequests: retry after prune(80) failed: $e',
      );
      rethrow;
    }
  }

  static Future<List<RentalRequest>> getRentalRequestsForOwner(
    String ownerId, {
    String? status,
  }) async {
    await _sweepExpressTimeouts();
    final all = await _getAllRentalRequests();
    final filtered = all
        .where(
          (r) => r.ownerId == ownerId && (status == null || r.status == status),
        )
        .toList();
    // Sort newest first
    filtered.sort((a, b) => b.start.compareTo(a.start));
    return filtered;
  }

  /// Returns true if there exists at least one PENDING request that is newer
  /// than the last time the owner viewed the Anfragen tab.
  static Future<bool> hasNewOwnerRequests(String ownerId) async {
    if (ownerId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    DateTime? lastSeen;
    try {
      final raw = prefs.getString(_requestsLastSeenKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final s = map[ownerId]?.toString();
        if (s != null && s.isNotEmpty) lastSeen = DateTime.tryParse(s);
      }
    } catch (_) {}

    final pending = await getRentalRequestsForOwner(ownerId, status: 'pending');
    if (pending.isEmpty) return false;
    // Latest by createdAt
    pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = pending.first.createdAt;
    if (lastSeen == null) return true;
    return latest.isAfter(lastSeen);
  }

  /// Marks all current requests as seen for the owner. We store the timestamp
  /// of the newest request at the time the tab is opened, so future requests
  /// created after that will be considered "new".
  static Future<void> markOwnerRequestsSeen(String ownerId) async {
    if (ownerId.isEmpty) return;
    final pending = await getRentalRequestsForOwner(
      ownerId,
    ); // include all statuses
    DateTime nowMarker;
    if (pending.isEmpty) {
      nowMarker = DateTime.now();
    } else {
      // Use the latest createdAt among all requests so we don't miss any
      pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      nowMarker = pending.first.createdAt;
    }
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_requestsLastSeenKey);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        map = jsonDecode(raw) as Map<String, dynamic>;
      }
      map[ownerId] = nowMarker.toIso8601String();
      await prefs.setString(_requestsLastSeenKey, jsonEncode(map));
    } catch (_) {
      // Fallback: write fresh map
      await prefs.setString(
        _requestsLastSeenKey,
        jsonEncode({ownerId: nowMarker.toIso8601String()}),
      );
    }
  }

  /// Marks a specific rental request as read by a user (owner or renter).
  /// Used to track which individual requests have been viewed.
  static Future<void> markRequestAsRead({
    required String userId,
    required String requestId,
  }) async {
    if (userId.isEmpty || requestId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_readRequestsKey);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        map = jsonDecode(raw) as Map<String, dynamic>;
      }
      // Get the user's read set
      List<dynamic> readList = (map[userId] as List<dynamic>?) ?? [];
      Set<String> readSet = readList.map((e) => e.toString()).toSet();

      if (!readSet.contains(requestId)) {
        readSet.add(requestId);
        map[userId] = readSet.toList();
        await prefs.setString(_readRequestsKey, jsonEncode(map));
      }
    } catch (e) {
      debugPrint('[DataService] markRequestAsRead error: $e');
    }
  }

  /// Checks if a specific request has been read by a user.
  static Future<bool> isRequestRead({
    required String userId,
    required String requestId,
  }) async {
    if (userId.isEmpty || requestId.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_readRequestsKey);
      if (raw == null || raw.isEmpty) return false;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final readList = (map[userId] as List<dynamic>?) ?? [];
      final readSet = readList.map((e) => e.toString()).toSet();

      return readSet.contains(requestId);
    } catch (e) {
      debugPrint('[DataService] isRequestRead error: $e');
      return false;
    }
  }

  /// Returns count of unread requests for a user in a specific category.
  /// Category can be: 'ongoing', 'upcoming', 'requests', 'pending', 'completed'
  static Future<int> getUnreadCountForCategory({
    required String userId,
    required String category,
    required List<RentalRequest> requests,
  }) async {
    if (userId.isEmpty) return 0;
    try {
      int unreadCount = 0;
      for (final req in requests) {
        final isRead = await isRequestRead(userId: userId, requestId: req.id);
        if (!isRead) unreadCount++;
      }
      return unreadCount;
    } catch (e) {
      debugPrint('[DataService] getUnreadCountForCategory error: $e');
      return 0;
    }
  }

  static Future<RentalRequest?> getRentalRequestById(String id) async {
    await _sweepExpressTimeouts();
    final all = await _getAllRentalRequests();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<RentalRequest> addRentalRequest(
    RentalRequest req, {
    Map<String, dynamic>? checkoutQuote,
  }) async {
    final all = await _getAllRentalRequests();
    final nextId = BackendConfig.enabled && !QaRuntimeService.isEnabled
        ? 'request_${DateTime.now().microsecondsSinceEpoch}'
        : (all.fold<int>(
                  0,
                  (p, e) => (int.tryParse(e.id) ?? 0) > p
                      ? (int.tryParse(e.id) ?? 0)
                      : p,
                ) +
                1)
            .toString();
    final now = DateTime.now();
    // Snapshot current delivery selection for this item so booking details remain accurate
    Map<String, dynamic>? deliverySel;
    try {
      deliverySel = await getSavedDeliverySelection(req.itemId);
    } catch (_) {
      deliverySel = null;
    }
    final bool ownerDelivers = (deliverySel?['hinweg'] == true);
    final bool ownerPicksUp = (deliverySel?['rueckweg'] == true);
    // Compute renter-facing quoted total and subtitle exactly as seen at booking time
    double? quotedTotal;
    String? quotedSub;
    try {
      final item = await getItemById(req.itemId);
      if (item != null) {
        final breakdown = priceBreakdownForRequest(
          item: item,
          req: req,
          deliverySel: deliverySel,
        );
        final bool expressSelectedTransient = (deliverySel?['express'] == true);
        final bool expressAccepted =
            req.expressRequested && (req.expressStatus == 'accepted');
        final bool priority =
            expressSelectedTransient || req.expressRequested || expressAccepted;
        quotedTotal = breakdown.totalRenter;
        quotedSub = TotalSubtitleHelper.build(
          delivery: ownerDelivers,
          pickup: ownerPicksUp,
          priority: priority,
        );
      }
    } catch (e) {
      debugPrint(
        '[DataService] addRentalRequest: failed to compute quoted total: $e',
      );
    }
    var toStore = RentalRequest(
      id: nextId,
      itemId: req.itemId,
      ownerId: req.ownerId,
      renterId: req.renterId,
      start: req.start,
      end: req.end,
      status: req.status,
      message: req.message,
      expressRequested: req.expressRequested,
      expressStatus: req.expressStatus,
      expressFee: req.expressFee,
      ownerDeliversAtDropoffChosen: ownerDelivers,
      ownerPicksUpAtReturnChosen: ownerPicksUp,
      deliveryAddressLine: (deliverySel?['deliveryAddressLine'] as String?) ??
          (deliverySel?['addressLine'] as String?),
      deliveryCity: (deliverySel?['deliveryCity'] as String?) ??
          (deliverySel?['city'] as String?),
      deliveryLat: (deliverySel?['deliveryLat'] as num?)?.toDouble() ??
          (deliverySel?['lat'] as num?)?.toDouble(),
      deliveryLng: (deliverySel?['deliveryLng'] as num?)?.toDouble() ??
          (deliverySel?['lng'] as num?)?.toDouble(),
      returnAddressLine: (deliverySel?['returnAddressLine'] as String?),
      returnCity: (deliverySel?['returnCity'] as String?),
      returnLat: (deliverySel?['returnLat'] as num?)?.toDouble(),
      returnLng: (deliverySel?['returnLng'] as num?)?.toDouble(),
      createdAt: now,
      expressRequestedAt: req.expressRequested ? now : null,
      expressConfirmedAt: null,
      quotedTotalRenter: quotedTotal,
      quotedSubtitle: quotedSub,
      privateStatusConfirmed: req.privateStatusConfirmed,
      quotedRentalSubtotalMinor: req.quotedRentalSubtotalMinor,
      quotedPlatformFeeMinor: req.quotedPlatformFeeMinor,
      quotedTotalMinor: req.quotedTotalMinor,
      legalDeclarations: req.legalDeclarations,
      returnState: req.returnState,
      returnT0: req.returnT0,
      returnReportDeadline: req.returnReportDeadline,
      returnClarificationDeadline: req.returnClarificationDeadline,
      returnCaseOpenedAt: req.returnCaseOpenedAt,
      returnCaseClosedAt: req.returnCaseClosedAt,
      reviewEvidenceReferences: req.reviewEvidenceReferences,
      contestedAuthorizedMinor: req.contestedAuthorizedMinor,
      allegedDamageMinorRecordedOnly: req.allegedDamageMinorRecordedOnly,
    );
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final createPayload = toStore.toJson();
      final freshQuote = checkoutQuote == null
          ? await BackendRepository.quoteBooking(createPayload)
          : Map<String, dynamic>.from(checkoutQuote);
      final quoteId = freshQuote['quoteId'] as String?;
      final quoteHash = freshQuote['quoteHash'] as String?;
      final expiresAt = DateTime.tryParse(
        freshQuote['expiresAt']?.toString() ?? '',
      );
      if (quoteId == null ||
          quoteHash == null ||
          expiresAt == null ||
          !expiresAt.isAfter(DateTime.now().toUtc())) {
        throw StateError('Der Server hat kein bindendes Angebot geliefert.');
      }
      createPayload['quoteId'] = quoteId;
      createPayload['quoteHash'] = quoteHash;
      final remote = await BackendRepository.createBooking(
        createPayload,
        idempotencyKey: 'create_$nextId',
      );
      toStore = RentalRequest.fromJson(remote);
      all.removeWhere((entry) => entry.id == toStore.id);
      all.add(toStore);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _rentalRequestsKey,
        jsonEncode(all.map((entry) => entry.toJson()).toList()),
      );
      SharedPersistenceSync.notify(SharedPersistenceSync.rentalRequestsKey);
    } else {
      all.add(toStore);
      await _saveAllRentalRequests(all);
    }
    debugPrint(
      '[DataService] addRentalRequest stored id=$nextId ownerDeliversAtDropoffChosen=$ownerDelivers ownerPicksUpAtReturnChosen=$ownerPicksUp expressRequested=${toStore.expressRequested}',
    );

    try {
      final item = await getItemById(toStore.itemId);
      final renter = await getUserById(toStore.renterId);
      if (item != null) {
        await addStructuredNotification(
          userId: toStore.ownerId,
          category: 'bookings',
          priority: 2,
          title: 'Neue Mietanfrage eingegangen',
          body:
              '${renter?.displayName ?? 'Ein Mieter'} möchte „${item.title}“ vom ${toStore.start.day.toString().padLeft(2, '0')}.${toStore.start.month.toString().padLeft(2, '0')}.${toStore.start.year} bis ${toStore.end.day.toString().padLeft(2, '0')}.${toStore.end.month.toString().padLeft(2, '0')}.${toStore.end.year} mieten.',
          entityType: 'booking',
          entityId: toStore.id,
          ctaLabel: 'Anfrage prüfen',
          payload: {
            'requestId': toStore.id,
            'listingId': toStore.itemId,
            'counterpartyUserId': toStore.renterId,
            'counterpartyName': renter?.displayName ?? '',
            'role': 'owner',
          },
        );
      }
    } catch (e) {
      debugPrint('[DataService] pending-request notification failed: $e');
    }

    // Start 30-minute express confirmation timer if applicable (runtime only)
    _scheduleExpressTimerIfNeeded(toStore);
    return toStore;
  }

  static Future<void> updateRentalRequestStatus({
    required String requestId,
    required String status,
    List<Map<String, dynamic>>? legalDeclarations,
  }) async {
    final all = await _getAllRentalRequests();
    bool mutated = false;
    RentalRequest? updatedRequest;
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final index = all.indexWhere((entry) => entry.id == requestId);
      if (index >= 0) {
        final current = all[index];
        final remote = await BackendRepository.transitionBooking(
          bookingId: requestId,
          status: status,
          idempotencyKey: 'transition_${requestId}_${current.status}_$status',
          legalDeclarations: legalDeclarations,
        );
        updatedRequest = RentalRequest.fromJson(remote);
        all[index] = updatedRequest;
        mutated = true;
      }
    } else {
      for (int i = 0; i < all.length; i++) {
        if (all[i].id == requestId) {
          all[i] = all[i].copyWith(
            status: status,
            legalDeclarations: legalDeclarations == null
                ? all[i].legalDeclarations
                : [...all[i].legalDeclarations, ...legalDeclarations],
          );
          if (status == 'accepted' && all[i].acceptedAt == null) {
            all[i] = all[i].copyWith(acceptedAt: DateTime.now());
          }
          updatedRequest = all[i];
          mutated = true;
          break;
        }
      }
    }
    if (mutated) {
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _rentalRequestsKey,
          jsonEncode(all.map((entry) => entry.toJson()).toList()),
        );
        SharedPersistenceSync.notify(SharedPersistenceSync.rentalRequestsKey);
      } else {
        await _saveAllRentalRequests(all);
      }

      // Wenn die Anfrage angenommen wurde, erstelle einen Message Thread
      if (status == 'accepted' && updatedRequest != null) {
        try {
          await _createMessageThreadForRequest(updatedRequest);

          // Create in-app notifications for both parties.
          try {
            final item = await getItemById(updatedRequest.itemId);
            if (item != null) {
              // For renter
              await addStructuredNotification(
                userId: updatedRequest.renterId,
                category: 'bookings',
                priority: 2,
                title: 'Mietanfrage angenommen',
                body:
                    'Deine Anfrage für „${item.title}“ wurde angenommen. Öffne die Buchung für Details.',
                entityType: 'booking',
                entityId: updatedRequest.id,
                ctaLabel: 'Zur Buchung',
                payload: {
                  'requestId': updatedRequest.id,
                  'listingId': updatedRequest.itemId,
                  'counterpartyUserId': updatedRequest.ownerId,
                  'role': 'renter',
                },
              );
              // For owner
              await addStructuredNotification(
                userId: updatedRequest.ownerId,
                category: 'bookings',
                priority: 2,
                title: 'Buchung bestätigt',
                body:
                    'Du hast die Anfrage für „${item.title}“ angenommen. Öffne die Vermietung für Übergabe & Rückgabe.',
                entityType: 'booking',
                entityId: updatedRequest.id,
                ctaLabel: 'Zur Vermietung',
                payload: {
                  'requestId': updatedRequest.id,
                  'listingId': updatedRequest.itemId,
                  'counterpartyUserId': updatedRequest.renterId,
                  'role': 'owner',
                },
              );
            }
          } catch (e) {
            debugPrint('[DataService] booking notifications failed: $e');
          }
        } catch (e) {
          debugPrint('[DataService] Failed to create message thread: $e');
        }
      }
    }
  }

  /// Update status and optionally set the actor who cancelled.
  /// If [status] is 'cancelled' and [cancelledBy] is provided, we persist it.
  static Future<void> updateRentalRequestStatusWithActor({
    required String requestId,
    required String status,
    String? cancelledBy,
  }) async {
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      await updateRentalRequestStatus(requestId: requestId, status: status);
      return;
    }
    final all = await _getAllRentalRequests();
    bool mutated = false;
    for (int i = 0; i < all.length; i++) {
      if (all[i].id == requestId) {
        Map<String, dynamic>? cancellationOutcome;
        if (status == 'cancelled') {
          final current = all[i];
          final actor = cancelledBy == 'owner'
              ? PrivatePilotCancellationActor.owner
              : PrivatePilotCancellationActor.renter;
          final outcome = PrivatePilotCancellationPolicy.evaluate(
            rentalStartAt: current.start,
            cancelAt: DateTime.now(),
            actor: actor,
            contractConfirmedAt: current.acceptedAt,
          );
          final totalMinor = current.quotedTotalMinor ?? 0;
          cancellationOutcome = {
            'refundBasisPoints': outcome.refundBasisPoints,
            'refundMinor': outcome.refundMinor(totalMinor),
            'retainedMinor': outcome.retainedMinor(totalMinor),
            'reasonCode': outcome.reasonCode,
            'freeCancellationUntil':
                outcome.freeCancellationUntil?.toIso8601String(),
            'calculatedAt': DateTime.now().toIso8601String(),
            'modelVersion': PrivatePilotConfig.documentVersion,
          };
        }
        all[i] = all[i].copyWith(
          status: status,
          cancelledBy: (status == 'cancelled')
              ? (cancelledBy ?? all[i].cancelledBy)
              : all[i].cancelledBy,
          cancellationOutcome:
              cancellationOutcome ?? all[i].cancellationOutcome,
        );
        mutated = true;
        break;
      }
    }
    if (mutated) await _saveAllRentalRequests(all);
  }

  static Future<void> recordRentalRequestConfirmation({
    required String requestId,
    required bool isReturn,
    required String method,
    required String confirmedByRole,
    required String confirmedByUserId,
    bool counterpartyConfirmed = false,
  }) async {
    final id = requestId.trim();
    final userId = confirmedByUserId.trim();
    if (id.isEmpty || userId.isEmpty) return;
    final all = await _getAllRentalRequests();
    bool mutated = false;
    final payload = <String, dynamic>{
      'method': method,
      'confirmedByRole': confirmedByRole,
      'confirmedByUserId': userId,
      'confirmedAt': DateTime.now().toIso8601String(),
    };
    for (int i = 0; i < all.length; i++) {
      if (all[i].id == id) {
        if (isReturn) {
          final existing = all[i].returnConfirmation == null
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(all[i].returnConfirmation!);
          final confirmedAt = payload['confirmedAt'];
          if (confirmedByRole == 'owner') {
            existing['ownerConfirmedAt'] = confirmedAt;
            if (counterpartyConfirmed) {
              existing['renterConfirmedAt'] = confirmedAt;
            }
          } else if (confirmedByRole == 'renter') {
            existing['renterConfirmedAt'] = confirmedAt;
            if (counterpartyConfirmed) {
              existing['ownerConfirmedAt'] = confirmedAt;
            }
          }
          payload.addAll(existing);
        }
        all[i] = all[i].copyWith(
          handoverConfirmation:
              isReturn ? all[i].handoverConfirmation : payload,
          returnConfirmation: isReturn ? payload : all[i].returnConfirmation,
        );
        mutated = true;
        break;
      }
    }
    if (mutated) {
      await _saveAllRentalRequests(all);
      if (isReturn) {
        await refreshPrivatePilotReturnState(
          requestId,
          actualReturnAt: DateTime.now(),
        );
      }
    }
  }

  static Future<Map<String, dynamic>?> issueBookingConfirmationChallenge({
    required String requestId,
    required String segment,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty ||
        !const <String>{
          HandoverCodeService.segmentPickup,
          HandoverCodeService.segmentReturn,
        }.contains(segment)) {
      return null;
    }
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      return BackendRepository.issueBookingConfirmationChallenge(
        bookingId: id,
        segment: segment,
      );
    }
    final request = await getRentalRequestById(id);
    final current = await getCurrentUser();
    final item = request == null ? null : await getItemById(request.itemId);
    if (request == null || current == null || item == null) return null;
    final presenterRole = current.id == request.ownerId
        ? HandoverCodeService.presenterOwner
        : current.id == request.renterId
            ? HandoverCodeService.presenterRenter
            : null;
    if (presenterRole == null) return null;
    final expectedPresenterRole = segment == HandoverCodeService.segmentPickup
        ? HandoverCodeService.presenterOwner
        : HandoverCodeService.presenterRenter;
    if (presenterRole != expectedPresenterRole) return null;
    final code = HandoverCodeService.codeForTitleAndStart(
      title: item.title,
      start: request.start,
      bookingId: request.id,
      segment: segment,
      presenterRole: presenterRole,
    );
    return <String, dynamic>{
      'id': 'local-${request.id}-$segment-$presenterRole',
      'bookingId': request.id,
      'segment': segment,
      'presenterRole': presenterRole,
      'code': code,
      'qrPayload': HandoverCodeService.qrPayload(
        segment: segment,
        presenterRole: presenterRole,
        code: code,
        bookingId: request.id,
      ),
      'issuedAt': DateTime.now().toIso8601String(),
      'expiresAt':
          DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
    };
  }

  static Future<bool> verifyBookingConfirmationChallenge({
    required String requestId,
    required String segment,
    required String presenterRole,
    String? qrPayload,
    String? code,
    String? challengeId,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return false;
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final response =
          await BackendRepository.verifyBookingConfirmationChallenge(
        bookingId: id,
        qrPayload: qrPayload,
        challengeId: challengeId,
        code: code,
        segment: segment,
        presenterRole: presenterRole,
      );
      return response['confirmation'] is Map || response['replayed'] == true;
    }
    final request = await getRentalRequestById(id);
    final current = await getCurrentUser();
    final item = request == null ? null : await getItemById(request.itemId);
    if (request == null || current == null || item == null) return false;
    final expectedPresenterRole = segment == HandoverCodeService.segmentPickup
        ? HandoverCodeService.presenterOwner
        : segment == HandoverCodeService.segmentReturn
            ? HandoverCodeService.presenterRenter
            : null;
    if (presenterRole != expectedPresenterRole) return false;
    final expectedVerifierId =
        presenterRole == HandoverCodeService.presenterOwner
            ? request.renterId
            : request.ownerId;
    if (current.id != expectedVerifierId) return false;
    final expected = HandoverCodeService.codeForTitleAndStart(
      title: item.title,
      start: request.start,
      bookingId: request.id,
      segment: segment,
      presenterRole: presenterRole,
    );
    if (qrPayload != null && qrPayload.trim().isNotEmpty) {
      return HandoverCodeService.isExpectedQrPayload(
        qrPayload,
        segment: segment,
        presenterRole: presenterRole,
        code: expected,
        bookingId: request.id,
      );
    }
    return code?.trim() == expected;
  }

  static Future<RentalRequest?> refreshPrivatePilotReturnState(
    String requestId, {
    DateTime? actualReturnAt,
    DateTime? now,
  }) async {
    final all = await _getAllRentalRequests();
    final index = all.indexWhere((entry) => entry.id == requestId.trim());
    if (index < 0) return null;
    final current = all[index];
    final confirmation = current.returnConfirmation ?? const {};
    final ownerConfirmed = confirmation['ownerConfirmedAt'] != null;
    final renterConfirmed = confirmation['renterConfirmedAt'] != null;
    final timeline = PrivatePilotReturnPolicy.evaluate(
      scheduledReturnAt: current.end,
      mutuallyConfirmedActualReturnAt: actualReturnAt ?? current.returnT0,
      ownerConfirmed: ownerConfirmed,
      renterConfirmed: renterConfirmed,
      substantiatedCaseOpenedAt: current.returnCaseOpenedAt,
      now: now,
    );
    final updated = current.copyWith(
      returnState: timeline.state.storageValue,
      returnT0: timeline.t0,
      returnReportDeadline: timeline.reportDeadline,
      returnClarificationDeadline: timeline.clarificationDeadline,
      needsReview: timeline.state == PrivatePilotReturnState.needsReview,
    );
    all[index] = updated;
    await _saveAllRentalRequests(all);
    return updated;
  }

  static Future<RentalRequest?> recordPlatformWithdrawal({
    required String requestId,
    required String userId,
  }) async {
    final normalizedRequestId = requestId.trim();
    final normalizedUserId = userId.trim();
    if (normalizedRequestId.isEmpty || normalizedUserId.isEmpty) return null;
    final all = await _getAllRentalRequests();
    final index = all.indexWhere((entry) => entry.id == normalizedRequestId);
    if (index < 0 || all[index].renterId != normalizedUserId) return null;
    final acceptedAt = DateTime.now();
    final declaration = <String, dynamic>{
      'type': 'platform_withdrawal',
      'exactWording': PrivatePilotConfig.platformWithdrawalDeclaration,
      'documentName': PrivatePilotConfig.documentName,
      'documentVersion': PrivatePilotConfig.documentVersion,
      'language': PrivatePilotConfig.language,
      'accepted': true,
      'acceptedAt': acceptedAt.toIso8601String(),
    };
    RentalRequest updated;
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final remote = await BackendRepository.recordPlatformWithdrawal(
        bookingId: normalizedRequestId,
        declaration: declaration,
        idempotencyKey:
            'withdrawal_${normalizedRequestId}_${acceptedAt.microsecondsSinceEpoch}',
      );
      updated = RentalRequest.fromJson(remote);
    } else {
      updated = all[index].copyWith(
        legalDeclarations: [...all[index].legalDeclarations, declaration],
      );
    }
    all[index] = updated;
    await _saveAllRentalRequests(all);
    await addTimelineEvent(
      requestId: normalizedRequestId,
      type: 'platform_withdrawal_received',
      note:
          'Widerruf der kostenpflichtigen Plattformleistung eingegangen. Buchungswirkung offen.',
    );
    await addStructuredNotification(
      userId: updated.ownerId,
      category: 'bookings',
      priority: 2,
      title: 'Widerruf zur Buchung eingegangen',
      body:
          'Die Plattformleistung zu Buchung $normalizedRequestId wurde widerrufen. Der Buchungsstatus bleibt bis zur rechtlichen Prozessentscheidung neutral.',
      entityType: 'booking',
      entityId: normalizedRequestId,
      ctaLabel: 'Buchung öffnen',
      payload: {'requestId': normalizedRequestId, 'role': 'owner'},
    );
    return updated;
  }

  static Future<RentalRequestTransitionResult> confirmPickupTransition({
    required String requestId,
    required String confirmedByUserId,
    required String method,
    required bool confirmationContextVerified,
    required bool galleryAcknowledged,
  }) async {
    final id = requestId.trim();
    final userId = confirmedByUserId.trim();
    if (id.isEmpty || userId.isEmpty) {
      return const RentalRequestTransitionResult.failure(
        'Übergabe-Bestätigung konnte nicht verarbeitet werden.',
      );
    }
    final request = await getRentalRequestById(id);
    if (request == null) {
      return const RentalRequestTransitionResult.failure(
        'Übergabe-Daten fehlen.',
      );
    }
    final currentUser = await getCurrentUser();
    if (currentUser == null || currentUser.id != userId) {
      return const RentalRequestTransitionResult.failure(
        'Bitte melde dich mit dem bestätigenden Konto an.',
      );
    }
    if (request.renterId != userId) {
      return const RentalRequestTransitionResult.failure(
        'Diese Bestätigung ist nur für den Mieter möglich.',
      );
    }
    if (request.status != 'accepted') {
      return const RentalRequestTransitionResult.failure(
        'Übergabe ist gerade nicht verfügbar.',
      );
    }
    if (!confirmationContextVerified) {
      return const RentalRequestTransitionResult.failure(
        'Übergabe-Bestätigung konnte nicht verifiziert werden.',
      );
    }
    final state = await getHandoverReturnState(id);
    if (state['handoverActive'] != true) {
      return const RentalRequestTransitionResult.failure(
        'Bitte starte die Übergabe zuerst im Chat.',
      );
    }
    final handoverPhotos = await getHandoverPhotoCount(id);
    if (handoverPhotos < minimumRequiredPhotos) {
      return const RentalRequestTransitionResult.failure(
        'Bitte dokumentiere die Übergabe zuerst mit mindestens 4 Fotos.',
      );
    }
    final galleryUsed = await wasHandoverGalleryUsed(id);
    if (galleryUsed && !galleryAcknowledged) {
      return const RentalRequestTransitionResult.failure(
        'Bitte bestätige bewusst die Galerie-Dokumentation, bevor du fortfährst.',
      );
    }

    await updateRentalRequestStatus(requestId: id, status: 'running');
    await recordRentalRequestConfirmation(
      requestId: id,
      isReturn: false,
      method: method,
      confirmedByRole: 'renter',
      confirmedByUserId: userId,
    );
    await clearHandoverActive(id);
    return const RentalRequestTransitionResult.success();
  }

  static Future<RentalRequestTransitionResult> confirmReturnTransition({
    required String requestId,
    required String confirmedByUserId,
    required String method,
    required bool confirmationContextVerified,
    required bool galleryAcknowledged,
    required String reviewPauseSource,
  }) async {
    final id = requestId.trim();
    final userId = confirmedByUserId.trim();
    if (id.isEmpty || userId.isEmpty) {
      return const RentalRequestTransitionResult.failure(
        'Rückgabe-Bestätigung konnte nicht verarbeitet werden.',
      );
    }
    final request = await getRentalRequestById(id);
    if (request == null) {
      return const RentalRequestTransitionResult.failure(
        'Rückgabe-Daten fehlen.',
      );
    }
    final currentUser = await getCurrentUser();
    if (currentUser == null || currentUser.id != userId) {
      return const RentalRequestTransitionResult.failure(
        'Bitte melde dich mit dem bestätigenden Konto an.',
      );
    }
    if (request.ownerId != userId) {
      return const RentalRequestTransitionResult.failure(
        'Diese Bestätigung ist nur für den Vermieter möglich.',
      );
    }
    if (request.status != 'running') {
      return const RentalRequestTransitionResult.failure(
        'Rückgabe ist gerade nicht verfügbar.',
      );
    }
    if (!confirmationContextVerified) {
      return const RentalRequestTransitionResult.failure(
        'Rückgabe-Bestätigung konnte nicht verifiziert werden.',
      );
    }
    final state = await getHandoverReturnState(id);
    if (state['returnActive'] != true) {
      return const RentalRequestTransitionResult.failure(
        'Bitte starte die Rückgabe zuerst im Chat.',
      );
    }
    final returnPhotos = await getReturnPhotoCount(id);
    if (returnPhotos < minimumRequiredPhotos) {
      return const RentalRequestTransitionResult.failure(
        'Bitte dokumentiere die Rückgabe zuerst mit mindestens 4 Fotos.',
      );
    }
    final galleryUsed = await wasReturnGalleryUsed(id);
    if (galleryUsed && !galleryAcknowledged) {
      return const RentalRequestTransitionResult.failure(
        'Bitte bestätige bewusst die Galerie-Dokumentation, bevor du fortfährst.',
      );
    }
    final pausedForReview = await pauseReturnCompletionIfNeedsReview(
      id,
      source: reviewPauseSource,
    );
    if (pausedForReview) {
      return const RentalRequestTransitionResult.paused(
        'Zu dieser Buchung liegt eine Rückmeldung vor. Wir prüfen den Vorgang sorgfältig und schließen die Buchung danach vollständig ab. Danke für dein Verständnis.',
      );
    }

    await updateRentalRequestStatus(requestId: id, status: 'completed');
    await recordRentalRequestConfirmation(
      requestId: id,
      isReturn: true,
      method: method,
      confirmedByRole: 'owner',
      confirmedByUserId: userId,
      counterpartyConfirmed: true,
    );
    final refreshed = await getRentalRequestById(id);
    if (refreshed?.needsReview == true) {
      return const RentalRequestTransitionResult.paused(
        'Zu dieser Buchung liegt ein belegter Fall vor. Der Abschluss bleibt für die Prüfung markiert; unstrittige Beträge bleiben davon getrennt.',
      );
    }
    await clearReturnActive(id);
    await addTimelineEvent(
      requestId: id,
      type: 'completed',
      note: method == 'manual'
          ? 'Rückgabe manuell bestätigt'
          : 'Rückgabe abgeschlossen',
    );
    return const RentalRequestTransitionResult.success();
  }

  // Update times and express choice for an existing request (edit flow)
  static Future<void> updateRentalRequestTimes({
    required String requestId,
    required DateTime start,
    required DateTime end,
    bool? expressRequested,
  }) async {
    final all = await _getAllRentalRequests();
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final index = all.indexWhere((entry) => entry.id == requestId);
      if (index < 0) return;
      final current = all[index];
      // Pickup/return appointment times are stored in their dedicated flow
      // metadata. The authoritative rental occupancy may only be amended while
      // the request is still pending.
      if (current.status != 'pending') return;
      final exp = expressRequested ?? current.expressRequested;
      final amended = current.copyWith(
        start: start,
        end: end,
        expressRequested: exp,
        expressStatus: exp ? 'pending' : null,
        expressRequestedAt: exp ? DateTime.now() : null,
        expressConfirmedAt: null,
      );
      final remote = await BackendRepository.amendBooking(
        amended.toJson(),
        bookingId: requestId,
        idempotencyKey:
            'amend_${requestId}_${_rentalDate(start)}_${_rentalDate(end)}',
      );
      all[index] = RentalRequest.fromJson(remote);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _rentalRequestsKey,
        jsonEncode(all.map((entry) => entry.toJson()).toList()),
      );
      SharedPersistenceSync.notify(SharedPersistenceSync.rentalRequestsKey);
      return;
    }
    bool mutated = false;
    for (int i = 0; i < all.length; i++) {
      if (all[i].id == requestId) {
        final bool exp = expressRequested ?? all[i].expressRequested;
        // If express requested now, set status to pending again; otherwise clear
        all[i] = all[i].copyWith(
          start: start,
          end: end,
          expressRequested: exp,
          expressStatus: exp ? 'pending' : null,
          expressRequestedAt: exp ? DateTime.now() : null,
          expressConfirmedAt: null,
        );
        mutated = true;
        // Schedule/clear runtime express timer accordingly
        if (exp) {
          _scheduleExpressTimerIfNeeded(all[i]);
        } else {
          try {
            _expressTimers[requestId]?.cancel();
            _expressTimers.remove(requestId);
          } catch (_) {}
        }
        break;
      }
    }
    if (mutated) await _saveAllRentalRequests(all);
  }

  // Update express confirmation status for a request
  static Future<void> updateRentalRequestExpress({
    required String requestId,
    required bool accept,
  }) async {
    final all = await _getAllRentalRequests();
    bool mutated = false;
    for (int i = 0; i < all.length; i++) {
      if (all[i].id == requestId) {
        final newStatus = accept ? 'accepted' : 'declined';
        all[i] = all[i].copyWith(
          expressStatus: newStatus,
          expressConfirmedAt:
              accept ? DateTime.now() : all[i].expressConfirmedAt,
        );
        mutated = true;
        // If accepted/declined, cancel any scheduled timer
        try {
          _expressTimers[requestId]?.cancel();
          _expressTimers.remove(requestId);
        } catch (_) {}
        break;
      }
    }
    if (mutated) await _saveAllRentalRequests(all);
  }

  static Future<bool> pauseReturnCompletionIfNeedsReview(
    String requestId, {
    required String source,
  }) async {
    try {
      final request = await getRentalRequestById(requestId);
      if (request == null || !request.needsReview) return false;
      try {
        await addTimelineEvent(
          requestId: requestId,
          type: 'return_completion_paused_review',
          note: 'Rückgabeabschluss pausiert: Fall ist zur Prüfung markiert.',
        );
      } catch (e) {
        debugPrint(
          '[DataService] pauseReturnCompletionIfNeedsReview timeline failed: $e',
        );
      }
      try {
        await addNotification(
          title: 'Prüfung erforderlich',
          body:
              'Diese Rückgabe ist zur Prüfung markiert. Der Abschluss bleibt pausiert.',
        );
      } catch (e) {
        debugPrint(
          '[DataService] pauseReturnCompletionIfNeedsReview notification failed: $e',
        );
      }
      return true;
    } catch (e) {
      debugPrint('[DataService] pauseReturnCompletionIfNeedsReview failed: $e');
      return false;
    }
  }

  static Future<bool> markRentalRequestNeedsReview(
    String requestId, {
    required String reason,
    required String source,
    List<String> evidenceReferences = const [],
    int contestedAuthorizedMinor = 0,
    int allegedDamageMinor = 0,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.length < 10 || evidenceReferences.isEmpty) {
      return false;
    }
    final all = await _getAllRentalRequests();
    bool mutated = false;
    RentalRequest? updatedRequest;
    final requestedAt = DateTime.now();
    final effectiveEvidenceReferences = [...evidenceReferences];
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final report = await BackendRepository.createReport(
        targetType: 'booking',
        targetId: requestId,
        reasonCode: 'return_issue',
        details: normalizedReason,
        reference: source,
      );
      final reportId = report['id']?.toString().trim() ?? '';
      if (reportId.isNotEmpty) {
        effectiveEvidenceReferences.add('moderationReport:$reportId');
      }
    }
    for (int i = 0; i < all.length; i++) {
      if (all[i].id == requestId) {
        final request = all[i];
        final reportDeadline = (request.returnT0 ?? request.end).add(
          const Duration(hours: PrivatePilotConfig.returnReportWindowHours),
        );
        if (requestedAt.isAfter(reportDeadline)) return false;
        final split = PrivatePilotReturnPolicy.splitAuthorizedAmount(
          authorizedBookingMinor: request.quotedTotalMinor ?? 0,
          contestedAuthorizedMinor: contestedAuthorizedMinor,
          allegedDamageMinor: allegedDamageMinor,
        );
        all[i] = all[i].copyWith(
          needsReview: true,
          reviewReason: normalizedReason,
          reviewSource: source,
          reviewRequestedAt: requestedAt,
          reviewEvidenceReferences: effectiveEvidenceReferences,
          returnState: PrivatePilotReturnState.needsReview.storageValue,
          returnCaseOpenedAt: requestedAt,
          returnT0: request.returnT0 ?? request.end,
          returnReportDeadline: reportDeadline,
          returnClarificationDeadline: (request.returnT0 ?? request.end).add(
            const Duration(
              days: PrivatePilotConfig.missingReturnConfirmationDays,
            ),
          ),
          contestedAuthorizedMinor: split.contestedAuthorizedMinor,
          allegedDamageMinorRecordedOnly: split.allegedDamageMinorRecordedOnly,
        );
        updatedRequest = all[i];
        mutated = true;
        break;
      }
    }
    if (!mutated || updatedRequest == null) return false;

    await _saveAllRentalRequests(all);
    try {
      await addTimelineEvent(
        requestId: requestId,
        type: 'review_required',
        note: 'Manuelle Prüfung markiert ($source): $reason',
      );
    } catch (e) {
      debugPrint(
        '[DataService] markRentalRequestNeedsReview timeline failed: $e',
      );
    }
    try {
      await addNotification(
        title: 'Prüfung erforderlich',
        body: 'Eine Buchung wurde zur manuellen Prüfung markiert.',
      );
    } catch (e) {
      debugPrint(
        '[DataService] markRentalRequestNeedsReview notification failed: $e',
      );
    }
    return true;
  }

  // Schedules a 30-minute timer for express confirmation. If the app is closed,
  // the sweep will enforce the timeout on next load.
  static void _scheduleExpressTimerIfNeeded(RentalRequest r) {
    if (!r.expressRequested) return;
    if (r.expressStatus == 'accepted') return;
    final started = r.expressRequestedAt ?? r.createdAt;
    final deadline = started.add(const Duration(minutes: 30));
    final delay = deadline.difference(DateTime.now());
    if (delay.isNegative) {
      // Past due; run sweep soon.
      scheduleMicrotask(() => _sweepExpressTimeouts());
      return;
    }
    _expressTimers[r.id]?.cancel();
    _expressTimers[r.id] = Timer(delay, () async {
      await _sweepExpressTimeouts();
    });
  }

  /// Checks all requests for express confirmation timeouts and auto-downgrades
  /// to Standard if not confirmed within 30 minutes. Also logs a timeline event.
  static Future<void> _sweepExpressTimeouts() async {
    try {
      final all = await _getAllRentalRequests();
      bool mutated = false;
      final now = DateTime.now();
      for (int i = 0; i < all.length; i++) {
        final r = all[i];
        if (!r.expressRequested) continue;
        if (r.expressStatus == 'accepted') continue;
        final started = r.expressRequestedAt ?? r.createdAt;
        final deadline = started.add(const Duration(minutes: 30));
        if (now.isAfter(deadline)) {
          all[i] = r.copyWith(
            expressRequested: false,
            expressStatus: null,
            expressRequestedAt: null,
            expressConfirmedAt: null,
          );
          mutated = true;
          debugPrint(
            '[DataService] Express timeout -> auto-switch to Standard for request ${r.id}',
          );
          try {
            await addTimelineEvent(
              requestId: r.id,
              type: 'express_timeout_refund',
              note: 'Priorität abgelaufen; auf Standard umgestellt',
            );
          } catch (_) {}
          // Cancel any pending timer for safety
          try {
            _expressTimers[r.id]?.cancel();
            _expressTimers.remove(r.id);
          } catch (_) {}
        } else {
          // Still pending; ensure a timer is scheduled for runtime
          _scheduleExpressTimerIfNeeded(r);
        }
      }
      if (mutated) await _saveAllRentalRequests(all);
    } catch (e) {
      debugPrint('[DataService] sweepExpressTimeouts failed: $e');
    }
  }

  static Future<void> _ensureDemoRentalRequests() async {
    // Deprecated: keep for backward compatibility; now we intentionally do not seed demos.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_rentalRequestsKey) == null) {
      await prefs.setString(_rentalRequestsKey, jsonEncode([]));
    }
  }

  // New: requests where the current viewer is the renter
  static Future<List<RentalRequest>> getRentalRequestsForRenter(
    String renterId, {
    String? status,
  }) async {
    await _sweepExpressTimeouts();
    final all = await _getAllRentalRequests();
    final filtered = all
        .where(
          (r) =>
              r.renterId == renterId && (status == null || r.status == status),
        )
        .toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  // Timeline events (simple local storage)
  static Future<void> addTimelineEvent({
    required String requestId,
    required String type,
    String? note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timelineEventsKey);
    List<dynamic> list =
        raw != null && raw.isNotEmpty ? (jsonDecode(raw) as List) : [];
    list.add({
      'requestId': requestId,
      'type': type,
      'note': note ?? '',
      'ts': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_timelineEventsKey, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> getTimelineForRequest(
    String requestId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timelineEventsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List list = jsonDecode(raw);
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['requestId'] == requestId)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Notifications (demo)
  static Future<void> addNotification({
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notificationsKey);
    List<dynamic> list =
        raw != null && raw.isNotEmpty ? (jsonDecode(raw) as List) : [];
    list.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'body': body,
      'ts': DateTime.now().toIso8601String(),
      'read': false,
    });
    await prefs.setString(_notificationsKey, jsonEncode(list));
  }

  // ===== Notifications (structured feed, local) =====
  // NOTE: Stored as a list of map entries under [_notificationsKey]. We keep
  // legacy entries compatible by backfilling missing fields at read time.
  static Future<void> addStructuredNotification({
    required String userId,
    required String
        category, // important | bookings | messages | reviews | platform
    required String title,
    required String body,
    int priority =
        2, // 1=important, 2=bookings, 3=messages, 4=reviews, 5=platform
    String? entityType, // booking | thread | payment | review | system
    String? entityId,
    String? ctaLabel,
    Map<String, dynamic>? payload,
    List<Map<String, String>>? actions,
    DateTime? timestamp,
    bool critical = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_notificationsKey);
      List<dynamic> list =
          raw != null && raw.isNotEmpty ? (jsonDecode(raw) as List) : [];
      final now = timestamp ?? DateTime.now();
      list.add({
        'id': 'n_${now.microsecondsSinceEpoch}',
        'userId': userId,
        'category': category,
        'priority': priority,
        'title': title,
        'body': body,
        'entityType': entityType,
        'entityId': entityId,
        'ctaLabel': ctaLabel,
        ...?payload,
        'actions': actions,
        'critical': critical,
        'archived': false,
        'ts': now.toIso8601String(),
        'read': false,
      });
      await prefs.setString(_notificationsKey, jsonEncode(list));
    } catch (e) {
      debugPrint(
        '[DataService] addStructuredNotification failed: $e',
      );
    }
  }

  static Map<String, dynamic> _normalizeNotification(
    Map<String, dynamic> raw, {
    required String userId,
  }) {
    // Backfill legacy fields to the structured format.
    final out = Map<String, dynamic>.from(raw);
    out['id'] = (out['id'] ?? '').toString().isNotEmpty
        ? out['id'].toString()
        : 'n_${DateTime.now().microsecondsSinceEpoch}';
    out['userId'] = (out['userId'] ?? userId).toString();
    final String cat = (out['category'] ?? '').toString();
    if (cat.isEmpty) {
      // Legacy entries: assume platform unless title suggests something else.
      out['category'] = 'platform';
    }
    out['priority'] = (out['priority'] is num)
        ? (out['priority'] as num).toInt()
        : _priorityForCategory((out['category'] ?? 'platform').toString());
    out['title'] = (out['title'] ?? '').toString();
    out['body'] = (out['body'] ?? '').toString();
    out['entityType'] = (out['entityType'] as String?);
    out['entityId'] = (out['entityId'] as String?);
    out['ctaLabel'] = (out['ctaLabel'] as String?);
    out['requestId'] = (out['requestId'] as String?);
    out['listingId'] = (out['listingId'] as String?);
    out['counterpartyUserId'] = (out['counterpartyUserId'] as String?);
    out['counterpartyName'] = (out['counterpartyName'] as String?);
    out['role'] = (out['role'] as String?);
    if (out['actions'] is List) {
      try {
        out['actions'] = (out['actions'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .map(
              (e) => {
                'id': (e['id'] ?? '').toString(),
                'label': (e['label'] ?? '').toString(),
              },
            )
            .where(
              (e) =>
                  (e['id'] ?? '').toString().isNotEmpty &&
                  (e['label'] ?? '').toString().isNotEmpty,
            )
            .toList();
      } catch (_) {
        out.remove('actions');
      }
    }
    out['critical'] = (out['critical'] == true);
    out['archived'] = (out['archived'] == true);
    out['read'] = (out['read'] == true);
    // Support both 'ts' and 'createdAt'
    final tsStr = (out['ts'] ?? out['createdAt'] ?? '').toString();
    out['ts'] = tsStr.isNotEmpty ? tsStr : DateTime.now().toIso8601String();
    return out;
  }

  static int _priorityForCategory(String category) {
    switch (category) {
      case 'important':
        return 1;
      case 'bookings':
        return 2;
      case 'messages':
        return 3;
      case 'reviews':
        return 4;
      case 'platform':
      default:
        return 5;
    }
  }

  static bool _isVisibleDemoNotification(Map<String, dynamic> notification) {
    String lower(Object? value) =>
        value == null ? '' : value.toString().trim().toLowerCase();
    final title = lower(notification['title']);
    final body = lower(notification['body']);
    final entityType = lower(notification['entityType']);
    final entityId = lower(notification['entityId']);

    const seededPrefixes = <String>{
      'welcome_',
      'security_tip_',
      'review_tip_',
      'chat_tip_',
      'demo_message_',
    };
    if (seededPrefixes.any(entityId.startsWith)) return true;

    if (entityType == 'system' && title == 'willkommen bei shareittoo') {
      return true;
    }
    if (entityType == 'system' && title == 'sicherheits‑check') return true;
    if (entityType == 'system' && title == 'bewertungen sammeln') return true;
    if (entityType == 'system' && title == 'tipp: schnelle abstimmung') {
      return true;
    }
    if (entityType == 'system' &&
        title == 'neue nachricht' &&
        body == 'du hast eine neue nachricht – antworte direkt aus dem feed.') {
      return true;
    }
    if (entityType == 'payment' &&
        title == 'zahlungsmethode hinzufügen' &&
        entityId == 'payment_methods') {
      return true;
    }

    return false;
  }

  static Future<List<Map<String, dynamic>>> getNotificationFeedForUser(
    String userId, {
    bool includeArchived = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        final remote = await BackendRepository.getNotifications();
        await prefs.setString(_notificationsKey, jsonEncode(remote));
      }
      final raw = prefs.getString(_notificationsKey);
      if (raw == null || raw.isEmpty) return [];
      final List list = jsonDecode(raw);
      final out = <Map<String, dynamic>>[];
      bool mutated = false;
      for (final e in list) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final uid = (m['userId'] ?? userId).toString();
        if (uid != userId) continue;
        final norm = _normalizeNotification(m, userId: userId);
        if (_isVisibleDemoNotification(norm)) continue;
        if (norm['archived'] == true && !includeArchived) continue;
        out.add(norm);
        // Sanitize storage by ensuring normalized entries exist
        if (m['category'] == null ||
            m['priority'] == null ||
            m['userId'] == null ||
            m['archived'] == null ||
            m['critical'] == null) {
          mutated = true;
        }
      }
      out.sort((a, b) {
        final at = DateTime.tryParse((a['ts'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bt = DateTime.tryParse((b['ts'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
      if (mutated) {
        // Merge back normalized values for this user only; keep other users' entries.
        final merged = <dynamic>[];
        for (final e in list) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final uid = (m['userId'] ?? userId).toString();
          if (uid == userId) {
            merged.add(_normalizeNotification(m, userId: userId));
          } else {
            merged.add(m);
          }
        }
        await prefs.setString(_notificationsKey, jsonEncode(merged));
      }
      return out;
    } catch (e) {
      debugPrint(
        '[DataService] getNotificationFeedForUser failed: $e',
      );
      return [];
    }
  }

  static Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  }) async {
    try {
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        await BackendRepository.updateNotification(
          id: notificationId,
          read: true,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_notificationsKey);
      if (raw == null || raw.isEmpty) return;
      final List list = jsonDecode(raw);
      bool mutated = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i] is! Map) continue;
        final m = Map<String, dynamic>.from(list[i] as Map);
        final uid = (m['userId'] ?? userId).toString();
        if (uid != userId) continue;
        if ((m['id'] ?? '').toString() == notificationId) {
          if (m['read'] != true) {
            m['read'] = true;
            list[i] = m;
            mutated = true;
          }
          break;
        }
      }
      if (mutated) await prefs.setString(_notificationsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[DataService] markNotificationRead failed: $e');
    }
  }

  static Future<void> markAllNotificationsRead(String userId) async {
    try {
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        await BackendRepository.markAllNotificationsRead();
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_notificationsKey);
      if (raw == null || raw.isEmpty) return;
      final List list = jsonDecode(raw);
      bool mutated = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i] is! Map) continue;
        final m = Map<String, dynamic>.from(list[i] as Map);
        final uid = (m['userId'] ?? userId).toString();
        if (uid != userId) continue;
        if (m['read'] != true) {
          m['read'] = true;
          list[i] = m;
          mutated = true;
        }
      }
      if (mutated) await prefs.setString(_notificationsKey, jsonEncode(list));
    } catch (e) {
      debugPrint(
        '[DataService] markAllNotificationsRead failed: $e',
      );
    }
  }

  static Future<void> archiveNotification({
    required String userId,
    required String notificationId,
  }) async {
    try {
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        await BackendRepository.updateNotification(
          id: notificationId,
          archived: true,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_notificationsKey);
      if (raw == null || raw.isEmpty) return;
      final List list = jsonDecode(raw);
      bool mutated = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i] is! Map) continue;
        final m = Map<String, dynamic>.from(list[i] as Map);
        final uid = (m['userId'] ?? userId).toString();
        if (uid != userId) continue;
        if ((m['id'] ?? '').toString() == notificationId) {
          final critical = (m['critical'] == true);
          if (!critical && m['archived'] != true) {
            m['archived'] = true;
            list[i] = m;
            mutated = true;
          }
          break;
        }
      }
      if (mutated) await prefs.setString(_notificationsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[DataService] archiveNotification failed: $e');
    }
  }

  // ===== Ride compensation lightweight state =====
  /// Persist a decision for ride compensation per request and segment ('dropoff' | 'return').
  static Future<void> setRideCompensationDecision({
    required String requestId,
    required String segment,
    required bool grant,
    String? reason,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_rideCompKey);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        try {
          map = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          map = {};
        }
      }
      final entry = Map<String, dynamic>.from(map[requestId] as Map? ?? {});
      entry[segment] = {
        'grant': grant,
        'reason': reason ?? '',
        'ts': DateTime.now().toIso8601String(),
      };
      map[requestId] = entry;
      await prefs.setString(_rideCompKey, jsonEncode(map));
    } catch (e) {
      debugPrint(
        '[DataService] setRideCompensationDecision failed: $e',
      );
    }
  }

  /// Returns the decision if present. If [consume] is true, removes it after reading.
  static Future<bool?> getRideCompensationDecision({
    required String requestId,
    required String segment,
    bool consume = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_rideCompKey);
      if (raw == null || raw.isEmpty) return null;
      Map<String, dynamic> map;
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
      final entry = map[requestId];
      if (entry is Map) {
        final seg = (entry[segment] as Map?);
        final grant = (seg?['grant'] as bool?);
        if (consume) {
          final e2 = Map<String, dynamic>.from(entry);
          e2.remove(segment);
          if (e2.isEmpty) {
            map.remove(requestId);
          } else {
            map[requestId] = e2;
          }
          await prefs.setString(_rideCompKey, jsonEncode(map));
        }
        return grant;
      }
      return null;
    } catch (e) {
      debugPrint(
        '[DataService] getRideCompensationDecision failed: $e',
      );
      return null;
    }
  }

  // ===== Review reminder scheduling (local, lightweight) =====
  static Future<void> scheduleReviewReminder({
    required String requestId,
    required String itemId,
    required String reviewerId,
    required String reviewedUserId,
    required String direction, // 'renter_to_owner' | 'owner_to_renter'
    required DateTime dueAt,
  }) async {
    try {
      final req = await getRentalRequestById(requestId);
      if (req != null && req.needsReview) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_reviewRemindersKey);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          list = jsonDecode(raw);
        } catch (_) {
          list = [];
        }
      }
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      list.add({
        'id': id,
        'requestId': requestId,
        'itemId': itemId,
        'reviewerId': reviewerId,
        'reviewedUserId': reviewedUserId,
        'direction': direction,
        'dueAt': dueAt.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_reviewRemindersKey, jsonEncode(list));
    } catch (e) {
      debugPrint(
        '[DataService] scheduleReviewReminder failed: $e',
      );
    }
  }

  static Future<Map<String, dynamic>?> takeDueReviewReminder({
    required String reviewerId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_reviewRemindersKey);
      if (raw == null || raw.isEmpty) return null;
      List list;
      try {
        list = jsonDecode(raw);
      } catch (_) {
        return null;
      }
      final now = DateTime.now();
      int idx = -1;
      Map<String, dynamic>? hit;
      for (int i = 0; i < list.length; i++) {
        try {
          final map = Map<String, dynamic>.from(list[i] as Map);
          final rid = (map['reviewerId'] ?? '').toString();
          if (rid != reviewerId) continue;
          final dueStr = (map['dueAt'] ?? '').toString();
          final due = DateTime.tryParse(dueStr);
          if (due != null && !now.isBefore(due)) {
            idx = i;
            hit = map;
            break;
          }
        } catch (_) {
          /* skip */
        }
      }
      if (idx >= 0 && hit != null) {
        list.removeAt(idx);
        await prefs.setString(_reviewRemindersKey, jsonEncode(list));
        final requestId = (hit['requestId'] ?? '').toString();
        if (requestId.isNotEmpty) {
          final req = await getRentalRequestById(requestId);
          if (req != null && req.needsReview) return null;
        }
        return hit;
      }
      return null;
    } catch (e) {
      debugPrint('[DataService] takeDueReviewReminder failed: $e');
      return null;
    }
  }

  static Future<void> postponeReviewReminder({
    required Map<String, dynamic> reminder,
    required Duration by,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_reviewRemindersKey);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          list = jsonDecode(raw);
        } catch (_) {
          list = [];
        }
      }
      // Add a new entry with a new id and new dueAt
      final dueStr = (reminder['dueAt'] ?? '').toString();
      final oldDue = DateTime.tryParse(dueStr) ?? DateTime.now();
      final newDue = DateTime.now().isAfter(oldDue)
          ? DateTime.now().add(by)
          : oldDue.add(by);
      list.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'requestId': reminder['requestId'],
        'itemId': reminder['itemId'],
        'reviewerId': reminder['reviewerId'],
        'reviewedUserId': reminder['reviewedUserId'],
        'direction': reminder['direction'],
        'dueAt': newDue.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_reviewRemindersKey, jsonEncode(list));
    } catch (e) {
      debugPrint(
        '[DataService] postponeReviewReminder failed: $e',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notificationsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List list = jsonDecode(raw);
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Feedback (stored locally; when backend is connected, migrate to server)
  static Future<int> countFeedbacksToday({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_feedbacksKey);
    if (raw == null || raw.isEmpty) return 0;
    try {
      final List list = jsonDecode(raw);
      final now = DateTime.now();
      int count = 0;
      for (final e in list) {
        try {
          final map = Map<String, dynamic>.from(e as Map);
          final uid = (map['userId'] ?? '').toString();
          if (uid != userId) continue;
          final tsStr = map['ts']?.toString();
          if (tsStr == null || tsStr.isEmpty) continue;
          final ts = DateTime.tryParse(tsStr);
          if (ts == null) continue;
          if (ts.year == now.year &&
              ts.month == now.month &&
              ts.day == now.day) {
            count++;
          }
        } catch (_) {
          /* skip corrupted entry */
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> addFeedback({
    required String userId,
    required String text,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_feedbacksKey);
    List<dynamic> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        list = jsonDecode(raw);
      } catch (_) {
        list = [];
      }
    }
    list.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'userId': userId,
      'text': text,
      'ts': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_feedbacksKey, jsonEncode(list));
  }

  // ===== Cancellation policy helpers (Unified) =====
  /// Human-readable policy title (DE) – unified across the app
  static String policyName([String? ignored]) => 'Einheitliche Stornobedingung';

  /// Exact V4 deadline. For a normal booking the free deadline is 24 hours
  /// before start. A short-notice booking receives the centrally configured
  /// grace period from contract confirmation, capped at rental start.
  static DateTime? freeCancellationUntil({
    required String policy,
    required DateTime start,
    required DateTime createdAt,
  }) {
    final grace = PrivatePilotCancellationPolicy.shortNoticeGraceDeadline(
      contractConfirmedAt: createdAt,
      rentalStartAt: start,
    );
    return grace ?? start.subtract(const Duration(hours: 24));
  }

  /// V4 refund ratio for renter cancellation. The same ratio applies to the
  /// rental subtotal and the 10% platform contribution.
  static double refundRatio({
    required String policy,
    required DateTime start,
    required DateTime cancelAt,
    DateTime? createdAt,
  }) {
    final outcome = PrivatePilotCancellationPolicy.evaluate(
      rentalStartAt: start,
      cancelAt: cancelAt,
      actor: PrivatePilotCancellationActor.renter,
      contractConfirmedAt: createdAt,
    );
    return outcome.refundBasisPoints / 10000;
  }

  /// Deletes ALL locally stored rentals and bookings (rental requests), including
  /// related timelines, reminders, last-seen markers and transient handover caches.
  /// Also clears saved availability/delivery selections to avoid stale UI state.
  static Future<void> clearAllRentalsAndBookings() async {
    try {
      // Stop any express timers running in this session
      try {
        for (final t in _expressTimers.values) {
          t.cancel();
        }
        _expressTimers.clear();
      } catch (_) {
        /* ignore */
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rentalRequestsKey);
      await prefs.remove(_timelineEventsKey);
      await prefs.remove(_reviewRemindersKey);
      await prefs.remove(_requestsLastSeenKey);
      await prefs.remove(_handoverFailCountsKey);
      await prefs.remove(_handoverBannersKey);
      await prefs.remove(_bookingSelectionsKey);
      debugPrint(
        '[DataService] Cleared rentals/bookings and related local caches',
      );
    } catch (e) {
      debugPrint(
        '[DataService] clearAllRentalsAndBookings failed: $e',
      );
    }
  }

  // ===== Message Threads =====

  static Future<bool> _isCurrentUserParticipantForRequestId(
    String requestId,
  ) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) return false;

    final currentUser = await getCurrentUser();
    if (currentUser == null) return false;

    final request = await getRentalRequestById(normalizedRequestId);
    if (request == null) return false;

    return request.ownerId == currentUser.id ||
        request.renterId == currentUser.id;
  }

  static Future<bool> _isCurrentUserParticipantForThread(
    MessageThread thread,
  ) async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) return false;

    return thread.user1Id == currentUser.id || thread.user2Id == currentUser.id;
  }

  /// Returns the message thread linked to a rental request, if any.
  static Future<MessageThread?> getMessageThreadByRequestId(
    String requestId,
  ) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) return null;

    try {
      final isParticipant = await _isCurrentUserParticipantForRequestId(
        normalizedRequestId,
      );
      if (!isParticipant) return null;

      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(prefs);
      if (raw == null || raw.isEmpty) return null;
      final List<dynamic> list = jsonDecode(raw);
      for (final e in list) {
        try {
          final thread = MessageThread.fromJson(
            Map<String, dynamic>.from(e as Map),
          );
          if (thread.requestId == normalizedRequestId) return thread;
        } catch (_) {}
      }
      return null;
    } catch (e) {
      debugPrint('[DataService] getMessageThreadByRequestId error: $e');
      return null;
    }
  }

  /// Creates (if missing) and returns a message thread for an existing request.
  ///
  /// This is a local/demo helper to ensure the communication hub can always open
  /// from booking screens.
  static Future<MessageThread?> createOrGetThreadForRequest(
    String requestId,
  ) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) return null;

    try {
      final isParticipant = await _isCurrentUserParticipantForRequestId(
        normalizedRequestId,
      );
      if (!isParticipant) return null;

      final existing = await getMessageThreadByRequestId(normalizedRequestId);
      if (existing != null) return existing;
      final req = await getRentalRequestById(normalizedRequestId);
      if (req == null) return null;

      // Mirror the internal creation used on accept.
      await _createMessageThreadForRequest(req);
      return await getMessageThreadByRequestId(normalizedRequestId);
    } catch (e) {
      debugPrint('[DataService] createOrGetThreadForRequest failed: $e');
      return null;
    }
  }

  /// Updates the booking status snapshot stored on a thread.
  ///
  /// If a real [RentalRequest] exists for [requestId], prefer updating that
  /// request via [updateRentalRequestStatus] instead.
  static Future<void> updateMessageThreadBookingStatus({
    required String threadId,
    required String status,
  }) async {
    if (threadId.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(prefs);
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> list = jsonDecode(raw);
      bool mutated = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i] is! Map) continue;
        final map = Map<String, dynamic>.from(list[i] as Map);
        if ((map['id'] ?? '').toString() != threadId) continue;
        final thread = MessageThread.fromJson(map);
        list[i] = thread.copyWith(bookingStatus: status).toJson();
        mutated = true;
        break;
      }
      if (mutated) await _persistMessageThreads(prefs, list);
    } catch (e) {
      debugPrint('[DataService] updateMessageThreadBookingStatus error: $e');
    }
  }

  /// Appends a system message to a thread.
  static Future<void> addSystemMessageToThread({
    required String threadId,
    required String text,
  }) async {
    if (threadId.trim().isEmpty) return;
    final t = text.trim();
    if (t.isEmpty) return;
    try {
      await addMessageToThread(threadId: threadId, senderId: 'system', text: t);
    } catch (e) {
      debugPrint('[DataService] addSystemMessageToThread error: $e');
    }
  }

  // ===== Handover/Return lightweight state (local) =====

  static const String _handoverReturnStateKey = 'handover_return_state_v1';

  static Future<Map<String, dynamic>> _getHandoverReturnStateMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_handoverReturnStateKey);
      if (raw == null || raw.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    } catch (e) {
      debugPrint('[DataService] _getHandoverReturnStateMap failed: $e');
      return <String, dynamic>{};
    }
  }

  static Future<void> _setHandoverReturnStateMap(
    Map<String, dynamic> map, {
    bool announce = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_handoverReturnStateKey, jsonEncode(map));
      if (announce) {
        SharedPersistenceSync.notify(
          SharedPersistenceSync.handoverReturnStateKey,
        );
      }
    } catch (e) {
      debugPrint('[DataService] _setHandoverReturnStateMap failed: $e');
    }
  }

  /// Returns state for a request: {handoverActive, returnActive, handoverPhotos, returnPhotos}
  static Future<Map<String, dynamic>> getHandoverReturnState(
    String requestId,
  ) async {
    final id = requestId.trim();
    if (id.isEmpty) return const {};
    final map = await _getHandoverReturnStateMap();
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      try {
        final remote = await BackendRepository.getBookingFlowTime(id);
        final existing = (map[id] is Map)
            ? Map<String, dynamic>.from(map[id] as Map)
            : <String, dynamic>{};
        existing.addAll(remote);
        map[id] = existing;
        await _setHandoverReturnStateMap(map, announce: false);
      } catch (error) {
        debugPrint('[DataService] remote flow-time load failed: $error');
      }
    }
    final entry = map[id];
    if (entry is Map) {
      final e = entry.map((k, v) => MapEntry(k.toString(), v));
      return {
        'handoverActive': e['handoverActive'] == true,
        'returnActive': e['returnActive'] == true,
        'handoverPhotos': (e['handoverPhotos'] is num)
            ? (e['handoverPhotos'] as num).toInt()
            : 0,
        'returnPhotos':
            (e['returnPhotos'] is num) ? (e['returnPhotos'] as num).toInt() : 0,
        'handoverTimeRequested': (e['handoverTimeRequested'] as String?) ?? '',
        'returnTimeRequested': (e['returnTimeRequested'] as String?) ?? '',
        'handoverTimeIso': (e['handoverTimeIso'] as String?) ?? '',
        'returnTimeIso': (e['returnTimeIso'] as String?) ?? '',
        'handoverTimeRequestedByUserId':
            (e['handoverTimeRequestedByUserId'] as String?) ?? '',
        'returnTimeRequestedByUserId':
            (e['returnTimeRequestedByUserId'] as String?) ?? '',
        'handoverTimeConfirmed': e['handoverTimeConfirmed'] == true,
        'returnTimeConfirmed': e['returnTimeConfirmed'] == true,
        'handoverLocationLat': (e['handoverLocationLat'] as String?) ?? '',
        'handoverLocationLng': (e['handoverLocationLng'] as String?) ?? '',
        'handoverLocationLabel': (e['handoverLocationLabel'] as String?) ?? '',
        'handoverLocationMapsUrl':
            (e['handoverLocationMapsUrl'] as String?) ?? '',
        'handoverLocationSharedByUserId':
            (e['handoverLocationSharedByUserId'] as String?) ?? '',
        'handoverLocationSharedByName':
            (e['handoverLocationSharedByName'] as String?) ?? '',
        'handoverLocationSharedByRole':
            (e['handoverLocationSharedByRole'] as String?) ?? '',
        'handoverLocationAcceptedAs':
            (e['handoverLocationAcceptedAs'] as String?) ?? 'handoverLocation',
        'returnLocationLat': (e['returnLocationLat'] as String?) ?? '',
        'returnLocationLng': (e['returnLocationLng'] as String?) ?? '',
        'returnLocationLabel': (e['returnLocationLabel'] as String?) ?? '',
        'returnLocationMapsUrl': (e['returnLocationMapsUrl'] as String?) ?? '',
        'returnLocationSharedByUserId':
            (e['returnLocationSharedByUserId'] as String?) ?? '',
        'returnLocationSharedByName':
            (e['returnLocationSharedByName'] as String?) ?? '',
        'returnLocationSharedByRole':
            (e['returnLocationSharedByRole'] as String?) ?? '',
        'returnLocationAcceptedAs':
            (e['returnLocationAcceptedAs'] as String?) ?? 'returnLocation',
        'returnLocationReusePromptDismissed':
            e['returnLocationReusePromptDismissed'] == true,
      };
    }
    return {
      'handoverActive': false,
      'returnActive': false,
      'handoverPhotos': 0,
      'returnPhotos': 0,
      'handoverTimeRequested': '',
      'returnTimeRequested': '',
      'handoverTimeIso': '',
      'returnTimeIso': '',
      'handoverTimeRequestedByUserId': '',
      'returnTimeRequestedByUserId': '',
      'handoverTimeConfirmed': false,
      'returnTimeConfirmed': false,
      'handoverLocationLat': '',
      'handoverLocationLng': '',
      'handoverLocationLabel': '',
      'handoverLocationMapsUrl': '',
      'handoverLocationSharedByUserId': '',
      'handoverLocationSharedByName': '',
      'handoverLocationSharedByRole': '',
      'handoverLocationAcceptedAs': 'handoverLocation',
      'returnLocationLat': '',
      'returnLocationLng': '',
      'returnLocationLabel': '',
      'returnLocationMapsUrl': '',
      'returnLocationSharedByUserId': '',
      'returnLocationSharedByName': '',
      'returnLocationSharedByRole': '',
      'returnLocationAcceptedAs': 'returnLocation',
      'returnLocationReusePromptDismissed': false,
    };
  }

  static Future<bool> setHandoverActive(
    String requestId, {
    required bool active,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return false;
    final map = await _getHandoverReturnStateMap();
    final existing = (map[id] is Map)
        ? Map<String, dynamic>.from(map[id] as Map)
        : <String, dynamic>{};
    if (active) {
      final request = await getRentalRequestById(id);
      final currentUser = await getCurrentUser();
      if (request == null || currentUser == null) return false;
      if (currentUser.id != request.ownerId) return false;
      if (!canStartHandover(
        requestStatus: request.status,
        viewerIsOwner: true,
        handoverTimeConfirmed: existing['handoverTimeConfirmed'] == true,
        handoverActive: existing['handoverActive'] == true,
        needsReview: request.needsReview,
      )) {
        return false;
      }
    }
    existing['handoverActive'] = active;
    if (active) existing['returnActive'] = false;
    existing['handoverPhotos'] = (existing['handoverPhotos'] is num)
        ? (existing['handoverPhotos'] as num).toInt()
        : 0;
    existing['returnPhotos'] = (existing['returnPhotos'] is num)
        ? (existing['returnPhotos'] as num).toInt()
        : 0;
    map[id] = existing;
    await _setHandoverReturnStateMap(map);
    return active;
  }

  static Future<bool> setReturnActive(
    String requestId, {
    required bool active,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return false;
    final map = await _getHandoverReturnStateMap();
    final existing = (map[id] is Map)
        ? Map<String, dynamic>.from(map[id] as Map)
        : <String, dynamic>{};
    if (active) {
      final request = await getRentalRequestById(id);
      final currentUser = await getCurrentUser();
      if (request == null || currentUser == null) return false;
      if (currentUser.id != request.renterId) return false;
      if (!canStartReturn(
        requestStatus: request.status,
        viewerIsOwner: false,
        returnTimeConfirmed: existing['returnTimeConfirmed'] == true,
        returnActive: existing['returnActive'] == true,
      )) {
        return false;
      }
    }
    existing['returnActive'] = active;
    if (active) existing['handoverActive'] = false;
    existing['handoverPhotos'] = (existing['handoverPhotos'] is num)
        ? (existing['handoverPhotos'] as num).toInt()
        : 0;
    existing['returnPhotos'] = (existing['returnPhotos'] is num)
        ? (existing['returnPhotos'] as num).toInt()
        : 0;
    map[id] = existing;
    await _setHandoverReturnStateMap(map);
    return active;
  }

  static Future<void> clearHandoverActive(String requestId) async {
    await setHandoverActive(requestId, active: false);
  }

  static Future<void> clearReturnActive(String requestId) async {
    await setReturnActive(requestId, active: false);
  }

  static Future<void> incrementHandoverPhotos(
    String requestId, {
    int max = 4,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final map = await _getHandoverReturnStateMap();
    final existing = (map[id] is Map)
        ? Map<String, dynamic>.from(map[id] as Map)
        : <String, dynamic>{};
    final cur = (existing['handoverPhotos'] is num)
        ? (existing['handoverPhotos'] as num).toInt()
        : 0;
    existing['handoverPhotos'] = (cur + 1).clamp(0, max);
    map[id] = existing;
    await _setHandoverReturnStateMap(map);
  }

  static Future<void> incrementReturnPhotos(
    String requestId, {
    int max = 4,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final map = await _getHandoverReturnStateMap();
    final existing = (map[id] is Map)
        ? Map<String, dynamic>.from(map[id] as Map)
        : <String, dynamic>{};
    final cur = (existing['returnPhotos'] is num)
        ? (existing['returnPhotos'] as num).toInt()
        : 0;
    existing['returnPhotos'] = (cur + 1).clamp(0, max);
    map[id] = existing;
    await _setHandoverReturnStateMap(map);
  }

  static const int minimumRequiredPhotos = 4;

  static Future<int> getHandoverPhotoCount(String requestId) async {
    final state = await getHandoverReturnState(requestId);
    return (state['handoverPhotos'] is num)
        ? (state['handoverPhotos'] as num).toInt()
        : 0;
  }

  static Future<int> getReturnPhotoCount(String requestId) async {
    final state = await getHandoverReturnState(requestId);
    return (state['returnPhotos'] is num)
        ? (state['returnPhotos'] as num).toInt()
        : 0;
  }

  static Future<void> markHandoverGalleryUsed(String requestId) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final map = await _getHandoverReturnStateMap();
    final existing = (map[id] is Map)
        ? Map<String, dynamic>.from(map[id] as Map)
        : <String, dynamic>{};
    existing['handoverGalleryUsed'] = true;
    map[id] = existing;
    await _setHandoverReturnStateMap(map);
  }

  static Future<void> markReturnGalleryUsed(String requestId) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final map = await _getHandoverReturnStateMap();
    final existing = (map[id] is Map)
        ? Map<String, dynamic>.from(map[id] as Map)
        : <String, dynamic>{};
    existing['returnGalleryUsed'] = true;
    map[id] = existing;
    await _setHandoverReturnStateMap(map);
  }

  static Future<bool> wasHandoverGalleryUsed(String requestId) async {
    final state = await getHandoverReturnState(requestId);
    return state['handoverGalleryUsed'] == true;
  }

  static Future<bool> wasReturnGalleryUsed(String requestId) async {
    final state = await getHandoverReturnState(requestId);
    return state['returnGalleryUsed'] == true;
  }

  static Future<void> requestFlowTime({
    required String requestId,
    required bool isReturn,
    required String label,
    required DateTime time,
    required String requestedByUserId,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final map = await _getHandoverReturnStateMap();
    final existing = (map[id] is Map)
        ? Map<String, dynamic>.from(map[id] as Map)
        : <String, dynamic>{};
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final remote = await BackendRepository.updateBookingFlowTime(
        bookingId: id,
        action: 'propose',
        segment: isReturn ? 'return' : 'pickup',
        label: label,
        time: time,
      );
      existing.addAll(remote);
      map[id] = existing;
      await _setHandoverReturnStateMap(map);
      return;
    }
    final prefix = isReturn ? 'return' : 'handover';
    existing['${prefix}TimeRequested'] = label;
    existing['${prefix}TimeIso'] = time.toIso8601String();
    existing['${prefix}TimeRequestedByUserId'] = requestedByUserId;
    existing['${prefix}TimeConfirmed'] = false;
    map[id] = existing;
    await _setHandoverReturnStateMap(map);
  }

  static Future<void> setFlowLocation({
    required String requestId,
    required bool isReturn,
    required String latitude,
    required String longitude,
    required String label,
    required String mapsUrl,
    required String sharedByUserId,
    required String sharedByName,
    required String sharedByRole,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final map = await _getHandoverReturnStateMap();
    final existing = (map[id] is Map)
        ? Map<String, dynamic>.from(map[id] as Map)
        : <String, dynamic>{};
    final prefix = isReturn ? 'return' : 'handover';
    existing['${prefix}LocationLat'] = latitude.trim();
    existing['${prefix}LocationLng'] = longitude.trim();
    existing['${prefix}LocationLabel'] = label.trim();
    existing['${prefix}LocationMapsUrl'] = mapsUrl.trim();
    existing['${prefix}LocationSharedByUserId'] = sharedByUserId.trim();
    existing['${prefix}LocationSharedByName'] = sharedByName.trim();
    existing['${prefix}LocationSharedByRole'] = sharedByRole.trim();
    existing['${prefix}LocationAcceptedAs'] =
        isReturn ? 'returnLocation' : 'handoverLocation';
    if (isReturn) {
      existing['returnLocationReusePromptDismissed'] = false;
    }
    map[id] = existing;
    await _setHandoverReturnStateMap(map);
  }

  static Future<void> copyHandoverLocationToReturn({
    required String requestId,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final map = await _getHandoverReturnStateMap();
    final existing = (map[id] is Map)
        ? Map<String, dynamic>.from(map[id] as Map)
        : <String, dynamic>{};
    existing['returnLocationLat'] =
        (existing['handoverLocationLat'] as String?) ?? '';
    existing['returnLocationLng'] =
        (existing['handoverLocationLng'] as String?) ?? '';
    existing['returnLocationLabel'] =
        (existing['handoverLocationLabel'] as String?) ?? '';
    existing['returnLocationMapsUrl'] =
        (existing['handoverLocationMapsUrl'] as String?) ?? '';
    existing['returnLocationSharedByUserId'] =
        (existing['handoverLocationSharedByUserId'] as String?) ?? '';
    existing['returnLocationSharedByName'] =
        (existing['handoverLocationSharedByName'] as String?) ?? '';
    existing['returnLocationSharedByRole'] =
        (existing['handoverLocationSharedByRole'] as String?) ?? '';
    existing['returnLocationAcceptedAs'] = 'returnLocation';
    existing['returnLocationReusePromptDismissed'] = false;
    map[id] = existing;
    await _setHandoverReturnStateMap(map);
  }

  static Future<void> dismissReturnLocationReusePrompt({
    required String requestId,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final map = await _getHandoverReturnStateMap();
    final existing = (map[id] is Map)
        ? Map<String, dynamic>.from(map[id] as Map)
        : <String, dynamic>{};
    existing['returnLocationReusePromptDismissed'] = true;
    map[id] = existing;
    await _setHandoverReturnStateMap(map);
  }

  static Future<void> confirmFlowTime({
    required String requestId,
    required bool isReturn,
    required String confirmedByUserId,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return;
    final map = await _getHandoverReturnStateMap();
    final existing = (map[id] is Map)
        ? Map<String, dynamic>.from(map[id] as Map)
        : <String, dynamic>{};
    if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
      final remote = await BackendRepository.updateBookingFlowTime(
        bookingId: id,
        action: 'confirm',
        segment: isReturn ? 'return' : 'pickup',
      );
      existing.addAll(remote);
      map[id] = existing;
      await _setHandoverReturnStateMap(map);
      return;
    }
    final prefix = isReturn ? 'return' : 'handover';
    final iso = (existing['${prefix}TimeIso'] as String?) ?? '';
    final parsed = iso.isNotEmpty ? DateTime.tryParse(iso) : null;
    existing['${prefix}TimeConfirmed'] = true;
    existing['${prefix}TimeConfirmedByUserId'] = confirmedByUserId;
    existing['${prefix}TimeConfirmedAt'] = DateTime.now().toIso8601String();
    map[id] = existing;
    await _setHandoverReturnStateMap(map);

    if (parsed != null) {
      final req = await getRentalRequestById(id);
      if (req != null) {
        if (isReturn) {
          await updateRentalRequestTimes(
            requestId: id,
            start: req.start,
            end: DateTime(
              req.end.year,
              req.end.month,
              req.end.day,
              parsed.hour,
              parsed.minute,
            ),
            expressRequested: req.expressRequested,
          );
        } else {
          await updateRentalRequestTimes(
            requestId: id,
            start: DateTime(
              req.start.year,
              req.start.month,
              req.start.day,
              parsed.hour,
              parsed.minute,
            ),
            end: req.end,
            expressRequested: req.expressRequested,
          );
        }
      }
    }
  }

  /// Erstellt automatisch einen Message Thread wenn eine Anfrage angenommen wird
  static Future<void> _createMessageThreadForRequest(
    RentalRequest request,
  ) async {
    try {
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        final remote = await BackendRepository.createOrGetBookingThread(
          request.id,
        );
        final prefs = await SharedPreferences.getInstance();
        final currentRaw = prefs.getString(_messageThreadsKey);
        final current = currentRaw != null && currentRaw.isNotEmpty
            ? List<dynamic>.from(jsonDecode(currentRaw) as List)
            : <dynamic>[];
        current.removeWhere(
          (entry) =>
              entry is Map &&
              ((entry['id']?.toString() == remote['id']?.toString()) ||
                  (entry['requestId']?.toString() == request.id)),
        );
        current.add(remote);
        await _persistMessageThreads(prefs, current);
        return;
      }
      final item = await getItemById(request.itemId);
      if (item == null) return;

      final renter = await getUserById(request.renterId);
      final owner = await getUserById(request.ownerId);
      if (renter == null || owner == null) return;

      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(prefs);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          list = jsonDecode(raw);
        } catch (_) {
          list = [];
        }
      }

      // Prüfe ob bereits ein Thread für diese Anfrage existiert
      final exists = list.any((e) {
        try {
          final map = Map<String, dynamic>.from(e as Map);
          return (map['requestId']?.toString() ?? '') == request.id;
        } catch (_) {
          return false;
        }
      });

      if (exists) return; // Thread existiert bereits

      // Erstelle neuen Thread mit initialer Nachricht
      final threadId = 'thread_${DateTime.now().microsecondsSinceEpoch}';
      final now = DateTime.now();

      final initialMessage = Message(
        id: 'msg_${now.microsecondsSinceEpoch}',
        senderId: 'system',
        text:
            'Starte einen Chat mit ${owner.displayName}, um eine Uhrzeit für Übergabe und Rückgabe zu vereinbaren.',
        timestamp: now,
        isRead: false,
      );

      final thread = MessageThread(
        id: threadId,
        requestId: request.id,
        itemId: request.itemId,
        itemTitle: item.title,
        user1Id: request.renterId,
        user2Id: request.ownerId,
        archivedForUserIds: const <String>[],
        messages: [initialMessage],
        createdAt: now,
        lastMessageAt: now,
      );

      list.add(thread.toJson());
      await _persistMessageThreads(prefs, list);
      debugPrint(
        '[DataService] Created message thread for request ${request.id}',
      );

      // Create message notifications for both parties pointing directly into the thread.
      try {
        await addStructuredNotification(
          userId: request.renterId,
          category: 'messages',
          priority: 3,
          title: 'Neuer Chat',
          body:
              'Du kannst jetzt mit ${owner.displayName} zu „${item.title}“ chatten.',
          entityType: 'thread',
          entityId: threadId,
          ctaLabel: 'Chat öffnen',
        );
        await addStructuredNotification(
          userId: request.ownerId,
          category: 'messages',
          priority: 3,
          title: 'Neuer Chat',
          body:
              'Du kannst jetzt mit ${renter.displayName} zu „${item.title}“ chatten.',
          entityType: 'thread',
          entityId: threadId,
          ctaLabel: 'Chat öffnen',
        );
      } catch (e) {
        debugPrint('[DataService] thread notifications failed: $e');
      }
    } catch (e) {
      debugPrint('[DataService] _createMessageThreadForRequest error: $e');
    }
  }

  /// Gibt alle Message Threads für einen User zurück
  static Future<List<MessageThread>> getMessageThreadsForUser(
    String userId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(prefs);
      if (raw == null || raw.isEmpty) {
        debugPrint(
          '[DataService] message thread seed skipped (demo seed disabled)',
        );
        return [];
      }

      final effectiveRaw = await _readMessageThreads(prefs);
      if (effectiveRaw == null || effectiveRaw.isEmpty) return [];

      final List<dynamic> list = jsonDecode(effectiveRaw);
      final threads = <MessageThread>[];

      for (final e in list) {
        try {
          final thread = MessageThread.fromJson(
            Map<String, dynamic>.from(e as Map),
          );
          // Nur Threads zeigen, die den User betreffen
          if ((thread.user1Id == userId || thread.user2Id == userId) &&
              !thread.archivedForUserIds.contains(userId)) {
            threads.add(thread);
          }
        } catch (err) {
          debugPrint('[DataService] Skipped corrupted thread: $err');
        }
      }

      // Sortiere nach letzter Nachricht (neueste zuerst)
      threads.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return threads;
    } catch (e) {
      debugPrint('[DataService] getMessageThreadsForUser error: $e');
      return [];
    }
  }

  /// Ensures at least one openable thread exists for the given user.
  ///
  /// Rationale: In preview/developer builds, demo seeding can be disabled.
  /// That can leave the Messages tab empty, making it impossible to QA the chat
  /// detail UI. This method seeds a minimal *support* thread **only when the
  /// store is empty**. It does not touch booking/payment/QR/review logic.
  static Future<bool> ensureSeededMessageThreadsForUser(String userId) async {
    if (!QaRuntimeService.isEnabled) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(prefs);

      List<dynamic> list = <dynamic>[];
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) list = decoded;
        } catch (_) {
          list = <dynamic>[];
        }
      }

      if (list.isNotEmpty) return false;

      final now = DateTime.now();
      final threadId = 'seed_support_${now.microsecondsSinceEpoch}';
      final messages = <Message>[
        Message(
          id: 'seed_msg_${now.microsecondsSinceEpoch}',
          senderId: 'support',
          text:
              'Hi! Das ist ein lokaler Demo-Chat, damit du das UI testen kannst.',
          timestamp: now.subtract(const Duration(minutes: 18)),
          isRead: false,
        ),
        Message(
          id: 'seed_msg_${now.microsecondsSinceEpoch + 1}',
          senderId: userId,
          text: 'Perfekt — ich prüfe gerade den Composer und den Send-Button.',
          timestamp: now.subtract(const Duration(minutes: 12)),
          isRead: true,
        ),
        Message(
          id: 'seed_msg_${now.microsecondsSinceEpoch + 2}',
          senderId: 'support',
          text:
              'Super. Schreib einfach eine Testnachricht — nichts wird extern gesendet.',
          timestamp: now.subtract(const Duration(minutes: 8)),
          isRead: false,
        ),
      ];

      final thread = MessageThread(
        id: threadId,
        requestId: 'seed_support_request_$userId',
        itemId: 'support',
        itemTitle: 'Support',
        user1Id: userId,
        user2Id: 'support',
        threadType: 'support',
        otherUserOnline: true,
        messages: messages,
        createdAt: now.subtract(const Duration(hours: 2)),
        lastMessageAt: messages.last.timestamp,
        archivedForUserIds: const <String>[],
      );

      await _persistMessageThreads(prefs, [thread.toJson()]);
      debugPrint(
        '[DataService] Seeded minimal support thread for user=$userId',
      );
      return true;
    } catch (e) {
      debugPrint('[DataService] ensureSeededMessageThreadsForUser failed: $e');
      return false;
    }
  }

  /// Returns threads that were archived by the user.
  static Future<List<MessageThread>> getArchivedMessageThreadsForUser(
    String userId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        final remote = await BackendRepository.getMessageThreads(
          includeArchived: true,
        );
        await _persistMessageThreads(
          prefs,
          remote,
          announceChange: shouldAnnounceMessageThreadCacheWrite(
            readOnlyRemoteRefresh: true,
          ),
        );
      }
      final raw = BackendConfig.enabled && !QaRuntimeService.isEnabled
          ? prefs.getString(_messageThreadsKey)
          : await _readMessageThreads(prefs);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw);
      final threads = <MessageThread>[];
      for (final e in list) {
        try {
          final thread = MessageThread.fromJson(
            Map<String, dynamic>.from(e as Map),
          );
          if ((thread.user1Id == userId || thread.user2Id == userId) &&
              thread.archivedForUserIds.contains(userId)) {
            threads.add(thread);
          }
        } catch (err) {
          debugPrint('[DataService] Skipped corrupted archived thread: $err');
        }
      }
      threads.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      return threads;
    } catch (e) {
      debugPrint('[DataService] getArchivedMessageThreadsForUser error: $e');
      return [];
    }
  }

  static Future<void> archiveMessageThreadForUser({
    required String threadId,
    required String userId,
  }) async {
    if (threadId.isEmpty || userId.isEmpty) return;
    try {
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        await BackendRepository.setThreadArchived(
          threadId: threadId,
          archived: true,
        );
        final prefs = await SharedPreferences.getInstance();
        final remote = await BackendRepository.getMessageThreads();
        await _persistMessageThreads(prefs, remote);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(prefs);
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> list = jsonDecode(raw);
      bool mutated = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i] is! Map) continue;
        final map = Map<String, dynamic>.from(list[i] as Map);
        if ((map['id'] ?? '').toString() != threadId) continue;
        final thread = MessageThread.fromJson(map);
        final archived = [...thread.archivedForUserIds];
        if (!archived.contains(userId)) {
          archived.add(userId);
          list[i] = thread.copyWith(archivedForUserIds: archived).toJson();
          mutated = true;
        }
        break;
      }
      if (mutated) await _persistMessageThreads(prefs, list);
    } catch (e) {
      debugPrint('[DataService] archiveMessageThreadForUser error: $e');
    }
  }

  static Future<void> unarchiveMessageThreadForUser({
    required String threadId,
    required String userId,
  }) async {
    if (threadId.isEmpty || userId.isEmpty) return;
    try {
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        await BackendRepository.setThreadArchived(
          threadId: threadId,
          archived: false,
        );
        final prefs = await SharedPreferences.getInstance();
        final remote = await BackendRepository.getMessageThreads();
        await _persistMessageThreads(prefs, remote);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(prefs);
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> list = jsonDecode(raw);
      bool mutated = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i] is! Map) continue;
        final map = Map<String, dynamic>.from(list[i] as Map);
        if ((map['id'] ?? '').toString() != threadId) continue;
        final thread = MessageThread.fromJson(map);
        final archived = [...thread.archivedForUserIds];
        if (archived.remove(userId)) {
          list[i] = thread.copyWith(archivedForUserIds: archived).toJson();
          mutated = true;
        }
        break;
      }
      if (mutated) await _persistMessageThreads(prefs, list);
    } catch (e) {
      debugPrint('[DataService] unarchiveMessageThreadForUser error: $e');
    }
  }

  /// Deletes a thread entirely from local storage.
  ///
  /// This is destructive and affects both participants (demo/local only).
  static Future<void> deleteMessageThread({required String threadId}) async {
    if (threadId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(prefs);
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> list = jsonDecode(raw);
      final before = list.length;
      list.removeWhere(
        (e) => (e is Map) && ((e['id'] ?? '').toString() == threadId),
      );
      if (list.length != before) {
        await _persistMessageThreads(prefs, list);
      }
    } catch (e) {
      debugPrint('[DataService] deleteMessageThread error: $e');
    }
  }

  static Future<int> getUnreadThreadCountForUser(String userId) async {
    try {
      final threads = await getMessageThreadsForUser(userId);
      int count = 0;
      for (final t in threads) {
        final hasUnread = t.messages.any(
          (m) => m.senderId != userId && !m.isRead,
        );
        if (hasUnread) count++;
      }
      return count;
    } catch (e) {
      debugPrint('[DataService] getUnreadThreadCountForUser error: $e');
      return 0;
    }
  }

  static List<MessageThread> _buildDemoMessageThreadsForUser(String userId) {
    final now = DateTime.now();
    final otherUsers = <String>['u2', 'u3', 'u6', 'u10', 'u14']..remove(userId);
    final picks = otherUsers.take(3).toList();
    if (picks.isEmpty) picks.add('u2');

    Message msg({
      required String senderId,
      required String text,
      required DateTime at,
      bool isRead = true,
    }) =>
        Message(
          id: 'msg_${at.microsecondsSinceEpoch}_${senderId == userId ? 'me' : 'them'}',
          senderId: senderId,
          text: text,
          timestamp: at,
          isRead: isRead,
        );

    MessageThread thread({
      required String threadId,
      required String otherUserId,
      required String itemTitle,
      String? bookingStatus,
      DateTime? handoverAt,
      DateTime? returnAt,
      String? threadType,
      required List<Message> messages,
      required DateTime createdAt,
      DateTime? lastAt,
    }) =>
        MessageThread(
          id: threadId,
          requestId: 'demo_req_$threadId',
          itemId: 'demo_item_$threadId',
          itemTitle: itemTitle,
          user1Id: userId,
          user2Id: otherUserId,
          threadType: threadType,
          bookingStatus: bookingStatus,
          handoverAt: handoverAt,
          returnAt: returnAt,
          otherUserOnline: threadType == 'support' ? true : null,
          otherUserLastActive: now.subtract(const Duration(minutes: 6)),
          archivedForUserIds: const <String>[],
          messages: messages,
          createdAt: createdAt,
          lastMessageAt: lastAt,
        );

    final t1Time = now.subtract(const Duration(hours: 2, minutes: 12));
    final t2Time = now.subtract(const Duration(days: 1, hours: 3));
    final t3Time = now.subtract(const Duration(days: 5, hours: 1));

    final th1 = thread(
      threadId: 'thread_demo_1',
      otherUserId: picks[0],
      itemTitle: 'Canon EOS R5 – Kamera',
      createdAt: t1Time.subtract(const Duration(minutes: 20)),
      lastAt: t1Time,
      bookingStatus: 'accepted',
      handoverAt: DateTime(now.year, now.month, now.day, 18, 0),
      messages: [
        msg(
          senderId: 'system',
          text: 'Starte einen Chat, um Übergabe und Rückgabe zu koordinieren.',
          at: t1Time.subtract(const Duration(minutes: 20)),
          isRead: true,
        ),
        msg(
          senderId: picks[0],
          text: 'Hi! Passt dir heute 18:30 für die Übergabe?',
          at: t1Time.subtract(const Duration(minutes: 7)),
          isRead: false,
        ),
        msg(
          senderId: userId,
          text: 'Ja, 18:30 ist perfekt. Ich bin pünktlich da.',
          at: t1Time.subtract(const Duration(minutes: 4)),
          isRead: true,
        ),
        msg(
          senderId: picks[0],
          text: 'Super — ich schicke dir gleich die genaue Adresse.',
          at: t1Time,
          isRead: false,
        ),
      ],
    );

    final th2 = thread(
      threadId: 'thread_demo_2',
      otherUserId: picks.length > 1 ? picks[1] : picks[0],
      itemTitle: 'Bosch Bohrmaschine',
      createdAt: t2Time.subtract(const Duration(hours: 1)),
      lastAt: t2Time,
      bookingStatus: 'pending',
      messages: [
        msg(
          senderId: 'system',
          text: 'Starte einen Chat, um Übergabe und Rückgabe zu koordinieren.',
          at: t2Time.subtract(const Duration(hours: 1)),
          isRead: true,
        ),
        msg(
          senderId: userId,
          text:
              'Hey! Ist die Bohrmaschine auch mit 10mm Steinbohrer verfügbar?',
          at: t2Time.subtract(const Duration(minutes: 18)),
          isRead: true,
        ),
        msg(
          senderId: picks.length > 1 ? picks[1] : picks[0],
          text: 'Ja, ist dabei. Akku ist voll geladen 👍',
          at: t2Time,
          isRead: true,
        ),
      ],
    );

    final th3 = thread(
      threadId: 'thread_demo_3',
      otherUserId: picks.length > 2 ? picks[2] : picks[0],
      itemTitle: 'E‑Scooter (City)',
      createdAt: t3Time.subtract(const Duration(hours: 2)),
      lastAt: t3Time,
      bookingStatus: 'completed',
      returnAt: DateTime(now.year, now.month, now.day + 1, 12, 0),
      messages: [
        msg(
          senderId: 'system',
          text: 'Starte einen Chat, um Übergabe und Rückgabe zu koordinieren.',
          at: t3Time.subtract(const Duration(hours: 2)),
          isRead: true,
        ),
        msg(
          senderId: picks.length > 2 ? picks[2] : picks[0],
          text: 'Wenn du willst, kann ich dir noch ein Schloss mitgeben.',
          at: t3Time.subtract(const Duration(minutes: 35)),
          isRead: true,
        ),
        msg(
          senderId: userId,
          text: 'Mega, danke! Dann fühle ich mich sicherer.',
          at: t3Time,
          isRead: true,
        ),
      ],
    );

    final supportTime = now.subtract(const Duration(minutes: 40));
    final support = thread(
      threadId: 'thread_support_1',
      otherUserId: 'support',
      threadType: 'support',
      itemTitle: 'SIT Support',
      bookingStatus: null,
      createdAt: supportTime.subtract(const Duration(minutes: 2)),
      lastAt: supportTime,
      messages: [
        msg(
          senderId: 'support',
          text: 'Hallo! Wie können wir helfen?',
          at: supportTime.subtract(const Duration(minutes: 2)),
          isRead: false,
        ),
        msg(
          senderId: userId,
          text: 'Kurze Frage zur Rückgabe: kann ich auch früher abgeben?',
          at: supportTime,
          isRead: true,
        ),
      ],
    );

    return [th1, th2, support, th3];
  }

  /// Erstellt einen neuen Support-Thread für einen User oder verwendet den bestehenden erneut.
  static Future<MessageThread?> createSupportThread({
    required String userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(prefs);
      final List<dynamic> list =
          raw != null && raw.isNotEmpty ? jsonDecode(raw) : [];

      for (final entry in list) {
        if (entry is! Map) continue;
        final thread = MessageThread.fromJson(Map<String, dynamic>.from(entry));
        final isSupport = (thread.threadType ?? '').toLowerCase() == 'support';
        final belongsToUser =
            (thread.user1Id == userId && thread.user2Id == 'support') ||
                (thread.user2Id == userId && thread.user1Id == 'support');
        if (isSupport && belongsToUser) {
          debugPrint('[DataService] createSupportThread: reusing ${thread.id}');
          return thread;
        }
      }

      final now = DateTime.now();
      final threadId = 'thread_support_${now.microsecondsSinceEpoch}';

      final supportThread = MessageThread(
        id: threadId,
        requestId: '',
        itemId: '',
        itemTitle: 'SIT Support',
        user1Id: userId,
        user2Id: 'support',
        threadType: 'support',
        bookingStatus: null,
        handoverAt: null,
        returnAt: null,
        otherUserOnline: true,
        otherUserLastActive: now,
        archivedForUserIds: const <String>[],
        messages: [
          Message(
            id: 'msg_${now.microsecondsSinceEpoch}_welcome',
            senderId: 'support',
            text: 'Hallo! Wie können wir dir helfen?',
            timestamp: now,
            isRead: false,
          ),
        ],
        createdAt: now,
        lastMessageAt: now,
      );

      list.add(supportThread.toJson());
      await _persistMessageThreads(prefs, list);

      debugPrint('[DataService] createSupportThread: created $threadId');
      return supportThread;
    } catch (e) {
      debugPrint('[DataService] createSupportThread error: $e');
      return null;
    }
  }

  /// Findet einen Thread anhand der Thread-ID
  static Future<MessageThread?> getMessageThreadById(
    String threadId, {
    Duration remoteTimeout = const Duration(seconds: 20),
  }) async {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(
        prefs,
        remoteTimeout: remoteTimeout,
      );
      if (raw == null || raw.isEmpty) return null;

      final List<dynamic> list = jsonDecode(raw);
      for (final e in list) {
        try {
          final thread = MessageThread.fromJson(
            Map<String, dynamic>.from(e as Map),
          );
          if (thread.id != normalizedThreadId) continue;

          final isParticipant = await _isCurrentUserParticipantForThread(
            thread,
          );
          if (!isParticipant) return null;

          return thread;
        } catch (_) {}
      }
      return null;
    } catch (e) {
      debugPrint('[DataService] getMessageThreadById error: $e');
      return null;
    }
  }

  /// Fügt eine Nachricht zu einem Thread hinzu
  static Future<void> addMessageToThread({
    required String threadId,
    required String senderId,
    required String text,
  }) async {
    try {
      final normalizedThreadId = threadId.trim();
      final normalizedSenderId = senderId.trim();
      final normalizedText = text.trim();
      if (normalizedThreadId.isEmpty ||
          normalizedSenderId.isEmpty ||
          normalizedText.isEmpty) {
        return;
      }

      final currentUser = await getCurrentUser();
      if (currentUser == null) return;

      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        if (normalizedSenderId == 'system' ||
            normalizedSenderId != currentUser.id) {
          return;
        }
        await BackendRepository.sendThreadMessage(
          threadId: normalizedThreadId,
          text: normalizedText,
          idempotencyKey:
              'message_${normalizedThreadId}_${DateTime.now().microsecondsSinceEpoch}',
        );
        final prefs = await SharedPreferences.getInstance();
        final remote = await BackendRepository.getMessageThreads();
        await _persistMessageThreads(prefs, remote);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(prefs);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> list = jsonDecode(raw);
      bool mutated = false;

      for (int i = 0; i < list.length; i++) {
        try {
          final map = Map<String, dynamic>.from(list[i] as Map);
          if ((map['id']?.toString() ?? '') == normalizedThreadId) {
            final thread = MessageThread.fromJson(map);
            final isParticipant = thread.user1Id == currentUser.id ||
                thread.user2Id == currentUser.id;
            final senderIsAllowed = normalizedSenderId == 'system' ||
                normalizedSenderId == currentUser.id;
            if (!isParticipant || !senderIsAllowed) return;

            final now = DateTime.now();
            final newMessage = Message(
              id: 'msg_${now.microsecondsSinceEpoch}',
              senderId: normalizedSenderId,
              text: normalizedText,
              timestamp: now,
              isRead: false,
            );

            final updatedThread = thread.copyWith(
              messages: [...thread.messages, newMessage],
              lastMessageAt: now,
            );

            list[i] = updatedThread.toJson();
            mutated = true;
            break;
          }
        } catch (_) {}
      }

      if (mutated) {
        await _persistMessageThreads(prefs, list);
      }
    } catch (e) {
      debugPrint('[DataService] addMessageToThread error: $e');
    }
  }

  static Future<void> addMessageAttachmentToThread({
    required String threadId,
    required Uint8List bytes,
    required String filename,
    String text = 'Foto hinzugefügt',
  }) async {
    if (!BackendConfig.enabled || QaRuntimeService.isEnabled) {
      await addMessageToThread(
        threadId: threadId,
        senderId: 'system',
        text: text,
      );
      return;
    }
    final upload = await BackendRepository.uploadMessageAttachment(
      bytes: bytes,
      filename: filename,
      threadId: threadId,
    );
    await BackendRepository.sendThreadMessage(
      threadId: threadId,
      text: text,
      idempotencyKey:
          'attachment_${threadId}_${DateTime.now().microsecondsSinceEpoch}',
      attachmentIds: [upload['id'].toString()],
    );
    final prefs = await SharedPreferences.getInstance();
    final remote = await BackendRepository.getMessageThreads();
    await _persistMessageThreads(prefs, remote);
  }

  /// Markiert alle Nachrichten in einem Thread als gelesen für einen User
  static Future<void> markThreadMessagesAsRead({
    required String threadId,
    required String userId,
  }) async {
    try {
      if (BackendConfig.enabled && !QaRuntimeService.isEnabled) {
        await BackendRepository.markThreadRead(threadId);
        final prefs = await SharedPreferences.getInstance();
        final remote = await BackendRepository.getMessageThreads();
        await _persistMessageThreads(prefs, remote);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = await _readMessageThreads(prefs);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> list = jsonDecode(raw);
      bool mutated = false;

      for (int i = 0; i < list.length; i++) {
        try {
          final map = Map<String, dynamic>.from(list[i] as Map);
          if ((map['id']?.toString() ?? '') == threadId) {
            final thread = MessageThread.fromJson(map);
            var threadMutated = false;
            final updatedMessages = thread.messages.map((msg) {
              if (msg.senderId != userId && !msg.isRead) {
                threadMutated = true;
                return msg.copyWith(isRead: true);
              }
              return msg;
            }).toList();

            if (threadMutated) {
              final updatedThread = thread.copyWith(messages: updatedMessages);
              list[i] = updatedThread.toJson();
              mutated = true;
            }
            break;
          }
        } catch (_) {}
      }

      if (mutated) {
        await _persistMessageThreads(prefs, list);
      }
    } catch (e) {
      debugPrint('[DataService] markThreadMessagesAsRead error: $e');
    }
  }
}
