class CandlestickPattern {
  final String name;
  final String description;
  final bool bullish;
  final bool bearish;
  final double confidence;

  const CandlestickPattern({
    required this.name,
    this.description = '',
    this.bullish = false,
    this.bearish = false,
    this.confidence = 0,
  });
}
