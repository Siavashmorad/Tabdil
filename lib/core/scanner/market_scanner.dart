import '../api/tabdeal_api_service.dart';
import '../analysis/signal_engine.dart';
import '../models/candle.dart';
import '../models/trade_signal.dart';

/// Scans the complete active USDT market universe using Tabdeal public data.
/// No private API credentials are required for scanning.
class MarketScanner {
  final TabdealApiService api;
  final SignalEngine engine;

  MarketScanner({TabdealApiService? api, SignalEngine? engine})
      : api = api ?? TabdealApiService(),
        engine = engine ?? SignalEngine();

  Future<List<String>> discoverUsdtSymbols() async {
    final info = await api.getExchangeInfo();
    final symbols = <String>[];
    for (final item in info) {
      final raw = item['symbol'] ?? item['tabdealSymbol'] ?? item['name'];
      if (raw == null) continue;
      final symbol = raw.toString().toUpperCase();
      final status = (item['status'] ?? 'TRADING').toString().toUpperCase();
      if (status != 'TRADING') continue;
      // Tabdeal symbols can be represented with either _ or concatenation.
      if (symbol.endsWith('USDT') || symbol.endsWith('_USDT')) {
        symbols.add(symbol);
      }
    }
    return symbols.toSet().toList()..sort();
  }

  Future<List<TradeSignal>> scanAllUsdt({
    String interval = '15m',
    int candleLimit = 200,
    int maxMarkets = 0,
  }) async {
    final symbols = await discoverUsdtSymbols();
    final selected = maxMarkets > 0 ? symbols.take(maxMarkets) : symbols;
    final results = <TradeSignal>[];

    for (final symbol in selected) {
      try {
        final candles = await api.getKlines(symbol, interval: interval, limit: candleLimit);
        if (candles.length < 60) continue;
        final signal = engine.analyze(
          symbol: symbol,
          exchange: 'Tabdeal',
          candles: candles,
        );
        if (signal != null) results.add(signal);
      } catch (_) {
        // One unavailable market must never abort the whole scan.
      }
    }

    results.sort((a, b) {
      final confidence = b.confidenceScore.compareTo(a.confidenceScore);
      if (confidence != 0) return confidence;
      return b.riskRewardRatio.compareTo(a.riskRewardRatio);
    });
    return results;
  }

  void dispose() => api.dispose();
}
