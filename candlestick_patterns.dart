import '../models/candle.dart';

enum CandlePattern {
  bullishEngulfing,
  bearishEngulfing,
  hammer,
  shootingStar,
  doji,
  morningStar,
  eveningStar,
  none,
}

class CandlestickPatternDetector {
  /// Detects the pattern (if any) ending at index [i] in [candles].
  static CandlePattern detectAt(List<Candle> candles, int i) {
    if (i < 0 || i >= candles.length) return CandlePattern.none;
    final c = candles[i];

    if (_isDoji(c)) return CandlePattern.doji;
    if (_isHammer(c)) return CandlePattern.hammer;
    if (_isShootingStar(c)) return CandlePattern.shootingStar;

    if (i >= 1) {
      final prev = candles[i - 1];
      if (_isBullishEngulfing(prev, c)) return CandlePattern.bullishEngulfing;
      if (_isBearishEngulfing(prev, c)) return CandlePattern.bearishEngulfing;
    }

    if (i >= 2) {
      final first = candles[i - 2];
      final mid = candles[i - 1];
      if (_isMorningStar(first, mid, c)) return CandlePattern.morningStar;
      if (_isEveningStar(first, mid, c)) return CandlePattern.eveningStar;
    }

    return CandlePattern.none;
  }

  static bool _isDoji(Candle c) => c.bodySize <= c.range * 0.1 && c.range > 0;

  static bool _isHammer(Candle c) =>
      c.lowerWick >= c.bodySize * 2 && c.upperWick <= c.bodySize * 0.5 && c.bodySize > 0;

  static bool _isShootingStar(Candle c) =>
      c.upperWick >= c.bodySize * 2 && c.lowerWick <= c.bodySize * 0.5 && c.bodySize > 0;

  static bool _isBullishEngulfing(Candle prev, Candle curr) =>
      prev.isBearish && curr.isBullish && curr.open <= prev.close && curr.close >= prev.open;

  static bool _isBearishEngulfing(Candle prev, Candle curr) =>
      prev.isBullish && curr.isBearish && curr.open >= prev.close && curr.close <= prev.open;

  static bool _isMorningStar(Candle first, Candle mid, Candle last) =>
      first.isBearish &&
      mid.bodySize < first.bodySize * 0.5 &&
      last.isBullish &&
      last.close > (first.open + first.close) / 2;

  static bool _isEveningStar(Candle first, Candle mid, Candle last) =>
      first.isBullish &&
      mid.bodySize < first.bodySize * 0.5 &&
      last.isBearish &&
      last.close < (first.open + first.close) / 2;

  static String patternLabelFa(CandlePattern p) {
    switch (p) {
      case CandlePattern.bullishEngulfing:
        return 'الگوی پوشای صعودی';
      case CandlePattern.bearishEngulfing:
        return 'الگوی پوشای نزولی';
      case CandlePattern.hammer:
        return 'الگوی چکش';
      case CandlePattern.shootingStar:
        return 'الگوی ستاره دنباله‌دار';
      case CandlePattern.doji:
        return 'الگوی دوجی';
      case CandlePattern.morningStar:
        return 'الگوی ستاره صبحگاهی';
      case CandlePattern.eveningStar:
        return 'الگوی ستاره عصرگاهی';
      case CandlePattern.none:
        return 'بدون الگو';
    }
  }
}
