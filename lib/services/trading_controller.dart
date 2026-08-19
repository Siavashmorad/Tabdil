import 'package:flutter/foundation.dart';
import '../core/scanner/market_scanner.dart';
import '../core/models/trade_signal.dart';

class TradingController extends ChangeNotifier {
  late final MarketScanner _scanner;

  bool isScanning = false;
  String? lastError;
  int marketsDiscovered = 0;
  List<TradeSignal> scanSignals = const [];

  TradingController({MarketScanner? scanner}) : _scanner = scanner ?? MarketScanner();

  Future<void> loadCredentials() async {
    // Public market scanning does not require private API credentials.
  }

  Future<void> scanAllUsdt() async {
    if (isScanning) return;
    isScanning = true;
    lastError = null;
    notifyListeners();
    try {
      final symbols = await _scanner.discoverUsdtSymbols();
      marketsDiscovered = symbols.length;
      scanSignals = await _scanner.scanAllUsdt();
    } catch (e) {
      lastError = 'خطا در اسکن بازار: $e';
    } finally {
      isScanning = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }
}
