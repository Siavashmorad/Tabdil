import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/tabdeal_api_service.dart';
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
  bool _testing = false;
  String? _connectionStatus;

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _apiSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _testAndSave(TradingController controller) async {
    final key = _apiKeyCtrl.text.trim();
    final secret = _apiSecretCtrl.text.trim();
    if (key.isEmpty || secret.isEmpty) {
      setState(() => _connectionStatus = 'API Key و API Secret را وارد کنید.');
      return;
    }

    setState(() {
      _testing = true;
      _connectionStatus = 'در حال تست اتصال به api1.tabdeal.org...';
    });

    final api = TabdealApiService(apiKey: key, apiSecret: secret);
    try {
      final ok = await api.ping();
      if (!ok) throw StateError('Ping failed');
      await controller.saveCredentials(key, secret);
      if (!mounted) return;
      setState(() {
        _testing = false;
        _connectionStatus = 'اتصال موفق به API تبدیل برقرار شد. ✅';
      });
      _apiKeyCtrl.clear();
      _apiSecretCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _connectionStatus = 'اتصال ناموفق: $e';
      });
    } finally {
      api.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradingController>();

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'اتصال به صرافی تبدیل',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.blueGrey.shade900.withOpacity(0.3),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'API Key و API Secret فقط روی گوشی و با flutter_secure_storage ذخیره می‌شوند. '
                'دسترسی Withdraw را برای کلید API فعال نکنید. آدرس REST برنامه: '
                'https://api1.tabdeal.org/r/api/v1\n\n'
                'Build verification: API1-6419764',
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyCtrl,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _testing ? null : () => _testAndSave(controller),
              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_done_outlined),
              label: Text(_testing ? 'در حال اتصال...' : 'تست اتصال و ذخیره امن'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await controller.clearCredentials();
              if (mounted) {
                setState(() => _connectionStatus = 'کلیدهای API حذف شدند.');
              }
            },
            child: const Text('حذف کلیدهای ذخیره‌شده'),
          ),
          if (_connectionStatus != null) ...[
            const SizedBox(height: 8),
            Text(
              _connectionStatus!,
              textAlign: TextAlign.right,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            controller.hasApiCredentials
                ? 'اعتبارنامه ذخیره‌شده: موجود'
                : 'اعتبارنامه ذخیره‌شده: موجود نیست',
            textAlign: TextAlign.right,
          ),
          const Divider(height: 32),
          Text(
            'لیست رصد بازار',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: controller.watchlist
                .map(
                  (s) => Chip(
                    label: Text(s),
                    onDeleted: () => setState(() => controller.watchlist.remove(s)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.orange.shade900.withOpacity(0.2),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'محدودیت مهم: اسکن بازار و معاملات خودکار فقط زمانی انجام می‌شوند که برنامه باز و در حال اجرا باشد.',
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
