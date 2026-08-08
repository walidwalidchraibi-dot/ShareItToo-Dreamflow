import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'backend_config.dart';
import 'backend_http.dart';

class BackendRepository {
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
  }) async {
    var token = await _token();
    try {
      return await BackendHttp.requestJson(
        method: method,
        path: path,
        accessToken: token,
        body: body,
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
      path: '/listings',
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

  static Future<List<Map<String, dynamic>>> getMessageThreads() async {
    final response = await _authorized(
      method: 'GET',
      path: '/message-threads',
    );
    return _maps(response['threads']);
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
}
