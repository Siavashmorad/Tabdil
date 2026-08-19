import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/trading_controller.dart';

void main() {
  runApp(const TabdilApp());
}

class TabdilApp extends StatelessWidget {
  const TabdilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TradingController()..loadCredentials(),
      child: MaterialApp(
        title: 'تبدیل | دستیار تحلیل بازار',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa', 'IR'),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF10B981),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0B0F14),
        ),
        home: const ScannerHomeScreen(),
      ),
    );
  }
}

class ScannerHomeScreen extends StatelessWidget {
  const ScannerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradingController>();
    final signals = controller.scanSignals;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اسکنر بازار تبدیل'),
          actions: [
            IconButton(
              tooltip: 'اسکن همه بازارهای USDT',
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
                      Text('اسکن کامل USDT', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('بازارها: ${controller.marketsDiscovered} | سیگنال‌ها: ${signals.length}'),
                      if (controller.isScanning) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      if (controller.lastError != null) ...[
                        const SizedBox(height: 12),
                        Text(controller.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                      '${signal.direction.name.toUpperCase()} | Entry: ${signal.entryMid.toStringAsFixed(6)}\n'
                      'SL: ${signal.stopLoss.toStringAsFixed(6)} | TP1: ${signal.takeProfit1.toStringAsFixed(6)}\n'
                      'TP2: ${signal.takeProfit2.toStringAsFixed(6)} | TP3: ${signal.takeProfit3.toStringAsFixed(6)}',
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
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('برای شروع، دکمه اسکن را بزنید.')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
