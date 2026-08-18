import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../models/candle.dart';
import '../models/order_models.dart';

class TabdealApiException implements Exception {
  final int code;
  final String msg;
  TabdealApiException(this.code, this.msg);

  @override
  String toString() => 'TabdealApiException($code): $msg';
}

/// Tabdeal REST API client.
///
/// Tabdeal's reachable REST API hostname is api1.tabdeal.org.
/// The documented REST routes are under /r/api/v1.
class TabdealApiService {
  static const String baseUrl = 'https://api1.tabdeal.org/r/api/v1';

  final String? apiKey;
  final String? apiSecret;
  final http.Client _client;

  TabdealApiService({this.apiKey, this.apiSecret, http.Client? client})
      : _client = client ?? http.Client();

  bool get hasCredentials =>
      apiKey != null && apiKey!.isNotEmpty &&
      apiSecret != null && apiSecret!.isNotEmpty;

  String _sign(String queryString) {
    final secret = apiSecret;
    if (secret == null || secret.isEmpty) {
      throw StateError('API secret not configured — cannot sign request.');
    }
    return Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(queryString))
        .toString();
  }

  Map<String, String> _authHeaders() {
    final key = apiKey;
    if (key == null || key.isEmpty) return {};
    return {'X-MBX-APIKEY': key};
  }

  String _buildSignedQuery(Map<String, dynamic> params) {
    final values = <String, dynamic>{
      ...params,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final query = values.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value.toString())}')
        .join('&');
    return '$query&signature=${_sign(query)}';
  }

  Uri _publicUri(String path, [Map<String, dynamic>? params]) {
    final query = <String, String>{};
    for (final entry in (params ?? {}).entries) {
      if (entry.value != null) query[entry.key] = entry.value.toString();
    }
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query.isEmpty ? null : query,
    );
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (_) {
      throw TabdealApiException(
        response.statusCode,
        'Invalid response from Tabdeal API (HTTP ${response.statusCode}).',
      );
    }

    if (decoded is Map && decoded['code'] != null && decoded['msg'] != null) {
      final rawCode = decoded['code'];
      final code = rawCode is int ? rawCode : int.tryParse('$rawCode') ?? response.statusCode;
      throw TabdealApiException(code, decoded['msg'].toString());
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TabdealApiException(
        response.statusCode,
        decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : 'HTTP ${response.statusCode}',
      );
    }
    return decoded;
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) async {
    return _client.get(uri, headers: headers);
  }

  Future<bool> ping() async {
    final response = await _get(_publicUri('/ping'));
    _handleResponse(response);
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<int?> serverTime() async {
    final response = await _get(_publicUri('/time'));
    final data = _handleResponse(response);
    if (data is Map && data['serverTime'] != null) {
      return int.tryParse(data['serverTime'].toString());
    }
    if (data is num) return data.toInt();
    return null;
  }

  Future<List<Map<String, dynamic>>> getExchangeInfo({String? symbol}) async {
    final uri = _publicUri(
      '/exchangeInfo',
      symbol == null ? null : {'symbol': symbol},
    );
    final data = _handleResponse(await _get(uri));
    if (data is List) return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    if (data is Map && data['symbols'] is List) {
      return (data['symbols'] as List)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
    }
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return [];
  }

  Future<Map<String, dynamic>> getDepth(String symbol, {int limit = 50}) async {
    final data = _handleResponse(
      await _get(_publicUri('/depth', {'symbol': symbol, 'limit': limit})),
    );
    if (data is Map) return Map<String, dynamic>.from(data);
    throw TabdealApiException(0, 'Unexpected order-book response.');
  }

  Future<List<Map<String, dynamic>>> getRecentTrades(
    String symbol, {
    int limit = 500,
  }) async {
    final data = _handleResponse(
      await _get(_publicUri('/trades', {'symbol': symbol, 'limit': limit})),
    );
    if (data is! List) {
      throw TabdealApiException(0, 'Unexpected trades response.');
    }
    return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<List<Candle>> getKlines(
    String symbol, {
    String interval = '15m',
    int limit = 200,
  }) async {
    try {
      final response = await _get(_publicUri('/klines', {
        'symbol': symbol,
        'interval': interval,
        'limit': limit,
      }));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = _handleResponse(response);
        if (data is List) {
          return data
              .whereType<List>()
              .map(Candle.fromKlineArray)
              .toList();
        }
      }
    } catch (_) {}
    return fetchRecentTradesAsCandles(
      symbol,
      bucketSeconds: _intervalToSeconds(interval),
    );
  }

  int _intervalToSeconds(String interval) {
    if (interval.isEmpty) return 900;
    final unit = interval.substring(interval.length - 1).toLowerCase();
    final value = int.tryParse(interval.substring(0, interval.length - 1)) ?? 1;
    switch (unit) {
      case 'm': return value * 60;
      case 'h': return value * 3600;
      case 'd': return value * 86400;
      default: return 900;
    }
  }

  Future<List<Candle>> fetchRecentTradesAsCandles(
    String symbol, {
    int bucketSeconds = 900,
  }) async {
    final trades = await getRecentTrades(symbol, limit: 1000);
    if (trades.isEmpty) return [];

    final buckets = <int, List<Map<String, dynamic>>>{};
    for (final trade in trades) {
      final rawTime = trade['time'] ?? trade['timestamp'];
      final timeMs = rawTime is num
          ? rawTime.toInt()
          : int.tryParse('$rawTime') ?? 0;
      if (timeMs <= 0) continue;
      final bucket = (timeMs ~/ 1000) ~/ bucketSeconds;
      buckets.putIfAbsent(bucket, () => <Map<String, dynamic>>[]).add(trade);
    }

    final keys = buckets.keys.toList()..sort();
    final candles = <Candle>[];
    for (final key in keys) {
      final group = buckets[key]!;
      final prices = group
          .map((t) => double.tryParse('${t['price']}'))
          .whereType<double>()
          .toList();
      if (prices.isEmpty) continue;
      final volume = group
          .map((t) => double.tryParse('${t['qty'] ?? t['quantity'] ?? 0}') ?? 0.0)
          .fold<double>(0.0, (a, b) => a + b);
      candles.add(Candle(
        openTime: DateTime.fromMillisecondsSinceEpoch(key * bucketSeconds * 1000),
        open: prices.first,
        high: prices.reduce((a, b) => a > b ? a : b),
        low: prices.reduce((a, b) => a < b ? a : b),
        close: prices.last,
        volume: volume,
      ));
    }
    return candles;
  }

  Future<Map<String, dynamic>> getAccount() async {
    final query = _buildSignedQuery({});
    final response = await _get(
      Uri.parse('$baseUrl/account?$query'),
      headers: _authHeaders(),
    );
    final data = _handleResponse(response);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw TabdealApiException(0, 'Unexpected account response.');
  }

  Future<TabdealOrder> newOrder({
    required String symbol,
    required OrderSide side,
    required OrderType type,
    required double quantity,
    double? price,
    double? stopPrice,
    String? newClientOrderId,
  }) async {
    final params = <String, dynamic>{
      'tabdealSymbol': symbol.contains('_') ? symbol : symbol,
      'side': side == OrderSide.buy ? 'BUY' : 'SELL',
      'type': type == OrderType.market
          ? 'MARKET'
          : (type == OrderType.stopLossLimit ? 'STOP_LOSS_LIMIT' : 'LIMIT'),
      'quantity': quantity,
      if (price != null) 'price': price,
      if (stopPrice != null) 'stopPrice': stopPrice,
      if (newClientOrderId != null) 'newClientOrderId': newClientOrderId,
    };
    final query = _buildSignedQuery(params);
    final response = await _client.post(
      Uri.parse('$baseUrl/order'),
      headers: {
        ..._authHeaders(),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: query,
    );
    final data = _handleResponse(response);
    if (data is Map) return TabdealOrder.fromJson(Map<String, dynamic>.from(data));
    throw TabdealApiException(0, 'Unexpected order response.');
  }

  Future<TabdealOrder> openMarketPositionWithStop({
    required String symbol,
    required OrderSide side,
    required double quantity,
    required double stopPrice,
    required double stopLimitPrice,
  }) async {
    final entry = await newOrder(
      symbol: symbol,
      side: side,
      type: OrderType.market,
      quantity: quantity,
    );
    final protectiveSide = side == OrderSide.buy ? OrderSide.sell : OrderSide.buy;
    await newOrder(
      symbol: symbol,
      side: protectiveSide,
      type: OrderType.stopLossLimit,
      quantity: quantity,
      price: stopLimitPrice,
      stopPrice: stopPrice,
    );
    return entry;
  }

  Future<TabdealOrder> cancelOrder({
    required String symbol,
    required int orderId,
  }) async {
    final query = _buildSignedQuery({
      'tabdealSymbol': symbol,
      'orderId': orderId,
    });
    final data = _handleResponse(
      await _client.delete(
        Uri.parse('$baseUrl/order?$query'),
        headers: _authHeaders(),
      ),
    );
    if (data is Map) return TabdealOrder.fromJson(Map<String, dynamic>.from(data));
    throw TabdealApiException(0, 'Unexpected cancel-order response.');
  }

  Future<List<TabdealOrder>> getOpenOrders({String? symbol}) async {
    final query = _buildSignedQuery(
      symbol == null ? {} : {'tabdealSymbol': symbol},
    );
    final data = _handleResponse(
      await _get(
        Uri.parse('$baseUrl/openOrders?$query'),
        headers: _authHeaders(),
      ),
    );
    if (data is! List) throw TabdealApiException(0, 'Unexpected open-orders response.');
    return data
        .whereType<Map>()
        .map((e) => TabdealOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<TabdealOrder>> cancelAllOpenOrders(String symbol) async {
    final query = _buildSignedQuery({'tabdealSymbol': symbol});
    final data = _handleResponse(
      await _client.delete(
        Uri.parse('$baseUrl/openOrders?$query'),
        headers: _authHeaders(),
      ),
    );
    if (data is! List) throw TabdealApiException(0, 'Unexpected cancel-all response.');
    return data
        .whereType<Map>()
        .map((e) => TabdealOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  void dispose() => _client.close();
}
