import '../models/trade_signal.dart';

class ScannerResult {
  final int marketsDiscovered;
  final int marketsAnalyzed;
  final DateTime completedAt;
  final List<TradeSignal> signals;

  const ScannerResult({
    required this.marketsDiscovered,
    required this.marketsAnalyzed,
    required this.completedAt,
    required this.signals,
  });

  List<TradeSignal> get topSignals => signals.take(10).toList(growable: false);
}
