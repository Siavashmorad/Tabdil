import '../models/candle.dart';
import '../models/trade_signal.dart';
import 'signal_engine.dart';

class BacktestTrade {
  final DateTime entryTime;
  final DateTime? exitTime;
  final SignalDirection direction;
  final double entryPrice;
  final double exitPrice;
  final double stopLoss;
  final double takeProfit1;
  final String exitReason; // 'TP1' | 'SL' | 'end_of_data'
  final double pnlPercent;

  BacktestTrade({
    required this.entryTime,
    required this.exitTime,
    required this.direction,
    required this.entryPrice,
    required this.exitPrice,
    required this.stopLoss,
    required this.takeProfit1,
    required this.exitReason,
    required this.pnlPercent,
  });
}

class BacktestReport {
  final List<BacktestTrade> trades;
  final double winRatePercent;
  final double profitFactor;
  final double maxDrawdownPercent;
  final double sharpeRatio;
  final double totalReturnPercent;
  final int totalTrades;

  BacktestReport({
    required this.trades,
    required this.winRatePercent,
    required this.profitFactor,
    required this.maxDrawdownPercent,
    required this.sharpeRatio,
    required this.totalReturnPercent,
    required this.totalTrades,
  });

  static BacktestReport empty() => BacktestReport(
        trades: [],
        winRatePercent: 0,
        profitFactor: 0,
        maxDrawdownPercent: 0,
        sharpeRatio: 0,
        totalReturnPercent: 0,
        totalTrades: 0,
      );
}

/// Walk-forward style backtester: replays the [SignalEngine] bar-by-bar
/// over historical candles (no lookahead — at each step, only candles up
/// to and including the current index are visible to the engine), then
/// simulates trade outcomes against subsequent price action using a simple
/// TP1/SL exit model.
class Backtester {
  final SignalEngine engine;
  final int minHistoryBars;
  final double feePercentPerSide;

  Backtester({
    SignalEngine? engine,
    this.minHistoryBars = 60,
    this.feePercentPerSide = 0.1,
  }) : engine = engine ?? SignalEngine();

  BacktestReport run({
    required String symbol,
    required List<Candle> candles,
  }) {
    if (candles.length < minHistoryBars + 10) return BacktestReport.empty();

    final trades = <BacktestTrade>[];
    int i = minHistoryBars;

    while (i < candles.length - 1) {
      final windowCandles = candles.sublist(0, i + 1);
      final signal = engine.analyze(
        symbol: symbol,
        exchange: 'Tabdeal',
        candles: windowCandles,
      );

      if (signal == null) {
        i++;
        continue;
      }

      final entryPrice = candles[i].close;
      final isLong = signal.direction == SignalDirection.long;
      int j = i + 1;
      double? exitPrice;
      String exitReason = 'end_of_data';
      DateTime? exitTime;

      while (j < candles.length) {
        final c = candles[j];
        final hitSl = isLong
            ? c.low <= signal.stopLoss
            : c.high >= signal.stopLoss;
        final hitTp = isLong
            ? c.high >= signal.takeProfit1
            : c.low <= signal.takeProfit1;

        if (hitSl) {
          exitPrice = signal.stopLoss;
          exitReason = 'SL';
          exitTime = c.openTime;
          break;
        }
        if (hitTp) {
          exitPrice = signal.takeProfit1;
          exitReason = 'TP1';
          exitTime = c.openTime;
          break;
        }
        j++;
      }

      exitPrice ??= candles.last.close;
      exitTime ??= candles.last.openTime;

      final rawPnlPercent = isLong
          ? (exitPrice - entryPrice) / entryPrice * 100
          : (entryPrice - exitPrice) / entryPrice * 100;
      final netPnlPercent = rawPnlPercent - (feePercentPerSide * 2);

      trades.add(
        BacktestTrade(
          entryTime: candles[i].openTime,
          exitTime: exitTime,
          direction: signal.direction,
          entryPrice: entryPrice,
          exitPrice: exitPrice,
          stopLoss: signal.stopLoss,
          takeProfit1: signal.takeProfit1,
          exitReason: exitReason,
          pnlPercent: netPnlPercent,
        ),
      );

      i = j > i ? j + 1 : i + 1;
    }

    return _buildReport(trades);
  }

  BacktestReport _buildReport(List<BacktestTrade> trades) {
    if (trades.isEmpty) return BacktestReport.empty();

    final wins = trades.where((t) => t.pnlPercent > 0).toList();
    final losses = trades.where((t) => t.pnlPercent <= 0).toList();
    final winRate = wins.length / trades.length * 100;

    final grossProfit = wins.fold<double>(0.0, (a, t) => a + t.pnlPercent);
    final grossLoss = losses.fold<double>(0.0, (a, t) => a + t.pnlPercent.abs());
    final profitFactor = grossLoss == 0
        ? (grossProfit > 0 ? double.infinity : 0.0)
        : grossProfit / grossLoss;

    double equity = 100.0;
    double peak = 100.0;
    double maxDrawdown = 0.0;
    final returns = <double>[];
    for (final t in trades) {
      equity *= (1 + t.pnlPercent / 100);
      returns.add(t.pnlPercent);
      if (equity > peak) peak = equity;
      final drawdown = (peak - equity) / peak * 100;
      if (drawdown > maxDrawdown) maxDrawdown = drawdown;
    }
    final totalReturn = equity - 100.0;

    final double meanReturn =
        returns.fold<double>(0.0, (a, b) => a + b) / returns.length;
    final double variance =
        returns.fold<double>(0.0, (a, b) => a + (b - meanReturn) * (b - meanReturn)) /
            returns.length;
    final double stdDev = variance <= 0.0 ? 0.0 : _sqrt(variance);
    final double sharpe = stdDev == 0.0 ? 0.0 : meanReturn / stdDev;

    return BacktestReport(
      trades: trades,
      winRatePercent: winRate.toDouble(),
      profitFactor: profitFactor.isFinite ? profitFactor.toDouble() : 99.99,
      maxDrawdownPercent: maxDrawdown,
      sharpeRatio: sharpe,
      totalReturnPercent: totalReturn,
      totalTrades: trades.length,
    );
  }

  double _sqrt(double value) {
    if (value <= 0.0) return 0.0;
    double x = value;
    double prev;
    do {
      prev = x;
      x = (x + value / x) / 2.0;
    } while ((x - prev).abs() > 1e-10);
    return x;
  }
}
