import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/trading_controller.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradingController>();
    final riskManager = controller.riskManager;

    return Scaffold(
      appBar: AppBar(title: const Text('پورتفولیو و عملکرد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('سود/زیان محقق‌شده امروز', textAlign: TextAlign.right),
                  const SizedBox(height: 4),
                  Text(
                    '${riskManager.realizedPnlToday.toStringAsFixed(0)} تومان (${riskManager.realizedPnlPercentToday.toStringAsFixed(2)}٪)',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: riskManager.realizedPnlToday >= 0 ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('پوزیشن‌های باز (${controller.openPositions.length})',
              style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.right),
          const SizedBox(height: 8),
          if (controller.openPositions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('پوزیشن باز فعالی وجود ندارد.', textAlign: TextAlign.right),
            )
          else
            ...controller.openPositions.map((p) => Card(
                  child: ListTile(
                    title: Text('${p.symbol} — ${p.side.name}', textAlign: TextAlign.right),
                    subtitle: Text(
                      'ورود: ${p.entryPrice.toStringAsFixed(0)} | حجم: ${p.quantity.toStringAsFixed(4)}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          Text('تاریخچه معاملات بسته‌شده (${controller.closedPositions.length})',
              style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.right),
          const SizedBox(height: 8),
          if (controller.closedPositions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('هنوز معامله بسته‌شده‌ای ثبت نشده است.', textAlign: TextAlign.right),
            )
          else
            ...controller.closedPositions.reversed.map((p) {
              final pnl = p.closePrice != null ? p.unrealizedPnl(p.closePrice!) : 0.0;
              return Card(
                child: ListTile(
                  title: Text('${p.symbol} — ${p.side.name}', textAlign: TextAlign.right),
                  subtitle: Text(
                    'ورود: ${p.entryPrice.toStringAsFixed(0)} → خروج: ${p.closePrice?.toStringAsFixed(0) ?? '-'}',
                    textAlign: TextAlign.right,
                  ),
                  trailing: Text(
                    pnl.toStringAsFixed(0),
                    style: TextStyle(color: pnl >= 0 ? Colors.greenAccent : Colors.redAccent),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
