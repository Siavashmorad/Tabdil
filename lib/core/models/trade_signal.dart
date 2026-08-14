enum TradeSignalType { long, short, wait }

class TradeSignal {
  final TradeSignalType type;
  final double score;
  final double? entry;
  final double? stopLoss;
  final double? takeProfit1;
  final double? takeProfit2;
  final double? takeProfit3;
  final String reason;

  const TradeSignal({
    required this.type,
    required this.score,
    this.entry,
    this.stopLoss,
    this.takeProfit1,
    this.takeProfit2,
    this.takeProfit3,
    this.reason = '',
  });

  bool get isLong => type == TradeSignalType.long;
  bool get isShort => type == TradeSignalType.short;
  bool get isWait => type == TradeSignalType.wait;
}
