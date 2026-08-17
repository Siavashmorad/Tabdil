import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/trading_controller.dart';
import '../../core/models/trade_signal.dart';
import '../../core/scanner/live_signal_scanner.dart';
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
            icon: controller.isScanning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
            onPressed: controller.isScanning ? null : () => controller.scanWatchlist(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.scanWatchlist(),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const _LiveOpportunityCard(),
            const SizedBox(height: 12),
            if (!controller.hasApiCredentials)
              Card(
                color: Colors.amber.shade900.withOpacity(0.3),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('برای داده‌های خصوصی و معامله، کلید API را در تنظیمات وارد کنید. اسکنر زنده بازار از داده‌های عمومی استفاده می‌کند.', textAlign: TextAlign.right),
                ),
              ),
            if (controller.lastError != null)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(controller.lastError!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.right)),
            const SizedBox(height: 8),
            Text('فرصت‌های شناسایی‌شده در رصد فعلی', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (controller.rankedOpportunities.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('در حال حاضر سیگنالی با اطمینان کافی یافت نشد. برای اسکن مجدد، دکمه بازخوانی را بزنید.', textAlign: TextAlign.center))
            else
              ...controller.rankedOpportunities.map((e) => _OpportunityCard(
                    symbol: e.key,
                    signal: e.value,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisDetailScreen(symbol: e.key, signal: e.value, candles: controller.candleCache[e.key] ?? const []))),
                  )),
            const SizedBox(height: 24),
            Text('لیست رصد', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...controller.watchlist.map((symbol) => ListTile(
                  title: Text(symbol, textAlign: TextAlign.right),
                  trailing: controller.signalCache[symbol] != null ? const Icon(Icons.bolt, color: Colors.amber) : const Icon(Icons.remove, color: Colors.grey),
                )),
          ],
        ),
      ),
    );
  }
}

class _LiveOpportunityCard extends StatefulWidget {
  const _LiveOpportunityCard();
  @override
  State<_LiveOpportunityCard> createState() => _LiveOpportunityCardState();
}

class _LiveOpportunityCardState extends State<_LiveOpportunityCard> {
  late final LiveSignalScanner _scanner;
  LiveSignal? _signal;
  bool _loading = false;
  String? _error;

  @override
  void initState() { super.initState(); _scanner = LiveSignalScanner(); }

  Future<void> _scan() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _scanner.api.ping();
      final signal = await _scanner.scanBest(maxMarkets: 30);
      if (mounted) setState(() { _signal = signal; if (signal == null) _error = 'فرصت باکیفیت کافی پیدا نشد.'; });
    } catch (e) {
      if (mounted) setState(() => _error = 'خطای اتصال به API تبدیل: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _p(double v) => v >= 1000 ? v.toStringAsFixed(2) : v >= 1 ? v.toStringAsFixed(5) : v.toStringAsFixed(8);

  @override
  Widget build(BuildContext context) {
    final s = _signal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('بهترین فرصت زنده', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Icon(Icons.radar, color: Theme.of(context).colorScheme.primary),
          ]),
          const SizedBox(height: 8),
          const Text('۳۰ بازار منتخب با Trades + Order Book بررسی می‌شوند. این بخش فقط تحلیل می‌کند و سفارش ثبت نمی‌کند.', textAlign: TextAlign.right),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: _loading ? null : _scan, icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search), label: Text(_loading ? 'در حال اسکن...' : 'اسکن بهترین پوزیشن')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent), textAlign: TextAlign.center)),
          if (s != null) ...[
            const Divider(height: 24),
            Text(s.symbol, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            Text('${s.direction} • امتیاز ${s.score.toStringAsFixed(0)}/100', style: TextStyle(fontWeight: FontWeight.bold, color: s.direction == 'LONG' ? Colors.greenAccent : Colors.orangeAccent), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('ورود: ${_p(s.entry)}'),
            Text('حد ضرر: ${_p(s.stopLoss)}'),
            Text('TP1: ${_p(s.takeProfit1)}'),
            Text('TP2: ${_p(s.takeProfit2)}'),
            Text('R/R: 1:${s.riskReward.toStringAsFixed(2)} • Spread: ${s.spreadPercent.toStringAsFixed(3)}%'),
            const SizedBox(height: 6),
            Text(s.reason, textAlign: TextAlign.right),
            if (s.direction == 'SHORT') const Padding(padding: EdgeInsets.only(top: 8), child: Text('SHORT نیازمند بازار تعهدی/اهرم است؛ این کارت هیچ سفارشی ارسال نمی‌کند.', style: TextStyle(color: Colors.orangeAccent), textAlign: TextAlign.right)),
          ],
        ]),
      ),
    );
  }

  @override
  void dispose() { _scanner.dispose(); super.dispose(); }
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Chip(label: Text('${signal.confidenceScore.toStringAsFixed(0)}٪ اطمینان')),
              Row(children: [Text(symbol, style: Theme.of(context).textTheme.titleMedium), const SizedBox(width: 8), Icon(isLong ? Icons.trending_up : Icons.trending_down, color: color), Text(isLong ? ' خرید (Long)' : ' فروش (Short)', style: TextStyle(color: color))]),
            ]),
            const SizedBox(height: 8),
            Text('محدوده ورود: ${signal.entryZoneLow.toStringAsFixed(0)} - ${signal.entryZoneHigh.toStringAsFixed(0)}'),
            Text('حد ضرر: ${signal.stopLoss.toStringAsFixed(0)}  |  ریسک به ریوارد: ${signal.riskRewardRatio.toStringAsFixed(2)}'),
          ]),
        ),
      ),
    );
  }
}
