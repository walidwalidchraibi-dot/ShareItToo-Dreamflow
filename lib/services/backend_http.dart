import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend_config.dart';

class BackendException implements Exception {
  final int statusCode;
  final String code;
  final Object? details;

  const BackendException(this.statusCode, this.code, {this.details});

  @override
  String toString() => 'BackendException($statusCode, $code)';
}

class BackendHttp {
  static Future<Map<String, dynamic>> requestJson({
    required String method,
    required String path,
    String? accessToken,
    Object? body,
    Map<String, String> additionalHeaders = const <String, String>{},
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
      ...additionalHeaders,
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final uri = BackendConfig.uri(path);

    late final http.Response response;
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: headers).timeout(timeout);
        break;
      case 'POST':
        response = await http
            .post(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
        break;
      case 'PUT':
        response = await http
            .put(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
        break;
      case 'PATCH':
        response = await http
            .patch(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers).timeout(timeout);
        break;
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
    }

    Map<String, dynamic> decoded = <String, dynamic>{};
    if (response.body.trim().isNotEmpty) {
      try {
        final value = jsonDecode(response.body);
        if (value is Map) decoded = Map<String, dynamic>.from(value);
      } catch (_) {
        throw BackendException(response.statusCode, 'invalid_server_response');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendException(
        response.statusCode,
        decoded['error']?.toString() ?? 'request_failed',
        details: decoded['details'],
      );
    }
    return decoded;
  }
}
