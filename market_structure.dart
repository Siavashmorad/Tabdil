import '../models/candle.dart';

enum SwingType { high, low }

class SwingPoint {
  final int index;
  final double price;
  final SwingType type;
  final DateTime time;
  SwingPoint(this.index, this.price, this.type, this.time);
}

enum StructureBreak { bullishBOS, bearishBOS, bullishCHoCH, bearishCHoCH, none }

class SupplyDemandZone {
  final double top;
  final double bottom;
  final bool isDemand; // true = demand (support), false = supply (resistance)
  final int originIndex;
  SupplyDemandZone(this.top, this.bottom, this.isDemand, this.originIndex);

  double get mid => (top + bottom) / 2;
}

/// Implements a simplified Smart Money Concepts / ICT-style structural
/// reading: swing high/low detection, Break of Structure (BOS) and Change
/// of Character (CHoCH) detection, plus basic supply/demand zone mapping.
///
/// This is a heuristic implementation intended to feed the ensemble signal
/// engine — it is not a full institutional-grade SMC library, but follows
/// the standard definitions:
///   - Swing high: a candle whose high is greater than [window] candles on
///     each side.
///   - BOS: price closes beyond the most recent swing in the direction of
///     the prevailing trend (continuation).
///   - CHoCH: price closes beyond the most recent swing AGAINST the
///     prevailing trend (potential reversal).
class MarketStructureAnalyzer {
  final int window;
  MarketStructureAnalyzer({this.window = 3});

  List<SwingPoint> findSwingPoints(List<Candle> candles) {
    final swings = <SwingPoint>[];
    for (int i = window; i < candles.length - window; i++) {
      final c = candles[i];
      bool isHigh = true;
      bool isLow = true;
      for (int j = i - window; j <= i + window; j++) {
        if (j == i) continue;
        if (candles[j].high >= c.high) isHigh = false;
        if (candles[j].low <= c.low) isLow = false;
      }
      if (isHigh) swings.add(SwingPoint(i, c.high, SwingType.high, c.openTime));
      if (isLow) swings.add(SwingPoint(i, c.low, SwingType.low, c.openTime));
    }
    return swings;
  }

  /// Determines the most recent structural event relative to the last two
  /// swing highs and swing lows.
  StructureBreak detectLatestBreak(List<Candle> candles) {
    final swings = findSwingPoints(candles);
    if (swings.length < 4 || candles.isEmpty) return StructureBreak.none;

    final highs = swings.where((s) => s.type == SwingType.high).toList();
    final lows = swings.where((s) => s.type == SwingType.low).toList();
    if (highs.length < 2 || lows.length < 2) return StructureBreak.none;

    final lastClose = candles.last.close;
    final lastHigh = highs.last;
    final lastLow = lows.last;
    final prevHigh = highs[highs.length - 2];
    final prevLow = lows[lows.length - 2];

    final priorTrendUp = lastHigh.price > prevHigh.price && lastLow.price > prevLow.price;
    final priorTrendDown = lastHigh.price < prevHigh.price && lastLow.price < prevLow.price;

    if (lastClose > lastHigh.price) {
      return priorTrendUp ? StructureBreak.bullishBOS : StructureBreak.bullishCHoCH;
    }
    if (lastClose < lastLow.price) {
      return priorTrendDown ? StructureBreak.bearishBOS : StructureBreak.bearishCHoCH;
    }
    return StructureBreak.none;
  }

  /// Maps basic supply/demand zones from the candle preceding a strong
  /// directional move (a simplified "order block" heuristic).
  List<SupplyDemandZone> findSupplyDemandZones(List<Candle> candles, {int lookback = 100}) {
    final zones = <SupplyDemandZone>[];
    final start = candles.length > lookback ? candles.length - lookback : 1;
    for (int i = start; i < candles.length - 1; i++) {
      final candle = candles[i];
      final next = candles[i + 1];
      final strongMoveUp = next.close > candle.high && next.bodySize > candle.range * 1.2;
      final strongMoveDown = next.close < candle.low && next.bodySize > candle.range * 1.2;

      if (strongMoveUp && candle.isBearish) {
        // Bearish candle before a bullish impulse -> demand zone.
        zones.add(SupplyDemandZone(candle.open, candle.low, true, i));
      }
      if (strongMoveDown && candle.isBullish) {
        // Bullish candle before a bearish impulse -> supply zone.
        zones.add(SupplyDemandZone(candle.high, candle.open, false, i));
      }
    }
    return zones;
  }

  /// Fibonacci retracement levels between the most recent significant
  /// swing high and swing low.
  Map<String, double> fibonacciRetracement(List<Candle> candles) {
    final swings = findSwingPoints(candles);
    if (swings.isEmpty) return {};
    final highs = swings.where((s) => s.type == SwingType.high).toList();
    final lows = swings.where((s) => s.type == SwingType.low).toList();
    if (highs.isEmpty || lows.isEmpty) return {};

    final swingHigh = highs.last.price;
    final swingLow = lows.last.price;
    final range = swingHigh - swingLow;
    if (range <= 0) return {};

    return {
      '0.0': swingHigh,
      '0.236': swingHigh - range * 0.236,
      '0.382': swingHigh - range * 0.382,
      '0.5': swingHigh - range * 0.5,
      '0.618': swingHigh - range * 0.618,
      '0.786': swingHigh - range * 0.786,
      '1.0': swingLow,
    };
  }
}
