import 'dart:convert';
import 'package:http/http.dart' as http;

class TabdealApiException implements Exception {
  final int statusCode;
  final String message;
  const TabdealApiException(this.statusCode, this.message);
  @override
  String toString() => 'TabdealApiException($statusCode): $message';
}

/// Public Tabdeal market-data client. No API key is required for these calls.
class TabdealApiService {
  static const baseUrl = 'https://api.tabdeal.org/r/api/v1';
  final http.Client _client;
  TabdealApiService({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? params]) {
    final qp = <String, String>{};
    for (final e in (params ?? const {}).entries) {
      if (e.value != null) qp[e.key] = e.value.toString();
    }
    return Uri.parse('$baseUrl$path').replace(queryParameters: qp.isEmpty ? null : qp);
  }

  Future<dynamic> _get(String path, [Map<String, dynamic>? params]) async {
    final response = await _client.get(_uri(path, params), headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      throw TabdealApiException(response.statusCode, 'پاسخ API قابل خواندن نیست.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map && data['msg'] != null ? data['msg'].toString() : 'HTTP ${response.statusCode}';
      throw TabdealApiException(response.statusCode, message);
    }
    return data;
  }

  Future<bool> ping() async { await _get('/ping'); return true; }

  Future<List<Map<String, dynamic>>> exchangeInfo() async {
    final data = await _get('/exchangeInfo');
    if (data is List) return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    if (data is Map && data['symbols'] is List) {
      return (data['symbols'] as List).whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> trades(String symbol, {int limit = 200}) async {
    final data = await _get('/trades', {'symbol': symbol, 'limit': limit});
    if (data is! List) return [];
    return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<Map<String, dynamic>> depth(String symbol, {int limit = 20}) async {
    final data = await _get('/depth', {'symbol': symbol, 'limit': limit});
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  void dispose() => _client.close();
}
