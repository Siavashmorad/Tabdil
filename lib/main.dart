import 'package:flutter/material.dart';
import 'core/api/tabdeal_api_service.dart';
import 'core/scanner/live_signal_scanner.dart';

void main() => runApp(const TabdilApp());

class TabdilApp extends StatelessWidget {
  const TabdilApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tabdil Live Scanner',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green, brightness: Brightness.dark),
        home: const ScannerScreen(),
      );
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late final LiveSignalScanner _scanner;
  LiveSignal? _signal;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanner = LiveSignalScanner();
  }

  Future<void> _scan() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _scanner.api.ping();
      final result = await _scanner.scanBest(maxMarkets: 30);
      if (!mounted) return;
      setState(() => _signal = result);
      if (result == null) _error = 'فعلاً فرصت باکیفیت با داده‌های دریافتی پیدا نشد.';
    } catch (e) {
      if (mounted) setState(() => _error = 'اتصال/دریافت داده ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _p(double value) => value >= 1000 ? value.toStringAsFixed(2) : value >= 1 ? value.toStringAsFixed(5) : value.toStringAsFixed(8);

  Widget _row(String title, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
      );

  @override
  Widget build(BuildContext context) {
    final s = _signal;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('اسکنر زنده تبدیل')),
        body: RefreshIndicator(
          onRefresh: _scan,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('داده عمومی معاملات و Order Book تبدیل بررسی می‌شود؛ سیگنال تضمینی نیست و این نسخه هیچ سفارشی ثبت نمی‌کند.'))),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _loading ? null : _scan, icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.radar), label: Text(_loading ? 'در حال اسکن بازارها...' : 'پیدا کردن بهترین فرصت فعلی')),
            const SizedBox(height: 18),
            if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!))),
            if (s != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(s.symbol, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('${s.direction}  •  امتیاز ${s.score.toStringAsFixed(0)}/100', style: TextStyle(color: s.direction == 'LONG' ? Colors.greenAccent : Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const Divider(height: 28),
              _row('نقطه ورود', _p(s.entry)),
              _row('حد ضرر', _p(s.stopLoss)),
              _row('حد سود ۱', _p(s.takeProfit1)),
              _row('حد سود ۲', _p(s.takeProfit2)),
              _row('Risk / Reward', '1 : ${s.riskReward.toStringAsFixed(2)}'),
              _row('Spread', '${s.spreadPercent.toStringAsFixed(3)}%'),
              const SizedBox(height: 8),
              Text(s.reason),
              if (s.direction == 'SHORT') const Padding(padding: EdgeInsets.only(top: 10), child: Text('هشدار: SHORT فقط در بازاری قابل اجراست که معاملات تعهدی/اهرم آن فعال باشد.', style: TextStyle(color: Colors.orangeAccent))),
            ]))),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() { _scanner.dispose(); super.dispose(); }
}

// Keep this import referenced so the API client remains part of the app's public architecture.
final TabdealApiService _apiTypeAnchor = TabdealApiService();
