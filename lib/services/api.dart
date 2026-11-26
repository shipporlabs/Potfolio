import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Thin client for the Potfolio Cloudflare Worker.
class WorkerApi {
  final http.Client _c;
  WorkerApi([http.Client? c]) : _c = c ?? http.Client();

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('${AppConfig.workerUrl}$path').replace(queryParameters: q);

  Map<String, String> _h(String? token) => {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, String>? query, String? token}) async {
    final r = await _c.get(_u(path, query), headers: _h(token)).timeout(const Duration(seconds: 25));
    return _decode(r);
  }

  Future<dynamic> post(String path, Object body, {String? token}) async {
    final r = await _c.post(_u(path), headers: _h(token), body: jsonEncode(body)).timeout(const Duration(seconds: 40));
    return _decode(r);
  }

  dynamic _decode(http.Response r) {
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 400) {
      final msg = body is Map ? (body['error'] ?? body['message'] ?? 'Request failed').toString() : 'Request failed';
      throw ApiException(msg, r.statusCode);
    }
    return body;
  }
}
