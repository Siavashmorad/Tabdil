import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../models/candle.dart';
import '../models/order_models.dart';

/// Thrown when Tabdeal API returns a structured error {code, msg}.
class TabdealApiException implements Exception {
  final int code;
  final String msg;
  TabdealApiException(this.code, this.msg);

  @override
  String toString() => 'TabdealApiException($code): $msg';
}

/// Client for the Tabdeal REST API.
///
/// Base URL and authentication scheme are taken from the official docs
/// at https://docs.tabdeal.org/ (Persian):
///   - Base URL: https://api1.tabdeal.org/r/api/v1
///   - Public endpoints:  no auth required
///   - USER endpoints:    header `X-MBX-APIKEY: <api_key>`
///   - TRADE endpoints:   header `X-MBX-APIKEY` + `signature` query param,
///                        where signature = HMAC_SHA256(queryString, api_secret)
///                        and queryString MUST include a `timestamp` (ms).
///
/// IMPORTANT / KNOWN GAP: the public docs page did not expose a documented
/// `klines` (candlestick history) endpoint at the time this client was written.
/// A best-effort path (`/klines`) is included below following the same
/// Binance-style convention used by every other endpoint in this API, but it
/// has NOT been independently confirmed. Before relying on it, verify against
/// the official Postman collection: https://github.com/Tabdeal-Exchange/tabdeal-api-postman
/// If it 404s, candles must instead be reconstructed client-side from the
/// `/trades` endpoint (see [TabdealApiService.fetchRecentTradesAsCandles]).
class TabdealApiService {
  static const String baseUrl = 'https://api1.tabdeal.org/r/api/v1';

  final String? apiKey;
  final String? apiSecret;
  final http.Client _client;

  TabdealApiService({this.apiKey, this.apiSecret, http.Client? client})
      : _client = client ?? http.Client();

  bool get hasCredentials => apiKey != null && apiSecret != null;

  // ---------------------------------------------------------------------
  // Signing helpers
  // ---------------------------------------------------------------------

  String _sign(String queryString) {
    if (apiSecret == null) {
      throw StateError('API secret not configured — cannot sign request.');
    }
    final key = utf8.encode(apiSecret!);
    final bytes = utf8.encode(queryString);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  Map<String, String> _authHeaders() {
    if (apiKey == null) return {};
    return {'X-MBX-APIKEY': apiKey!};
  }

  String _buildSignedQuery(Map<String, dynamic> params) {
    final withTimestamp = {
      ...params,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final query = withTimestamp.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value.toString())}')
        .join('&');
    final signature = _sign(query);
    return '$query&signature=$signature';
  }

  Uri _publicUri(String path, [Map<String, dynamic>? params]) {
    final query = (params ?? {})
        .map((k, v) => MapEntry(k, v.toString()));
    return Uri.parse('$baseUrl$path').replace(queryParameters: query.isEmpty ? null : query);
  }

  dynamic _handleResponse(http.Response resp) {
    final decoded = jsonDecode(resp.body);
    if (decoded is Map && decoded.containsKey('code') && decoded.containsKey('msg')) {
      // Tabdeal error envelope, e.g. {"code": 1218, "msg": "..."}
      throw TabdealApiException(decoded['code'] as int, decoded['msg'] as String);
    }
    return decoded;
  }

  // ---------------------------------------------------------------------
  // Public (unauthenticated) endpoints
  // ---------------------------------------------------------------------

