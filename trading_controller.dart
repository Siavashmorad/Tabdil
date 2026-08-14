import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api/tabdeal_api_service.dart';
import '../core/analysis/signal_engine.dart';
import '../core/models/candle.dart';
import '../core/models/trade_signal.dart';
import '../core/models/order_models.dart';
import '../core/risk/risk_manager.dart';

/// Default symbols to scan. Kept intentionally small for a personal-use,
/// phone-only app — a large universal scanner (per the original spec) would
/// require far more API calls than is practical without a backend.
/// User can edit this list in Settings.
class TradingController extends ChangeNotifier {
  final _secureStorage = const FlutterSecureStorage();
  TabdealApiService _api = TabdealApiService();
  final SignalEngine _signalEngine = SignalEngine();

  List<String> watchlist = ['BTCIRT', 'ETHIRT', 'USDTIRT', 'TRXIRT', 'DOGEIRT'];

  final Map<String, List<Candle>> _candleCache = {};
  final Map<String, TradeSignal?> _signalCache = {};

  RiskSettings? riskSettings;
  final RiskManager riskManager = RiskManager(const RiskSettings(
    accountEquity: 0,
    riskPercentPerTrade: 1,
    maxDailyLossPercent: 5,
    maxExposurePercent: 30,
    maxLeverage: 1,
    maxOpenPositions: 3,
  ));

  bool autoTradingEnabled = false;
  bool isScanning = false;
  String? lastError;

  final List<OpenPosition> openPositions = [];
  final List<OpenPosition> closedPositions = [];

  Timer? _scanTimer;

  bool get hasApiCredentials => _api.hasCredentials;

  Map<String, List<Candle>> get candleCache => _candleCache;
  Map<String, TradeSignal?> get signalCache => _signalCache;

  // ---------------------------------------------------------------------
  // Credential management
  // ---------------------------------------------------------------------

  Future<void> loadCredentials() async {
    final key = await _secureStorage.read(key: 'tabdeal_api_key');
    final secret = await _secureStorage.read(key: 'tabdeal_api_secret');
    if (key != null && secret != null) {
      _api = TabdealApiService(apiKey: key, apiSecret: secret);
    }
    notifyListeners();
  }

