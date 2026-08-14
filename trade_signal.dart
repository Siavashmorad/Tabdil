enum SignalDirection { long, short, neutral }

/// A fully-formed trade signal produced by the analysis engine.
/// This mirrors the required fields defined in the project spec.
class TradeSignal {
  final String symbol; // e.g. "BTCIRT"
  final String exchange; // "Tabdeal"
  final SignalDirection direction;
  final double entryZoneLow;
  final double entryZoneHigh;
  final double stopLoss;
  final double takeProfit1;
  final double takeProfit2;
  final double takeProfit3;
  final double riskRewardRatio;
  final double confidenceScore; // 0-100
  final List<String> reasons;
  final List<String> keyRisks;
  final double invalidationLevel;
  final DateTime generatedAt;

  const TradeSignal({
    required this.symbol,
    required this.exchange,
    required this.direction,
    required this.entryZoneLow,
    required this.entryZoneHigh,
    required this.stopLoss,
    required this.takeProfit1,
    required this.takeProfit2,
    required this.takeProfit3,
    required this.riskRewardRatio,
    required this.confidenceScore,
    required this.reasons,
    required this.keyRisks,
    required this.invalidationLevel,
    required this.generatedAt,
  });

  double get entryMid => (entryZoneLow + entryZoneHigh) / 2;

  /// Computes suggested position size given account equity and risk % per trade.
  /// This performs NO guarantee of profitability — purely risk-based sizing.
  double suggestedPositionSize({
    required double accountEquity,
    required double riskPercentPerTrade,
  }) {
    final riskAmount = accountEquity * (riskPercentPerTrade / 100);
    final stopDistance = (entryMid - stopLoss).abs();
    if (stopDistance <= 0) return 0;
    return riskAmount / stopDistance;
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'exchange': exchange,
        'direction': direction.name,
        'entryZoneLow': entryZoneLow,
        'entryZoneHigh': entryZoneHigh,
        'stopLoss': stopLoss,
        'takeProfit1': takeProfit1,
        'takeProfit2': takeProfit2,
        'takeProfit3': takeProfit3,
        'riskRewardRatio': riskRewardRatio,
        'confidenceScore': confidenceScore,
        'reasons': reasons,
        'keyRisks': keyRisks,
        'invalidationLevel': invalidationLevel,
        'generatedAt': generatedAt.toIso8601String(),
      };
}