  /// GET /exchangeInfo — market rules, filters (min qty, tick size, etc).
  Future<List<Map<String, dynamic>>> getExchangeInfo({String? symbol}) async {
    final uri = _publicUri('/exchangeInfo', symbol != null ? {'symbol': symbol} : null);
    final resp = await _client.get(uri);
    final data = _handleResponse(resp);
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map && data['symbols'] is List) {
      return (data['symbols'] as List).cast<Map<String, dynamic>>();
    }
    return [data as Map<String, dynamic>];
  }

  /// GET /depth — order book snapshot.
  Future<Map<String, dynamic>> getDepth(String symbol, {int limit = 50}) async {
    final uri = _publicUri('/depth', {'symbol': symbol, 'limit': limit});
    final resp = await _client.get(uri);
    return _handleResponse(resp) as Map<String, dynamic>;
  }

  /// GET /trades — most recent public trades for a symbol.
  Future<List<Map<String, dynamic>>> getRecentTrades(String symbol, {int limit = 500}) async {
    final uri = _publicUri('/trades', {'symbol': symbol, 'limit': limit});
    final resp = await _client.get(uri);
    final data = _handleResponse(resp);
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Best-effort klines fetch. See class-level doc comment for caveats.
  /// Falls back to bucketing recent trades into candles if the endpoint
  /// is unavailable.
  Future<List<Candle>> getKlines(
    String symbol, {
    String interval = '15m',
    int limit = 200,
  }) async {
    try {
      final uri = _publicUri('/klines', {
        'symbol': symbol,
        'interval': interval,
        'limit': limit,
      });
      final resp = await _client.get(uri);
      if (resp.statusCode == 200) {
        final data = _handleResponse(resp);
        if (data is List) {
          return data.map((e) => Candle.fromKlineArray(e as List)).toList();
        }
      }
    } catch (_) {
      // fall through to trade-bucketing fallback
    }
    return fetchRecentTradesAsCandles(symbol, bucketSeconds: _intervalToSeconds(interval));
  }

  int _intervalToSeconds(String interval) {
    final unit = interval.substring(interval.length - 1);
    final value = int.tryParse(interval.substring(0, interval.length - 1)) ?? 1;
    switch (unit) {
      case 'm':
        return value * 60;
      case 'h':
        return value * 3600;
      case 'd':
        return value * 86400;
      default:
        return 900;
    }
  }

  /// Fallback candle builder: buckets raw trades into fixed-size time windows.
  /// Less accurate than a true klines endpoint (limited by trade history
  /// depth), but keeps the analysis engine functional without a confirmed
  /// klines API.
  Future<List<Candle>> fetchRecentTradesAsCandles(
    String symbol, {
    int bucketSeconds = 900,
  }) async {
    final trades = await getRecentTrades(symbol, limit: 1000);
    if (trades.isEmpty) return [];

    final buckets = <int, List<Map<String, dynamic>>>{};
    for (final t in trades) {
      final timeMs = t['time'] as int;
      final bucketKey = (timeMs ~/ 1000) ~/ bucketSeconds;
      buckets.putIfAbsent(bucketKey, () => []).add(t);
    }

    final sortedKeys = buckets.keys.toList()..sort();
    final candles = <Candle>[];
    for (final key in sortedKeys) {
      final group = buckets[key]!;
      final prices = group.map((t) => double.parse(t['price'].toString())).toList();
      final volumes = group.map((t) => double.parse(t['qty'].toString())).toList();
      candles.add(Candle(
        openTime: DateTime.fromMillisecondsSinceEpoch(key * bucketSeconds * 1000),
        open: prices.first,
        high: prices.reduce((a, b) => a > b ? a : b),
        low: prices.reduce((a, b) => a < b ? a : b),
        close: prices.last,
        volume: volumes.fold(0.0, (a, b) => a + b),
      ));
    }
    return candles;
  }

  // ---------------------------------------------------------------------
  // Authenticated (USER) endpoints
  // ---------------------------------------------------------------------

  /// GET /account — balances and permissions. Requires api-key only (USER).
  Future<Map<String, dynamic>> getAccount() async {
    final query = _buildSignedQuery({});
    final uri = Uri.parse('$baseUrl/account?$query');
    final resp = await _client.get(uri, headers: _authHeaders());
    return _handleResponse(resp) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------
  // Authenticated (TRADE) endpoints — these move real funds.
  // ---------------------------------------------------------------------

  /// POST /order — place a new spot order (MARKET or LIMIT).
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
      'symbol': symbol,
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
    final uri = Uri.parse('$baseUrl/order');
    final resp = await _client.post(
      uri,
      headers: {..._authHeaders(), 'Content-Type': 'application/x-www-form-urlencoded'},
      body: query,
    );
    final data = _handleResponse(resp) as Map<String, dynamic>;
    return TabdealOrder.fromJson(data);
  }

  /// Places a market entry order, then attaches a protective stop-loss
  /// (STOP_LOSS_LIMIT) order. Take-profits are managed client-side by the
  /// app's position monitor (Tabdeal spot OCO covers only ONE stop + ONE
  /// limit leg — not three take-profit levels — so TP1/TP2/TP3 partial
  /// exits are orchestrated in Dart, not natively on the exchange).
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

    // Attach protective stop on the opposite side.
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

  /// DELETE /order — cancel an existing order.
  Future<TabdealOrder> cancelOrder({required String symbol, required int orderId}) async {
    final query = _buildSignedQuery({'symbol': symbol, 'orderId': orderId});
    final uri = Uri.parse('$baseUrl/order?$query');
    final resp = await _client.delete(uri, headers: _authHeaders());
    final data = _handleResponse(resp) as Map<String, dynamic>;
    return TabdealOrder.fromJson(data);
  }

  /// GET /openOrders
  Future<List<TabdealOrder>> getOpenOrders({String? symbol}) async {
    final query = _buildSignedQuery(symbol != null ? {'symbol': symbol} : {});
    final uri = Uri.parse('$baseUrl/openOrders?$query');
    final resp = await _client.get(uri, headers: _authHeaders());
    final data = _handleResponse(resp) as List;
    return data.map((e) => TabdealOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// DELETE cancel-all open orders for a symbol.
  Future<List<TabdealOrder>> cancelAllOpenOrders(String symbol) async {
    final query = _buildSignedQuery({'symbol': symbol});
    final uri = Uri.parse('$baseUrl/openOrders?$query');
    final resp = await _client.delete(uri, headers: _authHeaders());
    final data = _handleResponse(resp) as List;
    return data.map((e) => TabdealOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  void dispose() => _client.close();
}
