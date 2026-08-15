class Candle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  bool get isBullish => close >= open;
  bool get isBearish => close < open;

  double get range => high - low;

  factory Candle.fromJson(Map<String, dynamic> json) {
    final rawTime = json['time'] ?? json['timestamp'] ?? 0;
    final milliseconds = rawTime is num
        ? rawTime.toInt()
        : int.tryParse('$rawTime') ?? 0;

    return Candle(
      time: DateTime.fromMillisecondsSinceEpoch(milliseconds),
      open: _number(json['open']),
      high: _number(json['high']),
      low: _number(json['low']),
      close: _number(json['close']),
      volume: _number(json['volume']),
    );
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
