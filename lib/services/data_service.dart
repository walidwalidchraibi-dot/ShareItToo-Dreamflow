import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lendify/models/category.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/review.dart';
import 'package:lendify/models/multi_criteria_review.dart';
import 'package:lendify/models/message.dart';
import 'package:lendify/utils/total_subtitle.dart';

class DataService {
  static const String _categoriesKey = 'categories';
  static const String _itemsKey = 'items';
  static const String _usersKey = 'users';
  static const String _currentUserKey = 'currentUser';
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
  static const String _readRequestsKey = 'read_requests_v1'; // userId -> Set<requestId>
  static const String _handoverFailCountsKey = 'handover_fail_counts';
  static const String _handoverBannersKey = 'handover_banners';
  static const String _rideCompKey = 'ride_compensation_v1';
  // Wishlists
  static const String _wishlistsMetaKey = 'wishlists_meta_v1';
  static const String _wishlistAssignKey = 'wishlist_assign_v1';
  static const String _messageThreadsKey = 'message_threads_v1';

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
        try { map = jsonDecode(raw) as Map<String, dynamic>; } catch (_) { map = {}; }
      }
      final current = (map[bookingId] is num) ? (map[bookingId] as num).toInt() : 0;
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
  static Future<void> setHandoverBanner({required String bookingId, required String message}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_handoverBannersKey);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        try { map = jsonDecode(raw) as Map<String, dynamic>; } catch (_) { map = {}; }
      }
      map[bookingId] = {
        'msg': message,
        'ts': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_handoverBannersKey, jsonEncode(map));
    } catch (e) {
      // ignore but log for debug
      debugPrint('[DataService] setHandoverBanner failed: ' + e.toString());
    }
  }

  /// Returns and removes the banner text for a booking if present.
  static Future<String?> takeHandoverBanner(String bookingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_handoverBannersKey);
      if (raw == null || raw.isEmpty) return null;
      Map<String, dynamic> map;
      try { map = jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
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
      debugPrint('[DataService] takeHandoverBanner failed: ' + e.toString());
      return null;
    }
  }

  // Persisted availability selection per item
  static Future<(DateTime? start, DateTime? end)> getSavedDateRange(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingSelectionsKey);
    if (raw == null || raw.isEmpty) return (null, null);
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entry = map[itemId];
      if (entry is Map) {
        final s = entry['start'] as String?;
        final e = entry['end'] as String?;
        return (s != null ? DateTime.tryParse(s) : null, e != null ? DateTime.tryParse(e) : null);
      }
    } catch (_) {}
    return (null, null);
  }

  static Future<void> setSavedDateRange(String itemId, {required DateTime start, required DateTime end}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingSelectionsKey);
    Map<String, dynamic> map = {};
    if (raw != null && raw.isNotEmpty) {
      try { map = jsonDecode(raw) as Map<String, dynamic>; } catch (_) { map = {}; }
    }
    // Merge into existing per-item object instead of overwriting it so we
    // don't drop previously saved delivery selections.
    final existing = (map[itemId] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? <String, dynamic>{};
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
  static (double finalTotal, double baseTotal, double appliedPercent, double discountAmount) computeTotalWithDiscounts({
    required Item item,
    required int days,
  }) {
    final d = days.clamp(1, 3650);
    final base = (item.pricePerDay * d);
    if (!item.autoApplyDiscounts || item.longRentalDiscounts.isEmpty) {
      return (base, base, 0.0, 0.0);
    }
    // Pick the highest threshold <= days
    double pct = 0.0;
    for (final tier in item.longRentalDiscounts) {
      if (tier.days <= d && tier.discountPercent > pct) {
        pct = tier.discountPercent;
      }
    }
    final discountAmount = (base * (pct / 100)).clamp(0.0, base);
    final total = (base - discountAmount).clamp(0.0, base);
    return (total, base, pct, discountAmount);
  }

  /// Platform contribution ("Plattformbeitrag").
  /// Input: rentalSubtotal (after any rental discounts), excluding delivery/express.
  /// Rule update:
  ///  - Bis 10,00 € Mietbetrag: 1,00 €
  ///  - Ab 10,01 € Mietbetrag: 10 % des Mietbetrags
  /// Edge case: For a 0 € subtotal, the fee is 0 €.
  /// UI never shows percentages, only the absolute fee.
  static double platformContributionForRental(double rentalSubtotal) {
    final v = (rentalSubtotal.isNaN || rentalSubtotal.isInfinite || rentalSubtotal < 0) ? 0.0 : rentalSubtotal;
    if (v <= 0.0) return 0.0;
    if (v <= 10.0) return 1.0; // ≤ 10 € => 1 € flat
    final fee = v * 0.10; // ≥ 10.01 € => 10%
    return double.parse(fee.toStringAsFixed(2));
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
    final int days = (req.end.difference(req.start).inHours / 24).ceil().clamp(1, 365);
    final priced = computeTotalWithDiscounts(item: item, days: days);
    final double basePerDay = item.pricePerDay;
    final double baseTotal = priced.$2; // before discount
    final double discountAmount = priced.$4; // absolute EUR
    final double rentalSubtotal = priced.$1; // after discount
    final double platformFee = platformContributionForRental(rentalSubtotal);

    // Infer delivery responsibilities robustly (persisted flags first, then fallbacks)
    final bool inferredOwnerDeliversByTransient = (deliverySel?['hinweg'] == true);
    final bool inferredOwnerDeliversByExpress = req.expressRequested || (req.expressStatus != null);
    final bool inferredOwnerDeliversByAddress = ((req.deliveryAddressLine ?? '').toString().trim().isNotEmpty) || ((req.deliveryCity ?? '').toString().trim().isNotEmpty);
    final bool ownerDelivers = req.ownerDeliversAtDropoffChosen || inferredOwnerDeliversByTransient || inferredOwnerDeliversByExpress || inferredOwnerDeliversByAddress;

    final bool inferredOwnerPicksUpByTransient = (deliverySel?['rueckweg'] == true);
    final bool ownerPicksUp = req.ownerPicksUpAtReturnChosen || inferredOwnerPicksUpByTransient;

    // Distance estimation using best available signal
    double km = 0.0;
    final double? lat = req.deliveryLat ?? (deliverySel?['lat'] as num?)?.toDouble();
    final double? lng = req.deliveryLng ?? (deliverySel?['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      km = estimateDistanceKm(item.lat, item.lng, lat, lng);
    } else if ((req.deliveryAddressLine ?? '').toString().trim().isNotEmpty) {
      km = estimateDistanceKmFromAddressLine(item.lat, item.lng, req.deliveryAddressLine!.trim());
    } else if ((req.deliveryCity ?? '').toString().trim().isNotEmpty) {
      km = estimateDistanceKmToCity(item.lat, item.lng, req.deliveryCity!.trim());
    }

    double dropoffFee = 0.0;
    double returnFee = 0.0;
    if (ownerDelivers) dropoffFee = double.parse((km * 0.30).toStringAsFixed(2));
    if (ownerPicksUp) returnFee = double.parse((km * 0.30).toStringAsFixed(2));

    // Express: renter sees the surcharge as soon as it is selected/requested.
    // We consider three sources:
    //  - transient UI selection deliverySel['express']
    //  - request.expressRequested (persisted)
    //  - request.expressStatus == 'accepted' (persisted)
    final bool expressSelectedTransient = (deliverySel?['express'] == true);
    final bool expressAccepted = req.expressRequested && (req.expressStatus == 'accepted');
    final bool expressRequestedOrSelected = expressSelectedTransient || req.expressRequested || expressAccepted;
    final double expressApplied = expressRequestedOrSelected ? (req.expressFee) : 0.0; // renter-facing
    // New rule: add 10% of the Express surcharge to the renter total
    final double expressPlatformPart = expressApplied > 0 ? double.parse((expressApplied * 0.10).toStringAsFixed(2)) : 0.0;

    final double totalRenter = double.parse((rentalSubtotal + platformFee + dropoffFee + returnFee + expressApplied + expressPlatformPart).toStringAsFixed(2));
    // Owner payout should only include express when accepted
    final double payoutOwner = double.parse((rentalSubtotal + dropoffFee + returnFee + (expressAccepted ? req.expressFee : 0.0)).toStringAsFixed(2));

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
      deposit: item.deposit,
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

    Future<void> _persist(List<dynamic> payload) async {
      await prefs.setString(_itemsKey, jsonEncode(payload));
    }

    // Try to persist, falling back to photo sanitation when web storage quota is exceeded.
    try {
      await _persist(list);
    } catch (e) {
      debugPrint('[DataService] addItem persist failed, attempting to shrink payload: ' + e.toString());
      // 1) Replace base64 data URLs with lightweight placeholders and limit to max 3 photos per item
      List<dynamic> shrunk = list.map((raw) {
        try {
          final m = Map<String, dynamic>.from(raw as Map);
          final photos = (m['photos'] as List?)?.map((p) => p?.toString() ?? '').where((s) => s.isNotEmpty).toList() ?? <String>[];
          final limited = <String>[];
          int idx = 0;
          for (final p in photos) {
            if (idx >= 3) break;
            if (p.startsWith('data:')) {
              // Deterministic placeholder per item id and index to keep UI varied
              limited.add('https://picsum.photos/seed/${m['id'] ?? 'x'}_${idx}/800/800');
            } else {
              limited.add(p);
            }
            idx++;
          }
          if (limited.isEmpty) {
            limited.add('https://picsum.photos/seed/${m['id'] ?? 'x'}/800/800');
          }
          m['photos'] = limited;
          return m;
        } catch (_) {
          return raw;
        }
      }).toList();
      try {
        await _persist(shrunk);
      } catch (e2) {
        debugPrint('[DataService] addItem persist still failing after shrink: ' + e2.toString());
        // 2) Last resort: strip photos entirely to guarantee saving
        final stripped = shrunk.map((raw) {
          try {
            final m = Map<String, dynamic>.from(raw as Map);
            m['photos'] = <String>[];
            return m;
          } catch (_) { return raw; }
        }).toList();
        await _persist(stripped);
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
    return categoriesList.map((json) => Category.fromJson(json)).toList();
  }

  static Future<List<Item>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
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
        debugPrint('[DataService] Skipped corrupted item entry: ' + e.toString());
      }
    }
    if (mutated) {
      await prefs.setString(_itemsKey, jsonEncode(parsed.map((e) => e.toJson()).toList()));
    }
    List<Item> items = parsed;

    // Auto-clean: delete "ended" items older than 60 days
    final now = DateTime.now();
    final filtered = <Item>[];
    bool mutatedAging = false;
    for (final it in items) {
      if (it.status == 'ended' && it.endedAt != null) {
        final diff = now.difference(it.endedAt!).inDays;
        if (diff >= 60) { mutatedAging = true; continue; }
      }
      filtered.add(it);
    }
    if (mutatedAging) {
      await prefs.setString(_itemsKey, jsonEncode(filtered.map((e) => e.toJson()).toList()));
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

  /// Clears all persisted listings and seeds exactly five showcase items
  /// that reflect the latest delivery/return and express logic.
  /// If [force] is false, it will only run once per device based on a flag.
  static Future<void> resetItemsAndSeedFive({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final already = prefs.getBool(_seedFiveFlagKey) ?? false;
    if (!force && already) return;

    // Ensure categories and users exist
    if (prefs.getString(_categoriesKey) == null || prefs.getString(_usersKey) == null) {
      await _initializeSampleData();
    }

    // Load needed references
    final categories = await getCategories();
    final users = await getUsers();

    // Build five curated items
    final five = _buildFiveShowcaseItems(users, categories);

    await prefs.setString(_itemsKey, jsonEncode(five.map((e) => e.toJson()).toList()));
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
      if (!map.containsKey('createdAt') || map['createdAt'] == null || (map['createdAt'] as String).isEmpty) {
        map['createdAt'] = DateTime.now().toIso8601String(); mutated = true;
      }
      if (!map.containsKey('avgRating') || map['avgRating'] == null) { map['avgRating'] = 0.0; mutated = true; }
      if (!map.containsKey('reviewCount') || map['reviewCount'] == null) { map['reviewCount'] = 0; mutated = true; }
      final id = map['id']?.toString();
      if (id != null) {
        final override = _seedForId(id);
        if (override != null) {
          if (map['displayName'] != override.$1) { map['displayName'] = override.$1; mutated = true; }
          if (map['photoURL'] != override.$2) { map['photoURL'] = override.$2; mutated = true; }
        }
      }
      return map;
    }).toList();

    if (mutated) {
      await prefs.setString(_usersKey, jsonEncode(fixed));
    }
    return fixed.map((json) => User.fromJson(json)).toList();
  }

  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_currentUserKey);
    if (userJson == null) return null;

    final Map<String, dynamic> map = jsonDecode(userJson) as Map<String, dynamic>;
    bool mutated = false;
    if (!map.containsKey('createdAt') || (map['createdAt'] == null || (map['createdAt'] as String).isEmpty)) {
      map['createdAt'] = DateTime.now().toIso8601String(); mutated = true;
    }
    if (!map.containsKey('avgRating') || map['avgRating'] == null) { map['avgRating'] = 0.0; mutated = true; }
    if (!map.containsKey('reviewCount') || map['reviewCount'] == null) { map['reviewCount'] = 0; mutated = true; }

    // Personalize the display name for the current user to "Walid Chraibi"
    if (map['displayName'] != 'Walid Chraibi') {
      map['displayName'] = 'Walid Chraibi';
      mutated = true;
    }
    final id = map['id']?.toString();
    if (id != null) {
      final override = _seedForId(id);
      if (override != null && map['photoURL'] != override.$2) {
        map['photoURL'] = override.$2;
        mutated = true;
      }
    }

    final user = User.fromJson(map);
    if (mutated) {
      await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    }
    return user;
  }

  static Future<void> setCurrentUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
  }

  static const String _savedItemsKey = 'saved_item_ids';

  static Future<void> updateItemStatus({required String itemId, required String status}) async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString(_itemsKey);
    if (itemsJson == null) return;
    final List<dynamic> list = jsonDecode(itemsJson);
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
        mutated = true; list[i] = map; break;
      }
    }
    if (mutated) {
      await prefs.setString(_itemsKey, jsonEncode(list));
    }
  }

  static Future<void> updateItem(Item updated) async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString(_itemsKey);
    if (itemsJson == null) return;
    final List<dynamic> list = jsonDecode(itemsJson);
    bool mutated = false;
    for (int i = 0; i < list.length; i++) {
      final map = Map<String, dynamic>.from(list[i] as Map);
      if (map['id'].toString() == updated.id.toString()) {
        list[i] = updated.toJson();
        mutated = true; break;
      }
    }
    if (!mutated) return;
    Future<void> _persist(List<dynamic> payload) async {
      await prefs.setString(_itemsKey, jsonEncode(payload));
    }
    try {
      await _persist(list);
    } catch (e) {
      debugPrint('[DataService] updateItem persist failed, attempting to shrink payload: ' + e.toString());
      // Shrink photos across all items (limit to 3, replace base64 with placeholders)
      List<dynamic> shrunk = list.map((raw) {
        try {
          final m = Map<String, dynamic>.from(raw as Map);
          final photos = (m['photos'] as List?)?.map((p) => p?.toString() ?? '').where((s) => s.isNotEmpty).toList() ?? <String>[];
          final limited = <String>[];
          int idx = 0;
          for (final p in photos) {
            if (idx >= 3) break;
            if (p.startsWith('data:')) {
              limited.add('https://picsum.photos/seed/${m['id'] ?? 'x'}_${idx}/800/800');
            } else {
              limited.add(p);
            }
            idx++;
          }
          if (limited.isEmpty) {
            limited.add('https://picsum.photos/seed/${m['id'] ?? 'x'}/800/800');
          }
          m['photos'] = limited;
          return m;
        } catch (_) {
          return raw;
        }
      }).toList();
      try {
        await _persist(shrunk);
      } catch (e2) {
        debugPrint('[DataService] updateItem persist still failing after shrink: ' + e2.toString());
        final stripped = shrunk.map((raw) {
          try { final m = Map<String, dynamic>.from(raw as Map); m['photos'] = <String>[]; return m; } catch (_) { return raw; }
        }).toList();
        await _persist(stripped);
      }
    }
  }

  static Future<void> deleteItemById(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getString(_itemsKey);
    if (itemsJson == null) return;
    final List<dynamic> list = jsonDecode(itemsJson);
    final before = list.length;
    list.removeWhere((e) => (e as Map)['id'].toString() == itemId.toString());
    if (list.length != before) {
      await prefs.setString(_itemsKey, jsonEncode(list));
    }
  }

  static Future<List<Item>> getPublicItems() async {
    final items = await getItems();
    final filtered = items.where((e) => (e.status == 'active') || (e.isActive == true && e.status != 'ended')).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
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
        try { list = jsonDecode(raw); } catch (_) { list = []; }
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
        list.add({'id': wlSoonId, 'name': 'Demnächst benötigt', 'system': true});
      }
      if (!hasLater) {
        list.add({'id': wlLaterId, 'name': 'Für später', 'system': true});
      }
      if (!hasAgain) {
        list.add({'id': wlAgainId, 'name': 'Wieder mieten', 'system': true});
      }
      await prefs.setString(_wishlistsMetaKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[DataService] _ensureDefaultWishlists error: ' + e.toString());
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
            if (e is Map) Map<String, dynamic>.from(e)
        ];
      } catch (e) {
        debugPrint('[DataService] getWishlists decode failed: ' + e.toString());
      }
    }
    // Sort: system first in order soon, later, again; then custom by name
    out.sort((a, b) {
      final as = a['system'] == true;
      final bs = b['system'] == true;
      if (as && !bs) return -1;
      if (!as && bs) return 1;
      if (as && bs) {
        int rank(String id) => id == wlSoonId ? 0 : (id == wlLaterId ? 1 : (id == wlAgainId ? 2 : 99));
        return rank((a['id'] ?? '').toString()).compareTo(rank((b['id'] ?? '').toString()));
      }
      return ((a['name'] ?? '').toString()).toLowerCase().compareTo(((b['name'] ?? '').toString()).toLowerCase());
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
      debugPrint('[DataService] addCustomWishlist failed: ' + e.toString());
    }
    return id;
  }

  /// Deletes a custom wishlist by id (no-op for system lists). Also clears its assignments.
  static Future<void> deleteCustomWishlist(String id) async {
    if (id == wlSoonId || id == wlLaterId || id == wlAgainId) return; // cannot delete system
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
      debugPrint('[DataService] deleteCustomWishlist failed: ' + e.toString());
    }
  }

  /// Renames a custom wishlist. No-op for system lists.
  static Future<void> renameCustomWishlist({required String id, required String newName}) async {
    if (id == wlSoonId || id == wlLaterId || id == wlAgainId) return; // cannot rename system
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
        } catch (_) {/* ignore malformed entry */}
      }
      if (mutated) {
        await prefs.setString(_wishlistsMetaKey, jsonEncode(list));
      }
    } catch (e) {
      debugPrint('[DataService] renameCustomWishlist failed: ' + e.toString());
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
      return v == null ? null : v.toString();
    } catch (e) {
      debugPrint('[DataService] getWishlistForItem failed: ' + e.toString());
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
        try { map = jsonDecode(raw) as Map<String, dynamic>; } catch (_) { map = {}; }
      }
      map[itemId] = listId;
      await prefs.setString(_wishlistAssignKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[DataService] setItemWishlist failed: ' + e.toString());
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
      debugPrint('[DataService] removeItemFromWishlist failed: ' + e.toString());
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
        try { map = jsonDecode(raw) as Map<String, dynamic>; } catch (_) { map = {}; }
      }
      for (final it in items) {
        final id = (map[it.id]?.toString() ?? '');
        if (id.isEmpty) continue;
        out.putIfAbsent(id, () => []).add(it);
      }
    } catch (e) {
      debugPrint('[DataService] getItemsByWishlist failed: ' + e.toString());
    }
    return out;
  }

  static Future<void> _initializeSampleData() async {
    final prefs = await SharedPreferences.getInstance();

    final categories = _buildDemoCategories();
    await prefs.setString(_categoriesKey, jsonEncode(categories.map((c) => c.toJson()).toList()));

    final users = _buildDemoUsers();
    final items = _buildDemoItems(users, categories);
    final reviews = _buildDemoReviews(users);

    // Ensure stored review counts reflect actual demo reviews for consistency across the app.
    final reviewCounts = <String, int>{};
    for (final review in reviews) {
      reviewCounts.update(review.reviewedUserId, (value) => value + 1, ifAbsent: () => 1);
    }

    final usersWithCounts = [
      for (final user in users)
        user.copyWith(reviewCount: reviewCounts[user.id] ?? user.reviewCount)
    ];

    await prefs.setString(_usersKey, jsonEncode(usersWithCounts.map((u) => u.toJson()).toList()));
    await prefs.setString(_itemsKey, jsonEncode(items.map((i) => i.toJson()).toList()));
    await prefs.setString(_reviewsKey, jsonEncode(reviews.map((r) => r.toJson()).toList()));

    await prefs.setString(_currentUserKey, jsonEncode(usersWithCounts.first.toJson()));
    // Ensure wishlists are initialized once demo data is set up.
    try { await _ensureDefaultWishlists(); } catch (e) { debugPrint('[DataService] ensureDefaultWishlists failed: '+e.toString()); }
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

  static Map<String, (double lat, double lng)> getCities() => Map.unmodifiable(_cities);

  // Returns the closest known city name for a given coordinate.
  static String nearestCityName(double lat, double lng) {
    String nearest = _cities.keys.first;
    double best = double.infinity;
    for (final entry in _cities.entries) {
      final d = _haversine(lat, lng, entry.value.$1, entry.value.$2);
      if (d < best) { best = d; nearest = entry.key; }
    }
    return nearest;
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) + (cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180.0);

  // Delivery helpers
  static double estimateDistanceKm(double fromLat, double fromLng, double toLat, double toLng) {
    return _haversine(fromLat, fromLng, toLat, toLng);
  }

  static double estimateDistanceKmToCity(double fromLat, double fromLng, String cityName) {
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
    'Haushalt & Wohnen',
    'Fahrzeuge & Mobilität',
    'Mode & Lifestyle',
    'Sport & Hobbys',
    'Werkzeuge & Kleingeräte',
    'Garten & Hof',
    'Büro & Gewerbe',
    'Babys & Kinder',
    'Haustierbedarf',
    'Sonstiges',
  ];

  /// Maps a fine-grained category name (e.g., "Elektronik", "Kameras & Drohnen")
  /// to a coarse, simplified group used for display. Defaults to "Sonstiges".
  static String coarseCategoryFor(String name) {
    final n = name.toLowerCase();
    // Known mappings from demo data to coarse buckets
    if (n.contains('elektronik') || n.contains('computer') || n.contains('kamera') || n.contains('drohn') || n.contains('gaming') || n.contains('vr')) {
      return 'Technik & Elektronik';
    }
    if (n.contains('haushalt') || n.contains('haushalts') || n.contains('möbel') || n.contains('moebel') || n.contains('wohnen') || n.contains('beleuchtung')) {
      return 'Haushalt & Wohnen';
    }
    if (n.contains('fahrzeug') || n.contains('teile') || n.contains('fahrräder') || n.contains('fahrraeder') || n.contains('e-mobility') || n.contains('bike') || n.contains('e-scooter')) {
      return 'Fahrzeuge & Mobilität';
    }
    if (n.contains('mode') || n.contains('accessoires') || n.contains('schmuck') || n.contains('uhren')) {
      return 'Mode & Lifestyle';
    }
    if (n.contains('freizeit') || n.contains('sport') || n.contains('outdoor')) {
      return 'Sport & Hobbys';
    }
    if (n.contains('werkzeug') || n.contains('maschinen') || n.contains('handwerk')) {
      return 'Werkzeuge & Kleingeräte';
    }
    if (n.contains('garten') || n.contains('heimwerken')) {
      return 'Garten & Hof';
    }
    if (n.contains('büro') || n.contains('buero') || n.contains('gewerbe')) {
      return 'Büro & Gewerbe';
    }
    if (n.contains('baby') || n.contains('kinder')) {
      return 'Babys & Kinder';
    }
    if (n.contains('haustier')) {
      return 'Haustierbedarf';
    }
    return 'Sonstiges';
  }

  static Future<Map<String, dynamic>?> getSavedDeliverySelection(String itemId) async {
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
        if (!map.containsKey('express')) map['express'] = false; // ensure key exists for priority
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingSelectionsKey);
    Map<String, dynamic> map = {};
    if (raw != null && raw.isNotEmpty) {
      try { map = jsonDecode(raw) as Map<String, dynamic>; } catch (_) { map = {}; }
    }
    final existing = (map[itemId] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? <String, dynamic>{};
    existing['delivery'] = {
      'hinweg': hinweg,
      'rueckweg': rueckweg,
      'city': addressCity ?? '',
      'addressLine': addressLine,
      'express': express,
      'lat': lat,
      'lng': lng,
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
  static double estimateDistanceKmFromAddressLine(double fromLat, double fromLng, String addressLine) {
    final city = deriveCityFromAddress(addressLine);
    if (city.isNotEmpty) {
      return estimateDistanceKmToCity(fromLat, fromLng, city);
    }
    // Fallback: use the nearest city to the item coordinate as a proxy (0 km)
    // so that we don't block checkout without maps integration.
    return 0.0;
  }

  // Simple availability check stub – returns true. Replace with real inventory logic when backend is connected.
  static Future<bool> checkAvailability({required String itemId, required DateTime start, required DateTime end}) async {
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
  static Future<List<DateTimeRange>> getUnavailableRangesForItem(String itemId) async {
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
    final List<(String id, String name, String slug, String iconName, List<String> subs)> data = [
      ('cat1',  'Elektronik',                 'elektronik',                 'devices',           ['Smartphones','Tablets','Wearables','Audio','Zubehör']),
      ('cat2',  'Computer & IT',              'computer-it',               'computer',          ['Laptops','Desktops','Monitore','Drucker','Netzwerk']),
      ('cat3',  'Kameras & Drohnen',          'kameras-drohnen',           'camera_alt',        ['Kameras','Objektive','Drohnen','Stative','Licht']),
      ('cat4',  'Gaming & VR',                'gaming-vr',                 'sports_esports',    ['Konsolen','Gaming-PC','VR','Lenkräder','Retro']),
      ('cat5',  'Haushaltsgeräte',            'haushaltsgeraete',          'kitchen',           ['Staubsauger','Mixer','Kaffeemaschinen','Waschmaschinen','Trockner']),
      ('cat6',  'Möbel & Wohnen',             'moebel-wohnen',             'weekend',           ['Sofas','Tische','Stühle','Beleuchtung','Deko']),
      ('cat7',  'Garten & Heimwerken',        'garten-heimwerken',         'grass',             ['Rasenmäher','Heckenscheren','Gartengeräte','Bewässerung','Pflanzkisten']),
      ('cat8',  'Werkzeuge & Maschinen',      'werkzeuge-maschinen',       'construction',      ['Handwerkzeuge','Elektrowerkzeuge','Bohrmaschinen','Sägen','Schleifer']),
      ('cat9',  'Fahrräder & E-Mobility',      'fahrraeder-e-mobility',     'pedal_bike',        ['Citybikes','MTB','E-Bikes','E-Scooter','Zubehör']),
      ('cat10', 'Fahrzeuge & Teile',           'fahrzeuge-teile',           'directions_car',    ['Kleinwagen','SUV','Transporter','Wohnmobil','Anhänger']),
      ('cat11', 'Freizeit, Sport & Outdoor',   'freizeit-sport-outdoor',    'sports_soccer',     ['Fitness','Teamsport','Racketsport','Radsport','Wassersport']),
      ('cat12', 'Mode & Accessoires',         'mode-accessoires',          'checkroom',         ['Kleidung','Taschen','Schuhe','Schmuck','Uhren']),
      ('cat13', 'Baby, Kinder & Spielzeug',   'baby-kinder-spielzeug',     'child_friendly',    ['Kinderwagen','Sitze','Spielzeug','Tragen','Sicherheit']),
      ('cat14', 'Musikinstrumente & DJ',      'musikinstrumente-dj',       'music_note',        ['Gitarren','Tastaturen','Schlagzeug','Blasinstrumente','Studio']),
      ('cat15', 'Bücher, Filme & Medien',     'buecher-filme-medien',      'menu_book',         ['Bücher','Filme','Spiele','Hörbücher','Magazine']),
      ('cat16', 'Schmuck & Uhren',            'schmuck-uhren',             'watch',             ['Ringe','Ketten','Uhren','Ohrringe','Sets']),
      ('cat17', 'Kunst & Sammlerstücke',      'kunst-sammlerstuecke',      'palette',           ['Gemälde','Skulpturen','Drucke','Figuren','Seltenes']),
      ('cat18', 'Beauty & Gesundheit',        'beauty-gesundheit',         'spa',               ['Kosmetik','Pflege','Wellness','Medizin','Zubehör']),
      ('cat19', 'Haustierbedarf',             'haustierbedarf',            'pets',              ['Hunde','Katzen','Kleintiere','Aquaristik','Zubehör']),
      ('cat20', 'Büro & Gewerbe',             'buero-gewerbe',             'business_center',   ['Bürotechnik','Präsentation','Werkstatt','Lager','Zubehör']),
      ('cat21', 'Sonstiges',                  'sonstiges',                 'more_horiz',        ['Diverses']),
    ];
    return [
      for (final d in data)
        Category(id: d.$1, name: d.$2, slug: d.$3, iconName: d.$4, subcategories: d.$5, createdAt: now)
    ];
  }

  static const List<(String id, String name, String photo)> _userSeeds = [
    ('u1', 'Walid Chraibi', 'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=150&h=150&fit=crop&crop=face'),
    ('u2', 'Max Mustermann', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face'),
    ('u3', 'Sarah Schmidt', 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&h=150&fit=crop&crop=face'),
    ('u4', 'Thomas Weber', 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&h=150&fit=crop&crop=face'),
    ('u5', 'Julia Wagner', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop&crop=face'),
    ('u6', 'David König', 'https://images.unsplash.com/photo-1519345182560-3f2917c472ef?w=150&h=150&fit=crop&crop=face'),
    ('u7', 'Anna Keller', 'https://images.unsplash.com/photo-1520813792240-56fc4a3765a7?w=150&h=150&fit=crop&crop=face'),
    ('u8', 'Laura Krüger', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150&h=150&fit=crop&crop=face'),
    ('u9', 'Daniel Hoffmann', 'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=150&h=150&fit=crop&crop=face'),
    ('u10', 'Sophie Lehmann', 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150&h=150&fit=crop&crop=face'),
    ('u11', 'Jonas Maier', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&h=150&fit=crop&crop=face'),
    ('u12', 'Lea Schuster', 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150&h=150&fit=crop&crop=face'),
    ('u13', 'Felix Braun', 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=150&h=150&fit=crop&crop=face'),
    ('u14', 'Mia Sauer', 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&h=150&fit=crop&crop=face'),
    ('u15', 'Tobias Busch', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face'),
    ('u16', 'Nina Scholz', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&crop=face'),
    ('u17', 'Sebastian Hartmann', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=face'),
    ('u18', 'Eva Fuchs', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&h=150&fit=crop&crop=face'),
    ('u19', 'Paul Engel', 'https://images.unsplash.com/photo-1531891437562-4301cf35b7e4?w=150&h=150&fit=crop&crop=face'),
    ('u20', 'Clara Wolf', 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&h=150&fit=crop&crop=face'),
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
        )
    ];
  }

  static List<Item> _buildDemoItems(List<User> users, List<Category> categories) {
    final rnd = Random(99);
    final now = DateTime.now();
    final List<(String city, (double, double) pos)> cities = [
      for (final e in _cities.entries) (e.key, (e.value.$1, e.value.$2))
    ];

    // Title seeds by category
    final Map<String, List<String>> titles = {
      'cat1':  ['iPhone 14 Pro', 'Samsung Galaxy S23', 'iPad Pro 11"', 'Kindle Paperwhite', 'Sony WH-1000XM5'],
      'cat2':  ['MacBook Air M2', '27" Monitor', 'WiFi 6 Router', 'QNAP NAS', 'Laserdrucker'],
      'cat3':  ['Canon EOS R5', 'Sony A7 IV', 'DJI Mini 3 Pro', 'Fujifilm X-T5', 'Nikon Z6 II'],
      'cat4':  ['PS5 Konsole', 'Gaming-PC', 'VR Headset', 'Nintendo Switch', 'Rennlenkrad'],
      'cat5':  ['Dyson Staubsauger', 'KitchenAid Mixer', 'Jura Kaffeemaschine', 'Miele Waschmaschine', 'Bosch Trockner'],
      'cat6':  ['Samt-Sofa 3-Sitzer', 'Esstisch Eiche', 'Design-Lampe', 'Barhocker', 'Sideboard'],
      'cat7':  ['Rasenmäher', 'Heckenschere', 'Hochdruckreiniger', 'Gartenhäcksler', 'Schubkarre'],
      'cat8':  ['Bosch Bohrmaschine', 'Makita Akkuschrauber', 'DeWalt Kreissäge', 'Einhell Winkelschleifer', 'Metabo Stichsäge'],
      'cat9':  ['E-Bike Trekking', 'Mountainbike', 'E-Scooter', 'Citybike', 'Rennrad'],
      'cat10': ['VW Golf', 'BMW 3er', 'Mercedes Sprinter', 'Wohnmobil Ducato', 'Dachbox'],
      'cat11': ['SUP-Board', 'Kletterausrüstung', '2-Personen Zelt', 'Ski-Set', 'Inlineskates'],
      'cat12': ['Abendkleid', 'Ledertasche', 'Sneaker', 'Armbanduhr', 'Sonnenbrille'],
      'cat13': ['Kinderwagen', 'Kindersitz', 'Laufrad', 'Babyphone', 'Tragehilfe'],
      'cat14': ['Akustikgitarre', 'E-Piano', 'DJ Controller', 'Saxophon', 'Studio-Mikrofon'],
      'cat15': ['Buchpaket Sci-Fi', 'Blu-ray Sammlung', 'Brettspiele', 'Hörbuch-Set', 'Manga-Box'],
      'cat16': ['Armbanduhr', 'Halskette', 'Ohrringe', 'Perlenkette', 'Uhrenbox'],
      'cat17': ['Gemälde Öl', 'Skulptur', 'Vintage Figur', 'Posterlimit', 'Vinyl Sammlung'],
      'cat18': ['Massagepistole', 'Infrarotlampe', 'Haartrockner', 'Glätteisen', 'Ionenluftreiniger'],
      'cat19': ['Hundetransportbox', 'Kratzbaum', 'Aquarien-Set', 'Hundebuggy', 'Futterautomat'],
      'cat20': ['Beamer', 'Flipchart', 'Bohrhammer', 'Industriesauger', 'Messestand'],
      'cat21': ['Werkzeugkoffer', 'Überraschungspaket', 'Diverse Dinge'],
    };

    int idCounter = 1;
    final List<Item> items = [];
    final int targetCount = 160 + rnd.nextInt(40); // 160–199

    List<String> photosFor(String key, int seed, String catId) {
      // Use category-specific images with reliable sources
      final Map<String, List<String>> categoryImages = {
        'cat1': [ // Elektronik
          'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556656793-08538906a9f8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1545127398-14699f92334b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1585060544812-6b45742d762f?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1483736762161-1d107f3c78e1?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556656793-08538906a9f8?w=800&h=800&fit=crop'
        ],
        'cat2': [ // Computer & IT
          'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1587831990711-23ca6441447b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1484788984921-03950022c9ef?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1517077304055-6e89abbf09b0?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1616628188540-26abf1d75b5b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1587831990711-23ca6441447b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1484788984921-03950022c9ef?w=800&h=800&fit=crop'
        ],
        'cat3': [ // Kameras & Drohnen
          'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1473496169904-658ba7c44d8a?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1606983340126-99ab4feaa64a?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1486401899868-0e435ed85128?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1495592822108-9e6261896da8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1473496169904-658ba7c44d8a?w=800&h=800&fit=crop'
        ],
        'cat4': [ // Gaming & VR
          'https://images.unsplash.com/photo-1493711662062-fa541adb3fc8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1592840331013-9c57c6f3a3b8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1574292384054-9a63e9c5cfb0?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1493711662062-fa541adb3fc8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1592840331013-9c57c6f3a3b8?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=800&h=800&fit=crop'
        ],
        'cat5': [ // Haushaltsgeräte
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556909202-f6d704471045?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1570222094114-d054a817e56b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556909202-f6d704471045?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1570222094114-d054a817e56b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=800&fit=crop'
        ],
        'cat8': [ // Werkzeuge & Maschinen
          'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1609205842104-8e045f7e3e3c?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1544716278-e513176f20a5?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1611269154421-4e27233ac5c7?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1609205842104-8e045f7e3e3c?w=800&h=800&fit=crop'
        ],
        'cat9': [ // Fahrräder & E-Mobility
          'https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1502744688674-c619d1586c9e?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1544191696-15693074e8b5?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1502744688674-c619d1586c9e?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1544191696-15693074e8b5?w=800&h=800&fit=crop',
          'https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=800&h=800&fit=crop'
        ],
      };

      final images = categoryImages[catId] ?? [
        'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800&h=800&fit=crop',
        'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800&h=800&fit=crop',
        'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=800&h=800&fit=crop',
        'https://images.unsplash.com/photo-1541807084-5c52b6b3adef?w=800&h=800&fit=crop',
        'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800&h=800&fit=crop',
        'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800&h=800&fit=crop',
        'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=800&h=800&fit=crop',
        'https://images.unsplash.com/photo-1541807084-5c52b6b3adef?w=800&h=800&fit=crop',
        'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800&h=800&fit=crop'
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
        'cat1'  => 12 + rnd.nextInt(30),  // Elektronik
        'cat2'  => 8 + rnd.nextInt(25),   // Computer & IT
        'cat3'  => 35 + rnd.nextInt(100), // Kameras & Drohnen
        'cat4'  => 10 + rnd.nextInt(35),  // Gaming & VR
        'cat5'  => 10 + rnd.nextInt(35),  // Haushaltsgeräte
        'cat6'  => 10 + rnd.nextInt(30),  // Möbel & Wohnen
        'cat7'  => 7 + rnd.nextInt(20),   // Garten & Heimwerken
        'cat8'  => 8 + rnd.nextInt(20),   // Werkzeuge & Maschinen
        'cat9'  => 8 + rnd.nextInt(22),   // Fahrräder & E-Mobility
        'cat10' => 40 + rnd.nextInt(120), // Fahrzeuge & Teile
        'cat11' => 6 + rnd.nextInt(25),   // Freizeit, Sport & Outdoor
        'cat12' => 4 + rnd.nextInt(20),   // Mode & Accessoires
        'cat13' => 5 + rnd.nextInt(18),   // Baby, Kinder & Spielzeug
        'cat14' => 8 + rnd.nextInt(30),   // Musikinstrumente & DJ
        'cat15' => 3 + rnd.nextInt(10),   // Bücher, Filme & Medien
        'cat16' => 6 + rnd.nextInt(24),   // Schmuck & Uhren
        'cat17' => 8 + rnd.nextInt(27),   // Kunst & Sammlerstücke
        'cat18' => 5 + rnd.nextInt(17),   // Beauty & Gesundheit
        'cat19' => 4 + rnd.nextInt(14),   // Haustierbedarf
        'cat20' => 12 + rnd.nextInt(38),  // Büro & Gewerbe
        'cat21' => 10 + rnd.nextInt(30),  // Sonstiges
        _ => 10 + rnd.nextInt(30),
      };

      final isNewish = i < 80; // ensure at least 80 latest
      final createdAt = now.subtract(Duration(days: isNewish ? rnd.nextInt(10) : 10 + rnd.nextInt(350)));
      final verified = rnd.nextDouble() < 0.6; // ~60%

      // Determine demo delivery offerings
      final bool offerDropoff = rnd.nextDouble() < 0.5; // ~50%
      final bool offerPickup = rnd.nextDouble() < 0.5;  // ~50%
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
        subcategory: cat.subcategories.isNotEmpty ? cat.subcategories.first : '-',
        tags: [cat.slug, city.$1],
        pricePerDay: basePrice.toDouble(),
        currency: 'EUR',
        priceUnit: 'day',
        priceRaw: basePrice.toDouble(),
        deposit: null,
        photos: photosFor(cat.slug, i, cat.id),
        locationText: '${city.$1}-${['Mitte','Nord','Süd','Ost','West'][rnd.nextInt(5)]}',
        lat: lat,
        lng: lng,
        geohash: 'u' '${rnd.nextInt(9)}' '${rnd.nextInt(9)}' '${rnd.nextInt(9)}' '${rnd.nextInt(9)}',
        condition: ['new','like-new','good','acceptable'][rnd.nextInt(4)],
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
        cancellationPolicy: ['flexible','moderate','strict'][rnd.nextInt(3)],
      );
      items.add(item);
    }

    // Ensure at least 60 items have >=9 photos (already 9 by design) and mark them newest
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static List<Item> _buildFiveShowcaseItems(List<User> users, List<Category> categories) {
    final now = DateTime.now();
    // Pick a stable owner and cities
    final owner = users.isNotEmpty ? users.first : User(
      id: 'u1', displayName: 'Demo User', email: 'demo@demo', city: 'Berlin', country: 'Deutschland',
      preferredLanguage: 'de-DE', isVerified: true, isBanned: false, role: 'user', avgRating: 4.8, reviewCount: 12,
      createdAt: now, photoURL: '', languages: const ['Deutsch'],
    );
    final berlin = _cities['Berlin'] ?? (52.52, 13.405);
    Category cat(String id) => categories.firstWhere((c) => c.id == id, orElse: () => categories.first);

    String gh(int i) => 'u${i}3${i}h${i}';

    List<Item> items = [
      // 1) E-Bike with delivery at dropoff up to 10km
      Item(
        id: '1', ownerId: owner.id, title: 'E-Bike Trekking 28"',
        description: 'Top gepflegt, Akku 500Wh, sofort verfügbar.',
        categoryId: 'cat9', subcategory: 'E-Bikes', tags: const ['bike','e-bike','berlin'],
        pricePerDay: 19.0, currency: 'EUR', priceUnit: 'day', priceRaw: 19.0,
        deposit: null,
        photos: const ['https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=800&h=800&fit=crop'],
        locationText: 'Berlin-Mitte', lat: berlin.$1, lng: berlin.$2, geohash: gh(1),
        condition: 'like-new', minDays: 1, maxDays: 14,
        createdAt: now.subtract(const Duration(hours: 2)),
        isActive: true, verificationStatus: 'approved', city: 'Berlin', country: 'Deutschland',
        timesLent: 42, offersDeliveryAtDropoff: true, offersPickupAtReturn: false,
        offersExpressAtDropoff: true,
        maxDeliveryKmAtDropoff: 10,
        cancellationPolicy: 'flexible',
      ),
      // 2) Kamera mit Abholung bei Rückgabe bis 12km
      Item(
        id: '2', ownerId: owner.id, title: 'Canon EOS R6 + 24-105mm',
        description: 'Spitzenzustand, inkl. 2 Akkus und Ladegerät.',
        categoryId: 'cat3', subcategory: 'Kameras', tags: const ['kamera','canon','berlin'],
        pricePerDay: 45.0, currency: 'EUR', priceUnit: 'day', priceRaw: 45.0,
        deposit: null,
        photos: const ['https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=800&h=800&fit=crop'],
        locationText: 'Berlin-Prenzlauer Berg', lat: berlin.$1 + 0.01, lng: berlin.$2 + 0.01, geohash: gh(2),
        condition: 'like-new', minDays: 1, maxDays: 7,
        createdAt: now.subtract(const Duration(hours: 3)),
        isActive: true, verificationStatus: 'approved', city: 'Berlin', country: 'Deutschland',
        timesLent: 31, offersDeliveryAtDropoff: false, offersPickupAtReturn: true,
        maxPickupKmAtReturn: 12,
        cancellationPolicy: 'moderate',
      ),
      // 3) PS5 – zeigt keine Lieferoption (reines Selbstabholen)
      Item(
        id: '3', ownerId: owner.id, title: 'PlayStation 5 Digital Edition',
        description: 'Mit zweitem Controller, sehr leise, ideal fürs Wochenende.',
        categoryId: 'cat4', subcategory: 'Konsolen', tags: const ['gaming','ps5','berlin'],
        pricePerDay: 18.0, currency: 'EUR', priceUnit: 'day', priceRaw: 18.0,
        deposit: null,
        photos: const ['https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&h=800&fit=crop'],
        locationText: 'Berlin-Friedrichshain', lat: berlin.$1 - 0.01, lng: berlin.$2 - 0.01, geohash: gh(3),
        condition: 'good', minDays: 1, maxDays: 10,
        createdAt: now.subtract(const Duration(hours: 5)),
        isActive: true, verificationStatus: 'approved', city: 'Berlin', country: 'Deutschland',
        timesLent: 27,
        cancellationPolicy: 'strict',
      ),
      // 4) Dyson Staubsauger – Lieferung und Abholung mit je 5km
      Item(
        id: '4', ownerId: owner.id, title: 'Dyson Akku-Staubsauger V11',
        description: 'Sehr sauber, mit Wandhalterung und Extra-Düsen.',
        categoryId: 'cat5', subcategory: 'Staubsauger', tags: const ['haushalt','dyson','berlin'],
        pricePerDay: 12.0, currency: 'EUR', priceUnit: 'day', priceRaw: 12.0,
        deposit: null,
        photos: const ['https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=800&fit=crop'],
        locationText: 'Berlin-Charlottenburg', lat: berlin.$1 + 0.015, lng: berlin.$2 - 0.015, geohash: gh(4),
        condition: 'like-new', minDays: 1, maxDays: 14,
        createdAt: now.subtract(const Duration(hours: 7)),
        isActive: true, verificationStatus: 'approved', city: 'Berlin', country: 'Deutschland',
        timesLent: 15, offersDeliveryAtDropoff: true, offersPickupAtReturn: true,
        offersExpressAtDropoff: true,
        maxDeliveryKmAtDropoff: 5, maxPickupKmAtReturn: 5,
        cancellationPolicy: 'moderate',
      ),
      // 5) Bosch Bohrmaschine – Lieferung bis 7km, keine Abholung
      Item(
        id: '5', ownerId: owner.id, title: 'Bosch Bohrmaschine Professional',
        description: 'Robust, inkl. Koffer und Bohrer-Set.',
        categoryId: 'cat8', subcategory: 'Bohrmaschinen', tags: const ['werkzeug','bosch','berlin'],
        pricePerDay: 10.0, currency: 'EUR', priceUnit: 'day', priceRaw: 10.0,
        deposit: null,
        photos: const ['https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&h=800&fit=crop'],
        locationText: 'Berlin-Neukölln', lat: berlin.$1 - 0.02, lng: berlin.$2 + 0.01, geohash: gh(5),
        condition: 'good', minDays: 1, maxDays: 10,
        createdAt: now.subtract(const Duration(hours: 8)),
        isActive: true, verificationStatus: 'approved', city: 'Berlin', country: 'Deutschland',
        timesLent: 22, offersDeliveryAtDropoff: true, offersPickupAtReturn: false,
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

    void add(String reviewerId, String reviewedUserId, double rating, String comment, {int daysAgo = 0, int hoursAgo = 0}) {
      if (!existingIds.contains(reviewerId) || !existingIds.contains(reviewedUserId) || reviewerId == reviewedUserId) {
        return;
      }
      out.add(Review(
        id: 'r${out.length + 1}',
        reviewerId: reviewerId,
        reviewedUserId: reviewedUserId,
        rating: rating,
        comment: comment,
        createdAt: now.subtract(Duration(days: daysAgo, hours: hoursAgo)),
      ));
    }

    add('u1', 'u2', 4.9, 'Werkzeug war in Top-Zustand, Übergabe super flexibel.', daysAgo: 6, hoursAgo: 3);
    add('u7', 'u2', 5.0, 'Sehr hilfsbereit und schnelle Antworten auf Rückfragen.', daysAgo: 20, hoursAgo: 6);
    add('u11', 'u3', 4.8, 'Abholung lief reibungslos, würde wieder bei Sarah mieten.', daysAgo: 9, hoursAgo: 2);
    add('u5', 'u3', 4.7, 'Kamera war wie beschrieben, inklusive voll geladenem Akku.', daysAgo: 32, hoursAgo: 4);
    add('u10', 'u6', 5.0, 'David hat sich Zeit für eine kurze Einweisung genommen, top.', daysAgo: 12, hoursAgo: 5);
    add('u12', 'u6', 4.9, 'Sehr freundlich und flexibel bei der Rückgabe.', daysAgo: 45, hoursAgo: 7);
    add('u9', 'u8', 4.8, 'Laura hat den Zustand des E-Bikes genau erklärt, alles bestens.', daysAgo: 3, hoursAgo: 1);
    add('u14', 'u8', 5.0, 'Super Kommunikation und perfektes Zubehör dabei.', daysAgo: 14, hoursAgo: 8);
    add('u17', 'u10', 4.7, 'Konsole war sauber und sofort einsatzbereit.', daysAgo: 27, hoursAgo: 6);
    add('u18', 'u10', 4.9, 'Schnelle Übergabe und sehr sympathisch.', daysAgo: 58, hoursAgo: 3);
    add('u19', 'u9', 4.8, 'MacBook in neuwertigem Zustand, gerne wieder.', daysAgo: 16, hoursAgo: 2);
    add('u20', 'u9', 4.6, 'Abholung pünktlich und unkompliziert organisiert.', daysAgo: 70, hoursAgo: 5);
    add('u15', 'u4', 4.9, 'Thomas hat alles ausführlich erklärt, super Service.', daysAgo: 22, hoursAgo: 4);
    add('u13', 'u4', 4.8, 'Sehr zuverlässige Abstimmung und faire Konditionen.', daysAgo: 90, hoursAgo: 6);
    add('u8', 'u5', 4.7, 'Julia hat schnell auf Nachrichten reagiert und war flexibel.', daysAgo: 11, hoursAgo: 7);
    add('u6', 'u5', 4.9, 'Produkt top gepflegt, klare Empfehlung.', daysAgo: 61, hoursAgo: 2);

    return out;
  }

  static Future<List<Review>> _getAllReviews() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString(_reviewsKey);
    if (raw == null) {
      final users = await getUsers();
      final seed = _buildDemoReviews(users);
      await prefs.setString(_reviewsKey, jsonEncode(seed.map((e) => e.toJson()).toList()));
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
          MultiCriteriaReview.fromJson(Map<String, dynamic>.from(e as Map))
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAllMultiReviews(List<MultiCriteriaReview> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_multiReviewsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<bool> hasSubmittedReview({required String requestId, required String reviewerId}) async {
    final all = await _getAllMultiReviews();
    return all.any((r) => r.requestId == requestId && r.reviewerId == reviewerId);
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
    final nextId = (all.fold<int>(0, (p, e) => (int.tryParse(e.id) ?? 0) > p ? (int.tryParse(e.id) ?? 0) : p) + 1).toString();
    final review = MultiCriteriaReview(
      id: nextId,
      requestId: requestId,
      itemId: itemId,
      reviewerId: reviewerId,
      reviewedUserId: reviewedUserId,
      direction: direction,
      criteria: criteria,
      createdAt: DateTime.now(),
    );
    all.add(review);
    await _saveAllMultiReviews(all);

    // Incrementally update the reviewed user's rating stats
    try {
      final users = await getUsers();
      final idx = users.indexWhere((u) => u.id == reviewedUserId);
      if (idx != -1) {
        final u = users[idx];
        final count = (u.reviewCount) + 1;
        final avg = ((u.avgRating * (u.reviewCount)) + review.average) / count;
        final updated = u.copyWith(avgRating: avg, reviewCount: count);
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_usersKey);
        if (raw != null) {
          final List<dynamic> list = jsonDecode(raw);
          for (int i = 0; i < list.length; i++) {
            final m = Map<String, dynamic>.from(list[i] as Map);
            if ((m['id']?.toString() ?? '') == reviewedUserId) {
              list[i] = updated.toJson();
              break;
            }
          }
          await prefs.setString(_usersKey, jsonEncode(list));
        }
      }
    } catch (_) {/* non-fatal */}

    return review;
  }

  static Future<List<MultiCriteriaReview>> getMultiReviewsForUser(String userId) async {
    final all = await _getAllMultiReviews();
    final filtered = all.where((e) => e.reviewedUserId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  static Future<List<MultiCriteriaReview>> getMultiReviewsForUserByItem(String userId, String itemId) async {
    final all = await _getAllMultiReviews();
    final filtered = all.where((e) => e.reviewedUserId == userId && e.itemId == itemId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  static Future<List<Review>> getReviewsForUser(String userId) async {
    final all = await _getAllReviews();
    final filtered = all.where((review) => review.reviewedUserId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  static Future<List<ReviewWithUser>> getReviewSummariesForUser(String userId) async {
    final classic = await getReviewsForUser(userId);
    final multi = await getMultiReviewsForUser(userId);
    final users = await getUsers();
    final byId = {for (final u in users) u.id: u};

    // Convert multi-criteria into flat Review objects for existing UIs
    List<Review> folded = List<Review>.from(classic);
    for (final m in multi) {
      final combinedText = m.criteria
          .where((c) => (c.note?.trim().isNotEmpty ?? false))
          .map((c) => _criterionLabel(c.key) + ': ' + c.note!.trim())
          .join(' \u00B7 ');
      folded.add(Review(
        id: 'mc_${m.id}',
        reviewerId: m.reviewerId,
        reviewedUserId: m.reviewedUserId,
        rating: m.average,
        comment: combinedText,
        createdAt: m.createdAt,
      ));
    }
    folded.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return [
      for (final r in folded)
        ReviewWithUser(review: r, reviewer: byId[r.reviewerId])
    ];
  }

  static String _criterionLabel(String key) {
    switch (key) {
      case 'communication':
        return 'Kommunikation';
      case 'condition_dropoff':
        return 'Zustand bei Abgabe';
      case 'condition_return':
        return 'Zustand bei Rückgabe';
      case 'description_accuracy':
        return 'Beschreibungstreue';
      case 'reliability':
        return 'Zuverlässigkeit';
      case 'value_for_money':
        return 'Preis‑Leistung';
      case 'process':
        return 'Abgabe & Rückgabe';
      default:
        return key;
    }
  }

  // Quick helpers
  static Future<Item?> getItemById(String id) async {
    final items = await getItems();
    try { return items.firstWhere((e) => e.id.toString() == id.toString()); } catch (_) { return null; }
  }

  static Future<User?> getUserById(String id) async {
    final users = await getUsers();
    try { return users.firstWhere((e) => e.id.toString() == id.toString()); } catch (_) { return null; }
  }

  // Rental requests storage (demo, persisted locally)
  static Future<List<RentalRequest>> _getAllRentalRequests() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString(_rentalRequestsKey);
    if (raw == null) {
      // Do not seed demo requests anymore. Persist an empty list by default.
      await prefs.setString(_rentalRequestsKey, jsonEncode(<Map<String, dynamic>>[]));
      raw = prefs.getString(_rentalRequestsKey);
    }
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => RentalRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAllRentalRequests(List<RentalRequest> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rentalRequestsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<List<RentalRequest>> getRentalRequestsForOwner(String ownerId, {String? status}) async {
    await _sweepExpressTimeouts();
    final all = await _getAllRentalRequests();
    final filtered = all.where((r) => r.ownerId == ownerId && (status == null || r.status == status)).toList();
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
    final pending = await getRentalRequestsForOwner(ownerId); // include all statuses
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
      await prefs.setString(_requestsLastSeenKey, jsonEncode({ownerId: nowMarker.toIso8601String()}));
    }
  }

  /// Marks a specific rental request as read by a user (owner or renter).
  /// Used to track which individual requests have been viewed.
  static Future<void> markRequestAsRead({required String userId, required String requestId}) async {
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
  static Future<bool> isRequestRead({required String userId, required String requestId}) async {
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
    try { return all.firstWhere((e) => e.id == id); } catch (_) { return null; }
  }

  static Future<RentalRequest> addRentalRequest(RentalRequest req) async {
    final all = await _getAllRentalRequests();
    final nextId = (all.fold<int>(0, (p, e) => (int.tryParse(e.id) ?? 0) > p ? (int.tryParse(e.id) ?? 0) : p) + 1).toString();
    final now = DateTime.now();
    // Snapshot current delivery selection for this item so booking details remain accurate
    Map<String, dynamic>? deliverySel;
    try { deliverySel = await getSavedDeliverySelection(req.itemId); } catch (_) { deliverySel = null; }
    final bool ownerDelivers = (deliverySel?['hinweg'] == true);
    final bool ownerPicksUp = (deliverySel?['rueckweg'] == true);
    // Compute renter-facing quoted total and subtitle exactly as seen at booking time
    double? quotedTotal;
    String? quotedSub;
    try {
      final item = await getItemById(req.itemId);
      if (item != null) {
        final breakdown = priceBreakdownForRequest(item: item, req: req, deliverySel: deliverySel);
        final bool expressSelectedTransient = (deliverySel?['express'] == true);
        final bool expressAccepted = req.expressRequested && (req.expressStatus == 'accepted');
        final bool priority = expressSelectedTransient || req.expressRequested || expressAccepted;
        quotedTotal = breakdown.totalRenter;
        quotedSub = TotalSubtitleHelper.build(delivery: ownerDelivers, pickup: ownerPicksUp, priority: priority);
      }
    } catch (e) {
      debugPrint('[DataService] addRentalRequest: failed to compute quoted total: ' + e.toString());
    }
    final toStore = RentalRequest(
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
      deliveryAddressLine: (deliverySel?['addressLine'] as String?),
      deliveryCity: (deliverySel?['city'] as String?),
      deliveryLat: (deliverySel?['lat'] as num?)?.toDouble(),
      deliveryLng: (deliverySel?['lng'] as num?)?.toDouble(),
      createdAt: now,
      expressRequestedAt: req.expressRequested ? now : null,
      expressConfirmedAt: null,
      quotedTotalRenter: quotedTotal,
      quotedSubtitle: quotedSub,
    );
    all.add(toStore);
    await _saveAllRentalRequests(all);
    debugPrint('[DataService] addRentalRequest stored id='+nextId+
        ' ownerDeliversAtDropoffChosen='+ownerDelivers.toString()+
        ' ownerPicksUpAtReturnChosen='+ownerPicksUp.toString()+
        ' expressRequested='+toStore.expressRequested.toString());
    // Start 30-minute express confirmation timer if applicable (runtime only)
    _scheduleExpressTimerIfNeeded(toStore);
    return toStore;
  }

  static Future<void> updateRentalRequestStatus({required String requestId, required String status}) async {
    final all = await _getAllRentalRequests();
    bool mutated = false;
    RentalRequest? updatedRequest;
    for (int i = 0; i < all.length; i++) {
      if (all[i].id == requestId) {
        all[i] = all[i].copyWith(status: status);
        updatedRequest = all[i];
        mutated = true; break;
      }
    }
    if (mutated) {
      await _saveAllRentalRequests(all);
      
      // Wenn die Anfrage angenommen wurde, erstelle einen Message Thread
      if (status == 'accepted' && updatedRequest != null) {
        try {
          await _createMessageThreadForRequest(updatedRequest);
        } catch (e) {
          debugPrint('[DataService] Failed to create message thread: $e');
        }
      }
    }
  }

  /// Update status and optionally set the actor who cancelled.
  /// If [status] is 'cancelled' and [cancelledBy] is provided, we persist it.
  static Future<void> updateRentalRequestStatusWithActor({required String requestId, required String status, String? cancelledBy}) async {
    final all = await _getAllRentalRequests();
    bool mutated = false;
    for (int i = 0; i < all.length; i++) {
      if (all[i].id == requestId) {
        all[i] = all[i].copyWith(status: status, cancelledBy: (status == 'cancelled') ? (cancelledBy ?? all[i].cancelledBy) : all[i].cancelledBy);
        mutated = true; break;
      }
    }
    if (mutated) await _saveAllRentalRequests(all);
  }

  // Update times and express choice for an existing request (edit flow)
  static Future<void> updateRentalRequestTimes({required String requestId, required DateTime start, required DateTime end, bool? expressRequested}) async {
    final all = await _getAllRentalRequests();
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
          try { _expressTimers[requestId]?.cancel(); _expressTimers.remove(requestId); } catch (_) {}
        }
        break;
      }
    }
    if (mutated) await _saveAllRentalRequests(all);
  }

  // Update express confirmation status for a request
  static Future<void> updateRentalRequestExpress({required String requestId, required bool accept}) async {
    final all = await _getAllRentalRequests();
    bool mutated = false;
    for (int i = 0; i < all.length; i++) {
      if (all[i].id == requestId) {
        final newStatus = accept ? 'accepted' : 'declined';
        all[i] = all[i].copyWith(expressStatus: newStatus, expressConfirmedAt: accept ? DateTime.now() : all[i].expressConfirmedAt);
        mutated = true;
        // If accepted/declined, cancel any scheduled timer
        try { _expressTimers[requestId]?.cancel(); _expressTimers.remove(requestId); } catch (_) {}
        break;
      }
    }
    if (mutated) await _saveAllRentalRequests(all);
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
          debugPrint('[DataService] Express timeout -> auto-switch to Standard for request ${r.id}');
          try { await addTimelineEvent(requestId: r.id, type: 'express_timeout_refund', note: 'Priorität abgelaufen; auf Standard umgestellt'); } catch (_) {}
          // Cancel any pending timer for safety
          try { _expressTimers[r.id]?.cancel(); _expressTimers.remove(r.id); } catch (_) {}
        } else {
          // Still pending; ensure a timer is scheduled for runtime
          _scheduleExpressTimerIfNeeded(r);
        }
      }
      if (mutated) await _saveAllRentalRequests(all);
    } catch (e) {
      debugPrint('[DataService] sweepExpressTimeouts failed: ' + e.toString());
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
  static Future<List<RentalRequest>> getRentalRequestsForRenter(String renterId, {String? status}) async {
    await _sweepExpressTimeouts();
    final all = await _getAllRentalRequests();
    final filtered = all.where((r) => r.renterId == renterId && (status == null || r.status == status)).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  // Timeline events (simple local storage)
  static Future<void> addTimelineEvent({required String requestId, required String type, String? note}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timelineEventsKey);
    List<dynamic> list = raw != null && raw.isNotEmpty ? (jsonDecode(raw) as List) : [];
    list.add({
      'requestId': requestId,
      'type': type,
      'note': note ?? '',
      'ts': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_timelineEventsKey, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> getTimelineForRequest(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timelineEventsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List list = jsonDecode(raw);
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) => e['requestId'] == requestId).toList();
    } catch (_) {
      return [];
    }
  }

  // Notifications (demo)
  static Future<void> addNotification({required String title, required String body}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notificationsKey);
    List<dynamic> list = raw != null && raw.isNotEmpty ? (jsonDecode(raw) as List) : [];
    list.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'body': body,
      'ts': DateTime.now().toIso8601String(),
      'read': false,
    });
    await prefs.setString(_notificationsKey, jsonEncode(list));
  }

  // ===== Ride compensation lightweight state =====
  /// Persist a decision for ride compensation per request and segment ('dropoff' | 'return').
  static Future<void> setRideCompensationDecision({required String requestId, required String segment, required bool grant, String? reason}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_rideCompKey);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        try { map = jsonDecode(raw) as Map<String, dynamic>; } catch (_) { map = {}; }
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
      debugPrint('[DataService] setRideCompensationDecision failed: ' + e.toString());
    }
  }

  /// Returns the decision if present. If [consume] is true, removes it after reading.
  static Future<bool?> getRideCompensationDecision({required String requestId, required String segment, bool consume = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_rideCompKey);
      if (raw == null || raw.isEmpty) return null;
      Map<String, dynamic> map;
      try { map = jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
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
      debugPrint('[DataService] getRideCompensationDecision failed: ' + e.toString());
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
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_reviewRemindersKey);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        try { list = jsonDecode(raw); } catch (_) { list = []; }
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
      debugPrint('[DataService] scheduleReviewReminder failed: ' + e.toString());
    }
  }

  static Future<Map<String, dynamic>?> takeDueReviewReminder({required String reviewerId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_reviewRemindersKey);
      if (raw == null || raw.isEmpty) return null;
      List list;
      try { list = jsonDecode(raw); } catch (_) { return null; }
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
            idx = i; hit = map; break;
          }
        } catch (_) {/* skip */}
      }
      if (idx >= 0 && hit != null) {
        list.removeAt(idx);
        await prefs.setString(_reviewRemindersKey, jsonEncode(list));
        return hit;
      }
      return null;
    } catch (e) {
      debugPrint('[DataService] takeDueReviewReminder failed: ' + e.toString());
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
        try { list = jsonDecode(raw); } catch (_) { list = []; }
      }
      // Add a new entry with a new id and new dueAt
      final dueStr = (reminder['dueAt'] ?? '').toString();
      final oldDue = DateTime.tryParse(dueStr) ?? DateTime.now();
      final newDue = DateTime.now().isAfter(oldDue) ? DateTime.now().add(by) : oldDue.add(by);
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
      debugPrint('[DataService] postponeReviewReminder failed: ' + e.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notificationsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List list = jsonDecode(raw);
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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
          if (ts.year == now.year && ts.month == now.month && ts.day == now.day) {
            count++;
          }
        } catch (_) {/* skip corrupted entry */}
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> addFeedback({required String userId, required String text}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_feedbacksKey);
    List<dynamic> list = [];
    if (raw != null && raw.isNotEmpty) {
      try { list = jsonDecode(raw); } catch (_) { list = []; }
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
  static String policyName([String? _ignored]) => 'Einheitliche Stornobedingung';

  /// Returns the calendar-date-only representation of a DateTime.
  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Compute the deadline date until which cancellation is fully free (100%) under the
  /// unified policy. We operate on calendar days only (no times).
  /// Rule interpretation (unified):
  /// - 100%: Bis mindestens 2 Kalendertage vor Mietbeginn.
  /// - 50%: Am Kalendertag vor Mietbeginn.
  /// - 0%: Ab Mietbeginn oder bei Nicht‑Erscheinen.
  static DateTime? freeCancellationUntil({
    required String policy,
    required DateTime start,
    required DateTime createdAt,
  }) {
    // Unified: Free until the end of the day two days before the start date.
    final s = _dateOnly(start);
    final freeUntil = s.subtract(const Duration(days: 2));
    return freeUntil;
  }

  /// Returns the refund ratio (0.0..1.0) applied to the RENTAL PRICE under the unified policy,
  /// based solely on calendar days between [cancelAt] and [start].
  /// Master rule is applied by callers to all other fees using the same ratio.
  static double refundRatio({
    required String policy,
    required DateTime start,
    required DateTime cancelAt,
    DateTime? createdAt,
  }) {
    final startD = _dateOnly(start);
    final cancelD = _dateOnly(cancelAt);
    final daysBefore = startD.difference(cancelD).inDays;
    if (daysBefore >= 2) return 1.0; // Early: ≥ 2 days before start
    if (daysBefore == 1) return 0.5; // Late: on the day before start
    return 0.0; // Start day or after: no refund
  }

  /// Deletes ALL locally stored rentals and bookings (rental requests), including
  /// related timelines, reminders, last-seen markers and transient handover caches.
  /// Also clears saved availability/delivery selections to avoid stale UI state.
  static Future<void> clearAllRentalsAndBookings() async {
    try {
      // Stop any express timers running in this session
      try {
        for (final t in _expressTimers.values) { t.cancel(); }
        _expressTimers.clear();
      } catch (_) {/* ignore */}

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rentalRequestsKey);
      await prefs.remove(_timelineEventsKey);
      await prefs.remove(_reviewRemindersKey);
      await prefs.remove(_requestsLastSeenKey);
      await prefs.remove(_handoverFailCountsKey);
      await prefs.remove(_handoverBannersKey);
      await prefs.remove(_bookingSelectionsKey);
      debugPrint('[DataService] Cleared rentals/bookings and related local caches');
    } catch (e) {
      debugPrint('[DataService] clearAllRentalsAndBookings failed: ' + e.toString());
    }
  }

  // ===== Message Threads =====
  /// Erstellt automatisch einen Message Thread wenn eine Anfrage angenommen wird
  static Future<void> _createMessageThreadForRequest(RentalRequest request) async {
    try {
      final item = await getItemById(request.itemId);
      if (item == null) return;

      final renter = await getUserById(request.renterId);
      final owner = await getUserById(request.ownerId);
      if (renter == null || owner == null) return;

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_messageThreadsKey);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        try { list = jsonDecode(raw); } catch (_) { list = []; }
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
        text: 'Starte einen Chat mit ${owner.displayName}, um eine Uhrzeit für Übergabe und Rückgabe zu vereinbaren.',
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
        messages: [initialMessage],
        createdAt: now,
        lastMessageAt: now,
      );

      list.add(thread.toJson());
      await prefs.setString(_messageThreadsKey, jsonEncode(list));
      debugPrint('[DataService] Created message thread for request ${request.id}');
    } catch (e) {
      debugPrint('[DataService] _createMessageThreadForRequest error: $e');
    }
  }

  /// Gibt alle Message Threads für einen User zurück
  static Future<List<MessageThread>> getMessageThreadsForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_messageThreadsKey);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> list = jsonDecode(raw);
      final threads = <MessageThread>[];

      for (final e in list) {
        try {
          final thread = MessageThread.fromJson(Map<String, dynamic>.from(e as Map));
          // Nur Threads zeigen, die den User betreffen
          if (thread.user1Id == userId || thread.user2Id == userId) {
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

  /// Findet einen Thread anhand der Thread-ID
  static Future<MessageThread?> getMessageThreadById(String threadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_messageThreadsKey);
      if (raw == null || raw.isEmpty) return null;

      final List<dynamic> list = jsonDecode(raw);
      for (final e in list) {
        try {
          final thread = MessageThread.fromJson(Map<String, dynamic>.from(e as Map));
          if (thread.id == threadId) return thread;
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
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_messageThreadsKey);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> list = jsonDecode(raw);
      bool mutated = false;

      for (int i = 0; i < list.length; i++) {
        try {
          final map = Map<String, dynamic>.from(list[i] as Map);
          if ((map['id']?.toString() ?? '') == threadId) {
            final thread = MessageThread.fromJson(map);
            final now = DateTime.now();
            final newMessage = Message(
              id: 'msg_${now.microsecondsSinceEpoch}',
              senderId: senderId,
              text: text,
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
        await prefs.setString(_messageThreadsKey, jsonEncode(list));
      }
    } catch (e) {
      debugPrint('[DataService] addMessageToThread error: $e');
    }
  }

  /// Markiert alle Nachrichten in einem Thread als gelesen für einen User
  static Future<void> markThreadMessagesAsRead({
    required String threadId,
    required String userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_messageThreadsKey);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> list = jsonDecode(raw);
      bool mutated = false;

      for (int i = 0; i < list.length; i++) {
        try {
          final map = Map<String, dynamic>.from(list[i] as Map);
          if ((map['id']?.toString() ?? '') == threadId) {
            final thread = MessageThread.fromJson(map);
            final updatedMessages = thread.messages.map((msg) {
              if (msg.senderId != userId && !msg.isRead) {
                return msg.copyWith(isRead: true);
              }
              return msg;
            }).toList();

            final updatedThread = thread.copyWith(messages: updatedMessages);
            list[i] = updatedThread.toJson();
            mutated = true;
            break;
          }
        } catch (_) {}
      }

      if (mutated) {
        await prefs.setString(_messageThreadsKey, jsonEncode(list));
      }
    } catch (e) {
      debugPrint('[DataService] markThreadMessagesAsRead error: $e');
    }
  }
}
