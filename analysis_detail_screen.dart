import 'package:flutter/material.dart';
import '../../core/models/trade_signal.dart';
import '../../core/models/candle.dart';
import '../../widgets/candlestick_chart.dart';

class AnalysisDetailScreen extends StatelessWidget {
  final String symbol;
  final TradeSignal signal;
  final List<Candle> candles;

  const AnalysisDetailScreen({
    super.key,
    required this.symbol,
    required this.signal,
    this.candles = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isLong = signal.direction == SignalDirection.long;
    final color = isLong ? Colors.greenAccent : Colors.redAccent;

    return Scaffold(
      appBar: AppBar(title: Text('تحلیل $symbol')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(isLong ? Icons.trending_up : Icons.trending_down, color: color, size: 32),
              const SizedBox(width: 8),
              Text(
                isLong ? 'سیگنال خرید (Long)' : 'سیگنال فروش (Short)',
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Chip(label: Text('${signal.confidenceScore.toStringAsFixed(0)}٪ اطمینان')),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CandlestickChart(candles: candles, signal: signal),
            ),
          ),
          const SizedBox(height: 16),
          _infoCard('محدوده ورود پیشنهادی',
              '${signal.entryZoneLow.toStringAsFixed(0)} تا ${signal.entryZoneHigh.toStringAsFixed(0)}'),
          _infoCard('حد ضرر (Stop Loss)', signal.stopLoss.toStringAsFixed(0)),
          _infoCard('هدف قیمتی ۱', signal.takeProfit1.toStringAsFixed(0)),
          _infoCard('هدف قیمتی ۲', signal.takeProfit2.toStringAsFixed(0)),
          _infoCard('هدف قیمتی ۳', signal.takeProfit3.toStringAsFixed(0)),
          _infoCard('نسبت ریسک به ریوارد', signal.riskRewardRatio.toStringAsFixed(2)),
          _infoCard('سطح ابطال سیگنال', signal.invalidationLevel.toStringAsFixed(0)),
          const SizedBox(height: 16),
          Text('دلایل پشتیبان‌کننده سیگنال', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...signal.reasons.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r, textAlign: TextAlign.right)),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          Text('ریسک‌های کلیدی', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...signal.keyRisks.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_outlined, color: Colors.orangeAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r, textAlign: TextAlign.right)),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          const Card(
            color: Color(0x33FFFFFF),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'این تحلیل صرفاً یک ابزار کمکی است، توصیه مالی محسوب نمی‌شود و هیچ سودی را تضمین نمی‌کند. تصمیم نهایی معامله و مسئولیت آن بر عهده شماست.',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(label, textAlign: TextAlign.right),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
