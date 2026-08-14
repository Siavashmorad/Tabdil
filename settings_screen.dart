import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/trading_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _apiSecretCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _apiSecretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradingController>();

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('اتصال به صرافی تبدیل', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.right),
          const SizedBox(height: 8),
          Card(
            color: Colors.blueGrey.shade900.withOpacity(0.3),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'کلیدهای API را فقط با دسترسی «معامله» (Trade) بسازید و هرگز دسترسی «برداشت» (Withdraw) را فعال نکنید. '
                'کلیدها به‌صورت رمزنگاری‌شده روی همین گوشی ذخیره می‌شوند و به هیچ سروری ارسال نمی‌شوند.',
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyCtrl,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiSecretCtrl,
            textAlign: TextAlign.right,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'API Secret',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    if (_apiKeyCtrl.text.isEmpty || _apiSecretCtrl.text.isEmpty) return;
                    await controller.saveCredentials(_apiKeyCtrl.text, _apiSecretCtrl.text);
                    _apiKeyCtrl.clear();
                    _apiSecretCtrl.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('کلیدهای API ذخیره شد.')),
                      );
                    }
                  },
                  child: const Text('ذخیره'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await controller.clearCredentials();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('کلیدهای API حذف شد.')),
                    );
                  }
                },
                child: const Text('حذف'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            controller.hasApiCredentials ? 'وضعیت: متصل ✅' : 'وضعیت: متصل نیست',
            textAlign: TextAlign.right,
          ),
          const Divider(height: 32),
          Text('لیست رصد بازار', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.right),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: controller.watchlist
                .map((s) => Chip(
                      label: Text(s),
                      onDeleted: () => setState(() => controller.watchlist.remove(s)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.orange.shade900.withOpacity(0.2),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'محدودیت مهم: از آنجا که این برنامه فقط داخل گوشی و بدون سرور اجرا می‌شود، اسکن بازار، تحلیل و معاملات خودکار '
                'فقط زمانی انجام می‌شود که برنامه باز و در حال اجراست. اندروید ممکن است در پس‌زمینه اپ را متوقف کند.',
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