  Future<void> saveCredentials(String apiKey, String apiSecret) async {
    await _secureStorage.write(key: 'tabdeal_api_key', value: apiKey);
    await _secureStorage.write(key: 'tabdeal_api_secret', value: apiSecret);
    _api = TabdealApiService(apiKey: apiKey, apiSecret: apiSecret);
    notifyListeners();
  }

  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: 'tabdeal_api_key');
    await _secureStorage.delete(key: 'tabdeal_api_secret');
    _api = TabdealApiService();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Risk settings — user must (re-)enter these before enabling auto-trading
  // ---------------------------------------------------------------------

  void updateRiskSettings(RiskSettings settings) {
    riskSettings = settings;
    riskManager.settings = settings;
    notifyListeners();
  }

  void setAutoTradingEnabled(bool enabled) {
    if (enabled) {
      if (riskSettings == null || !riskSettings!.isValid) {
        lastError = 'لطفاً ابتدا تنظیمات ریسک را به‌صورت کامل و معتبر وارد کنید.';
        notifyListeners();
        return;
      }
      riskManager.resumeManually();
    } else {
      riskManager.pauseManually();
    }
    autoTradingEnabled = enabled;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Market scanning
  // ---------------------------------------------------------------------

  Future<void> scanWatchlist({String interval = '15m'}) async {
    isScanning = true;
    lastError = null;
    notifyListeners();

    for (final symbol in watchlist) {
      try {
        final candles = await _api.getKlines(symbol, interval: interval, limit: 200);
        if (candles.isEmpty) continue;
        _candleCache[symbol] = candles;
        final signal = _signalEngine.analyze(
          symbol: symbol,
          exchange: 'Tabdeal',
          candles: candles,
        );
        _signalCache[symbol] = signal;
      } catch (e) {
        lastError = 'خطا در دریافت داده $symbol: $e';
      }
    }

    isScanning = false;
    notifyListeners();

    if (autoTradingEnabled) {
      await _evaluateAutoTrades();
    }
  }

  void startAutoScan({Duration interval = const Duration(minutes: 5)}) {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(interval, (_) => scanWatchlist());
  }

  void stopAutoScan() {
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  /// Ranks the current watchlist by absolute confidence score (a stand-in
  /// for the spec's "opportunity score" across the scanned universe).
  List<MapEntry<String, TradeSignal>> get rankedOpportunities {
    final entries = _signalCache.entries
        .where((e) => e.value != null)
        .map((e) => MapEntry(e.key, e.value!))
        .toList();
    entries.sort((a, b) => b.value.confidenceScore.compareTo(a.value.confidenceScore));
    return entries;
  }

  // ---------------------------------------------------------------------
  // Auto-trading execution
  // ---------------------------------------------------------------------

  Future<void> _evaluateAutoTrades() async {
    if (!hasApiCredentials || riskSettings == null) return;

    for (final entry in rankedOpportunities) {
      final symbol = entry.key;
      final signal = entry.value;

      final alreadyOpen = openPositions.any((p) => p.symbol == symbol && !p.closed);
      if (alreadyOpen) continue;

      final qty = signal.suggestedPositionSize(
        accountEquity: riskSettings!.accountEquity,
        riskPercentPerTrade: riskSettings!.riskPercentPerTrade,
      );
      if (qty <= 0) continue;
      final positionValue = qty * signal.entryMid;

      final halt = riskManager.canOpenNewPosition(
        currentOpenPositions: openPositions.where((p) => !p.closed).toList(),
        proposedPositionValue: positionValue,
      );
      if (halt != TradingHaltReason.none) {
        lastError = RiskManager.haltReasonLabelFa(halt);
        notifyListeners();
        continue;
      }

      await _executeSignal(symbol, signal, qty);
    }
  }

  Future<void> _executeSignal(String symbol, TradeSignal signal, double qty) async {
    try {
      final side = signal.direction == SignalDirection.long ? OrderSide.buy : OrderSide.sell;
      final entryOrder = await _api.openMarketPositionWithStop(
        symbol: symbol,
        side: side,
        quantity: qty,
        stopPrice: signal.stopLoss,
        stopLimitPrice: signal.stopLoss,
      );

      final position = OpenPosition(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        symbol: symbol,
        side: side,
        entryPrice: signal.entryMid,
        quantity: qty,
        stopLoss: signal.stopLoss,
        takeProfit1: signal.takeProfit1,
        takeProfit2: signal.takeProfit2,
        takeProfit3: signal.takeProfit3,
        openedAt: DateTime.now(),
        entryOrderId: entryOrder.orderId,
      );
      openPositions.add(position);
      notifyListeners();
    } catch (e) {
      lastError = 'خطا در ثبت سفارش برای $symbol: $e';
      notifyListeners();
    }
  }

  /// Manually close a position at current market price (user-initiated,
  /// or called by the position monitor when SL/TP is hit).
  Future<void> closePositionManually(OpenPosition position, double exitPrice) async {
    try {
      final closingSide = position.side == OrderSide.buy ? OrderSide.sell : OrderSide.buy;
      await _api.newOrder(
        symbol: position.symbol,
        side: closingSide,
        type: OrderType.market,
        quantity: position.quantity,
      );
      position.closed = true;
      position.closePrice = exitPrice;
      position.closedAt = DateTime.now();
      riskManager.recordClosedTradePnl(position.unrealizedPnl(exitPrice));
      openPositions.remove(position);
      closedPositions.add(position);
      notifyListeners();
    } catch (e) {
      lastError = 'خطا در بستن پوزیشن ${position.symbol}: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _api.dispose();
    super.dispose();
  }
}
