import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/trading_controller.dart';
import '../../core/risk/risk_manager.dart';

class TradingScreen extends StatefulWidget {
  const TradingScreen({super.key});

  @override
  State<TradingScreen> createState() => _TradingScreenState();
}

class _TradingScreenState extends State<TradingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _equityCtrl = TextEditingController();
  final _riskPerTradeCtrl = TextEditingController(text: '1');
  final _maxDailyLossCtrl = TextEditingController(text: '5');
  final _maxExposureCtrl = TextEditingController(text: '30');
  final _maxLeverageCtrl = TextEditingController(text: '1');
  final _maxPositionsCtrl = TextEditingController(text: '3');

  @override
  void dispose() {
    _equityCtrl.dispose();
    _riskPerTradeCtrl.dispose();
    _maxDailyLossCtrl.dispose();
    _maxExposureCtrl.dispose();
    _maxLeverageCtrl.dispose();
    _maxPositionsCtrl.dispose();
    super.dispose();
  }

  void _applySettings(TradingController controller) {
    if (!_formKey.currentState!.validate()) return;
    final settings = RiskSettings(
      accountEquity: double.parse(_equityCtrl.text),
      riskPercentPerTrade: double.parse(_riskPerTradeCtrl.text),
      maxDailyLossPercent: double.parse(_maxDailyLossCtrl.text),
      maxExposurePercent: double.parse(_maxExposureCtrl.text),
      maxLeverage: double.parse(_maxLeverageCtrl.text),
      maxOpenPositions: int.parse(_maxPositionsCtrl.text),
    );
    controller.updateRiskSettings(settings);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تنظیمات ریسک ذخیره شد.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradingController>();

    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت ریسک و معاملات خودکار')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.red.shade900.withOpacity(0.25),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '⚠️ فعال‌سازی معاملات خودکار باعث اجرای سفارش‌های واقعی با سرمایه واقعی در صرافی تبدیل می‌شود. '
                'این ابزار توصیه مالی نیست و سود تضمین نمی‌شود. لطفاً مقادیر زیر را با دقت و طبق تحمل ریسک خودتان وارد کنید.',
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _numField(_equityCtrl, 'سرمایه اختصاص‌یافته به معاملات خودکار (تومان)'),
                _numField(_riskPerTradeCtrl, 'درصد ریسک در هر معامله (٪ از سرمایه)'),
                _numField(_maxDailyLossCtrl, 'حداکثر ضرر مجاز روزانه (٪)'),
                _numField(_maxExposureCtrl, 'حداکثر اکسپوژر هم‌زمان (٪ از سرمایه)'),
                _numField(_maxLeverageCtrl, 'حداکثر اهرم مجاز (برای اسپات معمولاً ۱)'),
                _numField(_maxPositionsCtrl, 'حداکثر تعداد پوزیشن باز هم‌زمان', isInt: true),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _applySettings(controller),
            icon: const Icon(Icons.save_outlined),
            label: const Text('ذخیره تنظیمات ریسک برای این نشست'),
          ),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('فعال‌سازی معاملات خودکار', textAlign: TextAlign.right),
            subtitle: Text(
              controller.autoTradingEnabled
                  ? 'معاملات خودکار فعال است — سفارش‌های واقعی ثبت می‌شوند.'
                  : 'معاملات خودکار غیرفعال است.',
              textAlign: TextAlign.right,
            ),
            value: controller.autoTradingEnabled,
            onChanged: (v) => controller.setAutoTradingEnabled(v),
          ),
          if (controller.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(controller.lastError!,
                  style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.right),
            ),
          const Divider(height: 32),
          Text('پوزیشن‌های باز', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (controller.openPositions.isEmpty)
            const Text('در حال حاضر پوزیشن بازی وجود ندارد.', textAlign: TextAlign.right)
          else
            ...controller.openPositions.map((p) => Card(
                  child: ListTile(
                    title: Text('${p.symbol} — ${p.side.name}', textAlign: TextAlign.right),
                    subtitle: Text(
                      'ورود: ${p.entryPrice.toStringAsFixed(0)} | حجم: ${p.quantity.toStringAsFixed(4)} | حد ضرر: ${p.stopLoss.toStringAsFixed(0)}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label, {bool isInt = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: ctrl,
        textAlign: TextAlign.right,
        keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (v) {
          if (v == null || v.isEmpty) return 'این فیلد الزامی است';
          final parsed = isInt ? int.tryParse(v) : double.tryParse(v);
          if (parsed == null) return 'عدد معتبر وارد کنید';
          if (parsed <= 0) return 'باید بزرگ‌تر از صفر باشد';
          return null;
        },
      ),
    );
  }
}
