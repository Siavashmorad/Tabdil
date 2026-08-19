import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/trading_controller.dart';

void main() => runApp(const TabdilApp());

class TabdilApp extends StatefulWidget {
  const TabdilApp({super.key});

  @override
  State<TabdilApp> createState() => _TabdilAppState();
}

class _TabdilAppState extends State<TabdilApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('fa', 'IR');

  bool get isFa => _locale.languageCode == 'fa';

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TradingController()..loadCredentials(),
      child: MaterialApp(
        title: isFa ? 'تبدیل | دستیار تحلیل بازار' : 'Tabdil | Market Scanner',
        debugShowCheckedModeBanner: false,
        locale: _locale,
        themeMode: _themeMode,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF10B981)),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF10B981),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0B0F14),
        ),
        home: ScannerHomeScreen(
          isFa: isFa,
          themeMode: _themeMode,
          onToggleTheme: () => setState(() {
            _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
          }),
          onToggleLanguage: () => setState(() {
            _locale = isFa ? const Locale('en', 'US') : const Locale('fa', 'IR');
          }),
        ),
      ),
    );
  }
}

class ScannerHomeScreen extends StatelessWidget {
  final bool isFa;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLanguage;

  const ScannerHomeScreen({
    super.key,
    required this.isFa,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onToggleLanguage,
  });

  String directionLabel(String value) {
    if (!isFa) return value.toUpperCase();
    return value.toLowerCase() == 'long' ? 'لانگ' : 'شورت';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradingController>();
    final signals = controller.scanSignals;
    return Directionality(
      textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isFa ? 'اسکنر بازار تبدیل' : 'Tabdil Market Scanner'),
          actions: [
            IconButton(
              tooltip: isFa ? 'تغییر زبان' : 'Change language',
              onPressed: onToggleLanguage,
              icon: const Icon(Icons.language),
            ),
            IconButton(
              tooltip: isFa ? 'حالت روشن/تاریک' : 'Light/Dark mode',
              onPressed: onToggleTheme,
              icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            ),
            IconButton(
              tooltip: isFa ? 'اسکن همه بازارهای USDT' : 'Scan all USDT markets',
              onPressed: controller.isScanning ? null : controller.scanAllUsdt,
              icon: const Icon(Icons.radar),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: controller.scanAllUsdt,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFa ? 'اسکن کامل بازار USDT' : 'Full USDT Market Scan',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(isFa
                          ? 'بازارها: ${controller.marketsDiscovered} | سیگنال‌ها: ${signals.length}'
                          : 'Markets: ${controller.marketsDiscovered} | Signals: ${signals.length}'),
                      if (controller.isScanning) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      if (controller.lastError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          controller.lastError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final signal in signals.take(20))
                Card(
                  child: ListTile(
                    title: Text(signal.symbol),
                    subtitle: Text(
                      '${directionLabel(signal.direction.name)} | ${isFa ? 'ورود' : 'Entry'}: ${signal.entryMid.toStringAsFixed(6)}\n'
                      '${isFa ? 'حد ضرر' : 'SL'}: ${signal.stopLoss.toStringAsFixed(6)} | ${isFa ? 'هدف ۱' : 'TP1'}: ${signal.takeProfit1.toStringAsFixed(6)}\n'
                      '${isFa ? 'هدف ۲' : 'TP2'}: ${signal.takeProfit2.toStringAsFixed(6)} | ${isFa ? 'هدف ۳' : 'TP3'}: ${signal.takeProfit3.toStringAsFixed(6)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${signal.confidenceScore.toStringAsFixed(0)}%'),
                        Text('R:R ${signal.riskRewardRatio.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
              if (!controller.isScanning && signals.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(isFa ? 'برای شروع، دکمه اسکن را بزنید.' : 'Press scan to start.'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
