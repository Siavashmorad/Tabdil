import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_trader/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const CryptoTraderApp());
    expect(find.text('اسکنر بازار کریپتو (تبدیل)'), findsOneWidget);
  });
}
