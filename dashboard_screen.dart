import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/trading_controller.dart';
import '../../core/models/trade_signal.dart';
import '../analysis/analysis_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradingController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('اسکنر بازار کریپتو (تبدیل)'),
        actions: [
          IconButton(
            icon: controller.isScanning
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: controller.isScanning ? null : () => controller.scanWatchlist(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.scanWatchlist(),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (!controller.hasApiCredentials)
              Card(
                color: Colors.amber.shade900.withOpacity(0.3),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'برای دریافت داده‌های زنده و معامله، ابتدا کلید API صرافی تبدیل را در بخش تنظیمات وارد کنید.',
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            if (controller.lastError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  controller.lastError!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.right,
                ),
              ),
            const SizedBox(height: 8),
            Text('فرصت‌های شناسایی‌شده', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (controller.rankedOpportunities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'در حال حاضر سیگنالی با اطمینان کافی یافت نشد. برای اسکن مجدد، دکمه بازخوانی را بزنید.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...controller.rankedOpportunities.map(
                (e) => _OpportunityCard(
                  symbol: e.key,
                  signal: e.value,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnalysisDetailScreen(
                        symbol: e.key,
                        signal: e.value,
                        candles: controller.candleCache[e.key] ?? const [],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text('لیست رصد', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...controller.watchlist.map((symbol) => ListTile(
                  title: Text(symbol, textAlign: TextAlign.right),
                  trailing: controller.signalCache[symbol] != null
                      ? const Icon(Icons.bolt, color: Colors.amber)
                      : const Icon(Icons.remove, color: Colors.grey),
                )),
          ],
        ),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final String symbol;
  final TradeSignal signal;
  final VoidCallback onTap;

  const _OpportunityCard({required this.symbol, required this.signal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLong = signal.direction == SignalDirection.long;
    final color = isLong ? Colors.greenAccent : Colors.redAccent;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(label: Text('${signal.confidenceScore.toStringAsFixed(0)}٪ اطمینان')),
                  Row(
                    children: [
                      Text(symbol, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 8),
                      Icon(isLong ? Icons.trending_up : Icons.trending_down, color: color),
                      Text(isLong ? ' خرید (Long)' : ' فروش (Short)', style: TextStyle(color: color)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('محدوده ورود: ${signal.entryZoneLow.toStringAsFixed(0)} - ${signal.entryZoneHigh.toStringAsFixed(0)}'),
              Text('حد ضرر: ${signal.stopLoss.toStringAsFixed(0)}  |  ریسک به ریوارد: ${signal.riskRewardRatio.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ),
    );
  }
}
