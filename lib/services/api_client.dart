import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiClient {
  const ApiClient({String? baseUrl}) : _baseUrl = baseUrl;

  final String? _baseUrl;

  String get baseUrl => (_baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/$'), '');

  Uri endpoint(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized');
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            endpoint(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body ?? const <String, dynamic>{}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw Exception(
        'The request took too long. Please check your connection and try again.',
      );
    } on http.ClientException {
      throw Exception(
        'Unable to connect to AgriN services. Please check your internet connection and try again.',
      );
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } catch (_) {
      throw Exception(
        'API returned an invalid response (${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        json['detail']?.toString() ?? 'API request failed (${response.statusCode}).',
      );
    }

    return json;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final base = endpoint(path);
    final uri = queryParameters == null || queryParameters.isEmpty
        ? base
        : base.replace(queryParameters: queryParameters);

    late final http.Response response;
    try {
      response = await http.get(uri).timeout(timeout);
    } on TimeoutException {
      throw Exception(
        'The request took too long. Please check your connection and try again.',
      );
    } on http.ClientException {
      throw Exception(
        'Unable to connect to AgriN services. Please check your internet connection and try again.',
      );
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } catch (_) {
      throw Exception(
        'API returned an invalid response (${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        json['detail']?.toString() ?? 'API request failed (${response.statusCode}).',
      );
    }

    return json;
  }
}
