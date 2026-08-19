import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_trader/core/scanner/market_scanner.dart';

void main() {
  test('MarketScanner can be constructed without private credentials', () {
    final scanner = MarketScanner();
    expect(scanner, isNotNull);
    scanner.dispose();
  });
}
