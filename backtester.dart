import 'candle.dart';
import 'trade_signal.dart';

class BacktestTrade {
  final String symbol;
  final SignalDirection direction;
  final double entryPrice;
  final double exitPrice;
  final double quantity;
  final double pnl;
  final double returnPercent;

  const BacktestTrade({
    required this.symbol,
    required this.direction,
    required this.entryPrice,
    required this.exitPrice,
    required this.quantity,
    required this.pnl,
    required this.returnPercent,
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

  const BacktestReport({
    required this.trades,
    required this.winRatePercent,
    required this.profitFactor,
    required this.maxDrawdownPercent,
    required this.sharpeRatio,
    required this.totalReturnPercent,
    required this.totalTrades,
  });
}

class Backtester {
  BacktestReport run({
    required List<Candle> candles,
    required List<TradeSignal> signals,
    double startingCapital = 1000,
    double riskPerTrade = 0.01,
  }) {
    final trades = <BacktestTrade>[];
    final returns = <double>[];
    var equity = startingCapital;
    var peakEquity = startingCapital;
    var maxDrawdown = 0.0;
    var grossProfit = 0.0;
    var grossLoss = 0.0;

    for (var i = 0; i < signals.length && i < candles.length; i++) {
      final signal = signals[i];
      if (signal.direction == SignalDirection.neutral) continue;

      final entry = candles[i].close;
      if (entry == null || entry <= 0) continue;

      final next = i + 1;
      if (next >= candles.length) break;
      final exit = candles[next].close;
      if (exit == null || exit <= 0) continue;

      final riskCapital = equity * riskPerTrade;
      final quantity = riskCapital / entry;
      final priceDelta = signal.direction == SignalDirection.long
          ? exit - entry
          : entry - exit;
      final pnl = quantity * priceDelta;
      final returnPercent = equity == 0 ? 0.0 : (pnl / equity) * 100;

      equity += pnl;
      if (pnl >= 0) {
        grossProfit += pnl;
      } else {
        grossLoss += pnl.abs();
      }

      peakEquity = equity > peakEquity ? equity : peakEquity;
      final drawdown = peakEquity == 0
          ? 0.0
          : ((peakEquity - equity) / peakEquity) * 100;
      maxDrawdown = drawdown > maxDrawdown ? drawdown : maxDrawdown;

      returns.add(returnPercent);
      trades.add(
        BacktestTrade(
          symbol: signal.symbol,
          direction: signal.direction,
          entryPrice: entry,
          exitPrice: exit,
          quantity: quantity,
          pnl: pnl,
          returnPercent: returnPercent,
        ),
      );
    }

    final wins = trades.where((trade) => trade.pnl > 0).length;
    final winRate = trades.isEmpty ? 0.0 : (wins / trades.length) * 100;
    final profitFactor = grossLoss == 0 ? 99.99 : grossProfit / grossLoss;
    final totalReturn = startingCapital == 0
        ? 0.0
        : ((equity - startingCapital) / startingCapital) * 100;

    if (returns.isEmpty) {
      return BacktestReport(
        trades: trades,
        winRatePercent: winRate,
        profitFactor: profitFactor,
        maxDrawdownPercent: maxDrawdown,
        sharpeRatio: 0.0,
        totalReturnPercent: totalReturn,
        totalTrades: trades.length,
      );
    }

    // Simple per-trade Sharpe-style ratio (mean / stddev of trade returns).
    final meanReturn = returns.fold<double>(0.0, (a, b) => a + b) / returns.length;
    final variance = returns.fold<double>(
          0.0,
          (a, b) => a + (b - meanReturn) * (b - meanReturn),
        ) /
        returns.length;
    final stdDev = variance <= 0 ? 0.0 : _sqrt(variance);
    final sharpe = stdDev == 0 ? 0.0 : meanReturn / stdDev;

    return BacktestReport(
      trades: trades,
      winRatePercent: winRate,
      profitFactor: profitFactor.isFinite ? profitFactor : 99.99,
      maxDrawdownPercent: maxDrawdown,
      sharpeRatio: sharpe.toDouble(),
      totalReturnPercent: totalReturn,
      totalTrades: trades.length,
    );
  }

  double _sqrt(double value) {
    if (value <= 0) return 0.0;
    double x = value;
    double prev;
    do {
      prev = x;
      x = (x + value / x) / 2;
    } while ((x - prev).abs() > 1e-10);
    return x;
  }
}
