import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'backend_config.dart';
import 'backend_http.dart';

class BackendRepository {
  static String? _staffStepUpToken;

  static Future<String> _token() async {
    final token = await AuthService.accessToken();
    if (token == null || token.isEmpty) {
      throw const BackendException(401, 'authentication_required');
    }
    return token;
  }

  static Future<Map<String, dynamic>> _authorized({
    required String method,
    required String path,
    Object? body,
    Map<String, String> additionalHeaders = const <String, String>{},
  }) async {
    var token = await _token();
    try {
      return await BackendHttp.requestJson(
        method: method,
        path: path,
        accessToken: token,
        body: body,
        additionalHeaders: additionalHeaders,
      );
    } on BackendException catch (error) {
      if (error.statusCode != 401) rethrow;
      token = await AuthService.refreshAccessToken() ?? '';
      if (token.isEmpty) rethrow;
      return BackendHttp.requestJson(
        method: method,
        path: path,
        accessToken: token,
        body: body,
        additionalHeaders: additionalHeaders,
      );
    }
  }

  static List<Map<String, dynamic>> _maps(Object? value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  static Future<Map<String, dynamic>> getCurrentProfile() async {
    final response = await _authorized(method: 'GET', path: '/auth/me');
    return Map<String, dynamic>.from(response['user'] as Map);
  }

  static Future<List<Map<String, dynamic>>> getAuthSessions() async {
    final response = await _authorized(method: 'GET', path: '/auth/sessions');
    return _maps(response['sessions']);
  }

  static Future<void> revokeAuthSession(String sessionId) async {
    await _authorized(
      method: 'DELETE',
      path: '/auth/sessions/${Uri.encodeComponent(sessionId)}',
    );
  }

  static Future<void> logoutAllSessions() async {
    await _authorized(method: 'POST', path: '/auth/logout-all');
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _authorized(
      method: 'POST',
      path: '/auth/password/change',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  static Future<Map<String, dynamic>> accountDeletionPreflight() async {
    return _authorized(method: 'GET', path: '/account/deletion-preflight');
  }

  static Future<Map<String, dynamic>> exportAccountData() async {
    return _authorized(method: 'GET', path: '/account/export');
  }

  static Future<void> deleteAccount({required String currentPassword}) async {
    await _authorized(
      method: 'POST',
      path: '/account/deletion',
      body: {'currentPassword': currentPassword},
    );
  }

  static Future<Map<String, dynamic>> registerPushDevice({
    required String token,
    required String platform,
    String? locale,
  }) async {
    return _authorized(
      method: 'PUT',
      path: '/auth/devices/push',
      body: {'token': token, 'platform': platform, 'locale': locale},
    );
  }

  static Future<void> deletePushDevice(String id) async {
    await _authorized(
      method: 'DELETE',
      path: '/auth/devices/push/${Uri.encodeComponent(id)}',
    );
  }

  static Future<Map<String, dynamic>> updateCurrentProfile(
    Map<String, dynamic> profile,
  ) async {
    final response = await _authorized(
      method: 'PATCH',
      path: '/profile',
      body: {'profile': profile},
    );
    return Map<String, dynamic>.from(response['user'] as Map);
  }

  static Future<List<Map<String, dynamic>>> autocompleteAddresses({
    required String input,
    String language = 'de',
    String country = 'de',
  }) async {
    final query = Uri(queryParameters: {
      'input': input,
      'language': language,
      'country': country,
    }).query;
    final response = await _authorized(
      method: 'GET',
      path: '/maps/places/autocomplete?$query',
    );
    return _maps(response['suggestions']);
  }

  static Future<Map<String, dynamic>?> getAddressPlaceDetails({
    required String placeId,
    String language = 'de',
  }) async {
    final query = Uri(queryParameters: {'language': language}).query;
    final response = await _authorized(
      method: 'GET',
      path: '/maps/places/${Uri.encodeComponent(placeId)}?$query',
    );
    final place = response['place'];
    return place is Map ? Map<String, dynamic>.from(place) : null;
  }

  static Future<Map<String, dynamic>?> getPublicProfile(String userId) async {
    try {
      final response = await BackendHttp.requestJson(
        method: 'GET',
        path: '/profiles/${Uri.encodeComponent(userId)}',
      );
      return Map<String, dynamic>.from(response['user'] as Map);
    } on BackendException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getListings() async {
    final response = await BackendHttp.requestJson(
      method: 'GET',
      path: '/listings?sort=newest&limit=100',
    );
    final byId = <String, Map<String, dynamic>>{
      for (final listing in _maps(response['listings']))
        if ((listing['id']?.toString() ?? '').isNotEmpty)
          listing['id'].toString(): listing,
    };
    if (await AuthService.readSession() != null) {
      final mine = await _authorized(method: 'GET', path: '/listings/mine');
      for (final listing in _maps(mine['listings'])) {
        final id = listing['id']?.toString() ?? '';
        if (id.isNotEmpty) byId[id] = listing;
      }
    }
    return byId.values.toList();
  }

  static Future<List<Map<String, dynamic>>> searchListings({
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
    int offset = 0,
  }) async {
    final parameters = <String, String>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (categoryIds.isNotEmpty) 'categories': categoryIds.join(','),
      if (conditions.isNotEmpty) 'conditions': conditions.join(','),
      if (minPrice != null) 'minPrice': minPrice.toString(),
      if (maxPrice != null) 'maxPrice': maxPrice.toString(),
      if (latitude != null) 'lat': latitude.toString(),
      if (longitude != null) 'lng': longitude.toString(),
      if (radiusKm != null) 'radiusKm': radiusKm.toString(),
      'sort': sort,
      'limit': limit.clamp(1, 100).toString(),
      'offset': offset.clamp(0, 5000).toString(),
    };
    final encoded = Uri(queryParameters: parameters).query;
    final response = await BackendHttp.requestJson(
      method: 'GET',
      path: '/listings?$encoded',
    );
    return _maps(response['listings']);
  }

  static Future<Map<String, dynamic>> createListing(
    Map<String, dynamic> listing,
  ) async {
    final response = await _authorized(
      method: 'POST',
      path: '/listings',
      body: listing,
    );
    return Map<String, dynamic>.from(response['listing'] as Map);
  }

  static Future<Map<String, dynamic>> updateListing(
    Map<String, dynamic> listing,
  ) async {
    final id = listing['id']?.toString() ?? '';
    final response = await _authorized(
      method: 'PUT',
      path: '/listings/${Uri.encodeComponent(id)}',
      body: listing,
    );
    return Map<String, dynamic>.from(response['listing'] as Map);
  }

  static Future<Map<String, dynamic>> updateListingStatus({
    required String id,
    required String status,
  }) async {
    final response = await _authorized(
      method: 'PATCH',
      path: '/listings/${Uri.encodeComponent(id)}/status',
      body: {'status': status},
    );
    return Map<String, dynamic>.from(response['listing'] as Map);
  }

  static Future<void> deleteListing(String id) async {
    await _authorized(
      method: 'DELETE',
      path: '/listings/${Uri.encodeComponent(id)}',
    );
  }

  static Future<Map<String, dynamic>> getListingAvailability({
    required String listingId,
    required String fromDate,
    required String toDate,
  }) async {
    final query = Uri(
      queryParameters: <String, String>{'from': fromDate, 'to': toDate},
    ).query;
    final response = await BackendHttp.requestJson(
      method: 'GET',
      path: '/listings/${Uri.encodeComponent(listingId)}/availability?$query',
    );
    return Map<String, dynamic>.from(response['availability'] as Map);
  }

  static Future<bool> checkListingAvailability({
    required String listingId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await BackendHttp.requestJson(
        method: 'POST',
        path: '/listings/${Uri.encodeComponent(listingId)}/availability/check',
        body: {'startDate': startDate, 'endDate': endDate},
      );
      return response['available'] == true;
    } on BackendException catch (error) {
      if (error.statusCode == 409) return false;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> quoteBooking(
    Map<String, dynamic> booking,
  ) async {
    return _authorized(method: 'POST', path: '/bookings/quote', body: booking);
  }

  static Future<Map<String, dynamic>> createBooking(
    Map<String, dynamic> booking, {
    required String idempotencyKey,
  }) async {
    final response = await _authorized(
      method: 'POST',
      path: '/bookings',
      body: booking,
      additionalHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return Map<String, dynamic>.from(response['booking'] as Map);
  }

  static Future<Map<String, dynamic>> amendBooking(
    Map<String, dynamic> booking, {
    required String bookingId,
    required String idempotencyKey,
  }) async {
    final response = await _authorized(
      method: 'PATCH',
      path: '/bookings/${Uri.encodeComponent(bookingId)}',
      body: booking,
      additionalHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return Map<String, dynamic>.from(response['booking'] as Map);
  }

  static Future<Map<String, dynamic>> transitionBooking({
    required String bookingId,
    required String status,
    required String idempotencyKey,
    int? expectedRevision,
  }) async {
    final response = await _authorized(
      method: 'POST',
      path: '/bookings/${Uri.encodeComponent(bookingId)}/transitions',
      body: {
        'status': status,
        if (expectedRevision != null) 'expectedRevision': expectedRevision,
      },
      additionalHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return Map<String, dynamic>.from(response['booking'] as Map);
  }

  static Future<Map<String, dynamic>> getConnectStatus() async {
    final response = await _authorized(
      method: 'GET',
      path: '/payments/connect/status',
    );
    return Map<String, dynamic>.from(response['account'] as Map);
  }

  static Future<Map<String, dynamic>> startConnectOnboarding({
    required String idempotencyKey,
  }) async {
    return _authorized(
      method: 'POST',
      path: '/payments/connect/onboarding',
      body: const {'country': 'DE', 'currency': 'EUR'},
      additionalHeaders: {'Idempotency-Key': idempotencyKey},
    );
  }

  static Future<Map<String, dynamic>> getBookingPayment(
      String bookingId) async {
    return _authorized(
      method: 'GET',
      path: '/bookings/${Uri.encodeComponent(bookingId)}/payment',
    );
  }

  static Future<Map<String, dynamic>> createBookingCheckout({
    required String bookingId,
    required String idempotencyKey,
    bool depositConsent = false,
  }) async {
    return _authorized(
      method: 'POST',
      path: '/bookings/${Uri.encodeComponent(bookingId)}/payment/checkout',
      body: {'depositConsent': depositConsent},
      additionalHeaders: {'Idempotency-Key': idempotencyKey},
    );
  }

  static Future<Map<String, dynamic>> createDepositSetup({
    required String bookingId,
    required String consentVersion,
    required String idempotencyKey,
  }) async {
    return _authorized(
      method: 'POST',
      path: '/bookings/${Uri.encodeComponent(bookingId)}/deposit/setup',
      body: {
        'consentAccepted': true,
        'consentVersion': consentVersion,
      },
      additionalHeaders: {'Idempotency-Key': idempotencyKey},
    );
  }

  static Future<List<Map<String, dynamic>>> getRentalRequests() async {
    final response = await _authorized(
      method: 'GET',
      path: '/rental-requests',
    );
    return _maps(response['requests']);
  }

  static Future<List<Map<String, dynamic>>> syncRentalRequests(
    List<Map<String, dynamic>> requests,
  ) async {
    final response = await _authorized(
      method: 'PUT',
      path: '/rental-requests/sync',
      body: {'requests': requests},
    );
    return _maps(response['requests']);
  }

  static Future<List<Map<String, dynamic>>> getMessageThreads({
    bool includeArchived = false,
  }) async {
    final response = await _authorized(
      method: 'GET',
      path: '/message-threads${includeArchived ? '?includeArchived=true' : ''}',
    );
    return _maps(response['threads']);
  }

  static Future<Map<String, dynamic>> createOrGetBookingThread(
    String bookingId,
  ) async {
    final response = await _authorized(
      method: 'POST',
      path: '/message-threads/booking/${Uri.encodeComponent(bookingId)}',
    );
    return Map<String, dynamic>.from(response['thread'] as Map);
  }

  static Future<Map<String, dynamic>> sendThreadMessage({
    required String threadId,
    required String text,
    required String idempotencyKey,
    List<String> attachmentIds = const <String>[],
  }) async {
    final response = await _authorized(
      method: 'POST',
      path: '/message-threads/${Uri.encodeComponent(threadId)}/messages',
      body: {
        'text': text,
        if (attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
      },
      additionalHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return Map<String, dynamic>.from(response['message'] as Map);
  }

  static Future<void> markThreadRead(String threadId) async {
    await _authorized(
      method: 'POST',
      path: '/message-threads/${Uri.encodeComponent(threadId)}/read',
    );
  }

  static Future<void> setThreadArchived({
    required String threadId,
    required bool archived,
  }) async {
    await _authorized(
      method: 'PATCH',
      path: '/message-threads/${Uri.encodeComponent(threadId)}',
      body: {'archived': archived},
    );
  }

  static Future<List<String>> getBlockedUserIds() async {
    final response = await _authorized(method: 'GET', path: '/user-blocks');
    return _maps(response['blocks'])
        .map((entry) => entry['userId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  static Future<void> blockUser(String userId) async {
    await _authorized(
      method: 'PUT',
      path: '/user-blocks/${Uri.encodeComponent(userId)}',
      body: {'reasonCode': 'user_request'},
    );
  }

  static Future<void> unblockUser(String userId) async {
    await _authorized(
      method: 'DELETE',
      path: '/user-blocks/${Uri.encodeComponent(userId)}',
    );
  }

  static Future<Map<String, dynamic>> createReport({
    required String targetType,
    required String targetId,
    required String reasonCode,
    String details = '',
    String? reference,
    List<String> evidenceUploadIds = const <String>[],
  }) async {
    final response = await _authorized(
      method: 'POST',
      path: '/reports',
      body: {
        'targetType': targetType,
        'targetId': targetId,
        'reasonCode': reasonCode,
        if (details.trim().isNotEmpty) 'details': details.trim(),
        if ((reference ?? '').trim().isNotEmpty) 'reference': reference!.trim(),
        if (evidenceUploadIds.isNotEmpty)
          'evidenceUploadIds': evidenceUploadIds,
      },
      additionalHeaders: {
        'Idempotency-Key': 'report_${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    return Map<String, dynamic>.from(response['report'] as Map);
  }

  static Future<List<Map<String, dynamic>>> getMyReports() async {
    final response = await _authorized(method: 'GET', path: '/reports/mine');
    return _maps(response['reports']);
  }

  static Future<Map<String, dynamic>> createBookingReview({
    required String bookingId,
    required String direction,
    required List<Map<String, dynamic>> criteria,
  }) async {
    final response = await _authorized(
      method: 'POST',
      path: '/bookings/${Uri.encodeComponent(bookingId)}/reviews',
      body: {'direction': direction, 'criteria': criteria},
    );
    return Map<String, dynamic>.from(response['review'] as Map);
  }

  static Future<List<Map<String, dynamic>>> getUserReviews(
    String userId,
  ) async {
    final response = await BackendHttp.requestJson(
      method: 'GET',
      path: '/users/${Uri.encodeComponent(userId)}/reviews',
    );
    return _maps(response['reviews']);
  }

  static Future<void> elevateStaff(String currentPassword) async {
    final response = await _authorized(
      method: 'POST',
      path: '/admin/step-up',
      body: {'currentPassword': currentPassword},
    );
    final elevation = Map<String, dynamic>.from(response['elevation'] as Map);
    final token = elevation['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const BackendException(500, 'invalid_staff_elevation');
    }
    _staffStepUpToken = token;
  }

  static void clearStaffElevation() => _staffStepUpToken = null;

  static Future<Map<String, dynamic>> _staff({
    required String method,
    required String path,
    Object? body,
    String? idempotencyKey,
  }) async {
    final token = _staffStepUpToken;
    if (token == null || token.isEmpty) {
      throw const BackendException(401, 'staff_step_up_required');
    }
    try {
      return await _authorized(
        method: method,
        path: path,
        body: body,
        additionalHeaders: {
          'X-Admin-Step-Up': token,
          if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
        },
      );
    } on BackendException catch (error) {
      if (error.statusCode == 401) _staffStepUpToken = null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getStaffOverview() async {
    final response = await _staff(method: 'GET', path: '/admin/overview');
    return Map<String, dynamic>.from(response['overview'] as Map);
  }

  static Future<List<Map<String, dynamic>>> getStaffReports() async {
    final response = await _staff(method: 'GET', path: '/admin/reports');
    return _maps(response['reports']);
  }

  static Future<Map<String, dynamic>> getStaffReport(String reportId) async {
    final response = await _staff(
      method: 'GET',
      path: '/admin/reports/${Uri.encodeComponent(reportId)}',
    );
    return Map<String, dynamic>.from(response['report'] as Map);
  }

  static Future<Map<String, dynamic>> updateStaffReport({
    required String reportId,
    required Map<String, dynamic> update,
  }) async {
    final response = await _staff(
      method: 'PATCH',
      path: '/admin/reports/${Uri.encodeComponent(reportId)}',
      body: update,
      idempotencyKey: 'report_update_${DateTime.now().microsecondsSinceEpoch}',
    );
    return Map<String, dynamic>.from(response['report'] as Map);
  }

  static Future<List<Map<String, dynamic>>> getStaffUsers() async {
    final response = await _staff(method: 'GET', path: '/admin/users');
    return _maps(response['users']);
  }

  static Future<List<Map<String, dynamic>>> getStaffListings() async {
    final response = await _staff(method: 'GET', path: '/admin/listings');
    return _maps(response['listings']);
  }

  static Future<List<Map<String, dynamic>>> getStaffBookings() async {
    final response = await _staff(method: 'GET', path: '/admin/bookings');
    return _maps(response['bookings']);
  }

  static Future<List<Map<String, dynamic>>> getStaffPayments() async {
    final response = await _staff(method: 'GET', path: '/admin/payments');
    return _maps(response['payments']);
  }

  static Future<List<Map<String, dynamic>>> getStaffAudit() async {
    final response = await _staff(
      method: 'GET',
      path: '/admin/audit?limit=200',
    );
    return _maps(response['audit']);
  }

  static Future<void> suspendUser({
    required String userId,
    required String scope,
    required String reasonCode,
    String? reportId,
    String? note,
  }) async {
    await _staff(
      method: 'POST',
      path: '/admin/users/${Uri.encodeComponent(userId)}/suspensions',
      body: {
        'scope': scope,
        'reasonCode': reasonCode,
        if (reportId != null) 'reportId': reportId,
        if ((note ?? '').isNotEmpty) 'note': note,
      },
      idempotencyKey: 'user_suspend_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  static Future<void> moderateListing({
    required String listingId,
    required String status,
    required String reasonCode,
    String? reportId,
    String? note,
  }) async {
    await _staff(
      method: 'PATCH',
      path: '/admin/listings/${Uri.encodeComponent(listingId)}/moderation',
      body: {
        'status': status,
        'reasonCode': reasonCode,
        if (reportId != null) 'reportId': reportId,
        if ((note ?? '').isNotEmpty) 'note': note,
      },
      idempotencyKey:
          'listing_moderation_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _authorized(
      method: 'GET',
      path: '/notifications?limit=100',
    );
    return _maps(response['notifications']);
  }

  static Future<void> updateNotification({
    required String id,
    bool? read,
    bool? archived,
  }) async {
    await _authorized(
      method: 'PATCH',
      path: '/notifications/${Uri.encodeComponent(id)}',
      body: {
        if (read != null) 'read': read,
        if (archived != null) 'archived': archived,
      },
    );
  }

  static Future<void> markAllNotificationsRead() async {
    await _authorized(method: 'POST', path: '/notifications/read-all');
  }

  static Future<List<Map<String, dynamic>>> syncMessageThreads(
    List<Map<String, dynamic>> threads,
  ) async {
    final response = await _authorized(
      method: 'PUT',
      path: '/message-threads/sync',
      body: {'threads': threads},
    );
    return _maps(response['threads']);
  }

  static Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    var token = await _token();
    Future<http.StreamedResponse> send(String accessToken) {
      final request = http.MultipartRequest(
        'POST',
        BackendConfig.uri('/uploads'),
      )
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
          ),
        );
      return request.send().timeout(const Duration(seconds: 45));
    }

    var response = await send(token);
    if (response.statusCode == 401) {
      token = await AuthService.refreshAccessToken() ?? '';
      if (token.isNotEmpty) response = await send(token);
    }
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendException(response.statusCode, 'upload_failed');
    }
    final value = jsonDecode(body);
    if (value is! Map) {
      throw const BackendException(500, 'invalid_server_response');
    }
    final decoded = Map<String, dynamic>.from(value);
    final url = decoded['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw const BackendException(500, 'invalid_upload_response');
    }
    return url;
  }

  static Future<Map<String, dynamic>> uploadMessageAttachment({
    required Uint8List bytes,
    required String filename,
    required String threadId,
  }) async {
    var token = await _token();
    Future<http.StreamedResponse> send(String accessToken) {
      final request = http.MultipartRequest(
        'POST',
        BackendConfig.uri('/uploads'),
      )
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..fields['purpose'] = 'message_attachment'
        ..fields['threadId'] = threadId
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );
      return request.send().timeout(const Duration(seconds: 45));
    }

    var response = await send(token);
    if (response.statusCode == 401) {
      token = await AuthService.refreshAccessToken() ?? '';
      if (token.isNotEmpty) response = await send(token);
    }
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendException(response.statusCode, 'attachment_upload_failed');
    }
    final value = jsonDecode(body);
    if (value is! Map) {
      throw const BackendException(500, 'invalid_server_response');
    }
    final decoded = Map<String, dynamic>.from(value);
    if ((decoded['id']?.toString() ?? '').isEmpty) {
      throw const BackendException(500, 'invalid_upload_response');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> uploadReportEvidence({
    required Uint8List bytes,
    required String filename,
  }) async {
    var token = await _token();
    Future<http.StreamedResponse> send(String accessToken) {
      final request = http.MultipartRequest(
          'POST', BackendConfig.uri('/uploads'))
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..fields['purpose'] = 'report_evidence'
        ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename));
      return request.send().timeout(const Duration(seconds: 45));
    }

    var response = await send(token);
    if (response.statusCode == 401) {
      token = await AuthService.refreshAccessToken() ?? '';
      if (token.isNotEmpty) response = await send(token);
    }
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendException(response.statusCode, 'evidence_upload_failed');
    }
    final value = jsonDecode(body);
    if (value is! Map || (value['id']?.toString() ?? '').isEmpty) {
      throw const BackendException(500, 'invalid_upload_response');
    }
    return Map<String, dynamic>.from(value);
  }
}
