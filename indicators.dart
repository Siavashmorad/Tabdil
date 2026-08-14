import '../models/candle.dart';

/// Collection of standard technical-analysis indicator calculations.
/// Pure functions operating on a list of [Candle]s ordered oldest -> newest.
class Indicators {
  /// Simple Moving Average over the last [period] closes.
  static List<double?> sma(List<Candle> candles, int period) {
    final result = List<double?>.filled(candles.length, null);
    for (int i = period - 1; i < candles.length; i++) {
      double sum = 0;
      for (int j = i - period + 1; j <= i; j++) {
        sum += candles[j].close;
      }
      result[i] = sum / period;
    }
    return result;
  }

  /// Exponential Moving Average.
  static List<double?> ema(List<Candle> candles, int period) {
    final result = List<double?>.filled(candles.length, null);
    if (candles.length < period) return result;
    final k = 2 / (period + 1);
    double prevEma = candles.sublist(0, period).map((c) => c.close).reduce((a, b) => a + b) / period;
    result[period - 1] = prevEma;
    for (int i = period; i < candles.length; i++) {
      final val = candles[i].close * k + prevEma * (1 - k);
      result[i] = val;
      prevEma = val;
    }
    return result;
  }

  /// Relative Strength Index (Wilder's smoothing).
  static List<double?> rsi(List<Candle> candles, {int period = 14}) {
    final result = List<double?>.filled(candles.length, null);
    if (candles.length <= period) return result;

    double avgGain = 0, avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final change = candles[i].close - candles[i - 1].close;
      if (change >= 0) {
        avgGain += change;
      } else {
        avgLoss -= change;
      }
    }
    avgGain /= period;
    avgLoss /= period;
    result[period] = _rsiFromAvg(avgGain, avgLoss);

    for (int i = period + 1; i < candles.length; i++) {
      final change = candles[i].close - candles[i - 1].close;
      final gain = change > 0 ? change : 0.0;
      final loss = change < 0 ? -change : 0.0;
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
      result[i] = _rsiFromAvg(avgGain, avgLoss);
    }
    return result;
  }

  static double _rsiFromAvg(double avgGain, double avgLoss) {
    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  /// MACD (12,26,9 by default). Returns (macdLine, signalLine, histogram).
  static ({List<double?> macd, List<double?> signal, List<double?> histogram}) macd(
    List<Candle> candles, {
    int fast = 12,
    int slow = 26,
    int signalPeriod = 9,
  }) {
    final emaFast = ema(candles, fast);
    final emaSlow = ema(candles, slow);
    final macdLine = List<double?>.filled(candles.length, null);
    for (int i = 0; i < candles.length; i++) {
      if (emaFast[i] != null && emaSlow[i] != null) {
        macdLine[i] = emaFast[i]! - emaSlow[i]!;
      }
    }

    // Signal line = EMA of macdLine over non-null values.
    final signalLine = List<double?>.filled(candles.length, null);
    final validIndices = <int>[];
    for (int i = 0; i < macdLine.length; i++) {
      if (macdLine[i] != null) validIndices.add(i);
    }
    if (validIndices.length >= signalPeriod) {
      final k = 2 / (signalPeriod + 1);
      double prev = 0;
      for (int idx = 0; idx < signalPeriod; idx++) {
        prev += macdLine[validIndices[idx]]!;
      }
      prev /= signalPeriod;
      signalLine[validIndices[signalPeriod - 1]] = prev;
      for (int idx = signalPeriod; idx < validIndices.length; idx++) {
        final val = macdLine[validIndices[idx]]! * k + prev * (1 - k);
        signalLine[validIndices[idx]] = val;
        prev = val;
      }
    }

    final histogram = List<double?>.filled(candles.length, null);
    for (int i = 0; i < candles.length; i++) {
      if (macdLine[i] != null && signalLine[i] != null) {
        histogram[i] = macdLine[i]! - signalLine[i]!;
      }
    }

    return (macd: macdLine, signal: signalLine, histogram: histogram);
  }

  /// Average True Range — volatility measure used for stop distance / sizing.
  static List<double?> atr(List<Candle> candles, {int period = 14}) {
    final trueRanges = <double>[];
    for (int i = 0; i < candles.length; i++) {
      if (i == 0) {
        trueRanges.add(candles[i].range);
        continue;
      }
      final prevClose = candles[i - 1].close;
      final tr = [
        candles[i].high - candles[i].low,
        (candles[i].high - prevClose).abs(),
        (candles[i].low - prevClose).abs(),
      ].reduce((a, b) => a > b ? a : b);
      trueRanges.add(tr);
    }

    final result = List<double?>.filled(candles.length, null);
    if (candles.length < period) return result;
    double avg = trueRanges.sublist(0, period).reduce((a, b) => a + b) / period;
    result[period - 1] = avg;
    for (int i = period; i < candles.length; i++) {
      avg = (avg * (period - 1) + trueRanges[i]) / period;
      result[i] = avg;
    }
    return result;
  }

  /// Bollinger Bands (middle, upper, lower).
  static ({List<double?> mid, List<double?> upper, List<double?> lower}) bollingerBands(
    List<Candle> candles, {
    int period = 20,
    double stdDevMultiplier = 2,
  }) {
    final mid = sma(candles, period);
    final upper = List<double?>.filled(candles.length, null);
    final lower = List<double?>.filled(candles.length, null);
    for (int i = period - 1; i < candles.length; i++) {
      final window = candles.sublist(i - period + 1, i + 1).map((c) => c.close);
      final mean = mid[i]!;
      final variance = window.map((c) => (c - mean) * (c - mean)).reduce((a, b) => a + b) / period;
      final std = _sqrt(variance);
      upper[i] = mean + stdDevMultiplier * std;
      lower[i] = mean - stdDevMultiplier * std;
    }
    return (mid: mid, upper: upper, lower: lower);
  }

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    double x = value;
    double prev;
    do {
      prev = x;
      x = (x + value / x) / 2;
    } while ((x - prev).abs() > 1e-10);
    return x;
  }

  /// Basic trend classification via slope of the EMA(50) over recent bars.
  static String trendDirection(List<Candle> candles, {int emaPeriod = 50, int lookback = 10}) {
    final emaVals = ema(candles, emaPeriod);
    if (emaVals.length < lookback + 1) return 'unknown';
    final recent = emaVals.sublist(emaVals.length - lookback).whereType<double>().toList();
    if (recent.length < 2) return 'unknown';
    final slope = recent.last - recent.first;
    final threshold = recent.first.abs() * 0.001;
    if (slope > threshold) return 'uptrend';
    if (slope < -threshold) return 'downtrend';
    return 'sideways';
  }
}
