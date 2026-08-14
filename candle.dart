/// Represents a single OHLCV candlestick for a given timeframe.
class Candle {
  final DateTime openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const Candle({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  bool get isBullish => close >= open;
  bool get isBearish => close < open;

  /// Body size (absolute) of the candle.
  double get bodySize => (close - open).abs();

  /// Full range (high - low) of the candle.
  double get range => high - low;

  /// Upper wick length.
  double get upperWick => high - (isBullish ? close : open);

  /// Lower wick length.
  double get lowerWick => (isBullish ? open : close) - low;

  factory Candle.fromKlineArray(List<dynamic> raw) {
    // Generic Binance-style kline array format:
    // [openTime, open, high, low, close, volume, closeTime, ...]
    return Candle(
      openTime: DateTime.fromMillisecondsSinceEpoch(raw[0] as int),
      open: double.parse(raw[1].toString()),
      high: double.parse(raw[2].toString()),
      low: double.parse(raw[3].toString()),
      close: double.parse(raw[4].toString()),
      volume: double.parse(raw[5].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'openTime': openTime.millisecondsSinceEpoch,
        'open': open,
        'high': high,
        'low': low,
        'close': close,
        'volume': volume,
      };

  factory Candle.fromJson(Map<String, dynamic> json) => Candle(
        openTime: DateTime.fromMillisecondsSinceEpoch(json['openTime'] as int),
        open: (json['open'] as num).toDouble(),
        high: (json['high'] as num).toDouble(),
        low: (json['low'] as num).toDouble(),
        close: (json['close'] as num).toDouble(),
        volume: (json['volume'] as num).toDouble(),
      );
}
