import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/trading_controller.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/trading/trading_screen.dart';
import 'screens/portfolio/portfolio_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() {
  runApp(const CryptoTraderApp());
}

class CryptoTraderApp extends StatelessWidget {
  const CryptoTraderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TradingController()..loadCredentials(),
      child: MaterialApp(
        title: 'دستیار تحلیل و معاملات کریپتو',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa', 'IR'),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF10B981),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0B0F14),
          // To use a Persian font like Vazirmatn: add the .ttf files under
          // assets/fonts/, register them in pubspec.yaml under `fonts:`,
          // then set fontFamily: 'Vazirmatn' here.
        ),
        home: const RootShell(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    TradingScreen(),
    PortfolioScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(child: _screens[_index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'داشبورد'),
            NavigationDestination(icon: Icon(Icons.auto_graph), label: 'معاملات'),
            NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'پورتفولیو'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
          ],
        ),
      ),
    );
  }
}
