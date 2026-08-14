import '../models/order_models.dart';

/// User-supplied risk configuration. Per project requirement, the user
/// enters these manually before EACH auto-trading session — there is
/// deliberately no persisted "safe default" that silently carries over,
/// so the user always makes an active, informed choice.
class RiskSettings {
  final double accountEquity; // total capital allocated to auto-trading (IRT or USDT)
  final double riskPercentPerTrade; // e.g. 1.0 = 1% of equity risked per trade
  final double maxDailyLossPercent; // e.g. 5.0 = stop trading after -5% for the day
  final double maxExposurePercent; // e.g. 30.0 = max % of equity deployed at once
  final double maxLeverage; // 1.0 = no leverage (spot only)
  final int maxOpenPositions;

  const RiskSettings({
    required this.accountEquity,
    required this.riskPercentPerTrade,
    required this.maxDailyLossPercent,
    required this.maxExposurePercent,
    required this.maxLeverage,
    required this.maxOpenPositions,
  });

  bool get isValid =>
      accountEquity > 0 &&
      riskPercentPerTrade > 0 &&
      riskPercentPerTrade <= 100 &&
      maxDailyLossPercent > 0 &&
      maxExposurePercent > 0 &&
      maxLeverage >= 1 &&
      maxOpenPositions >= 1;
}

enum TradingHaltReason {
  none,
  dailyLossLimitReached,
  exposureLimitReached,
  maxPositionsReached,
  manualPause,
}

/// Enforces the risk rules defined in [RiskSettings] against the current
/// trading session. Auto-trading MUST consult [canOpenNewPosition] before
/// every single order placement — this is the safety gate described in the
/// project spec ("pause trading automatically after predefined limits").
class RiskManager {
  RiskSettings settings;
  double _realizedPnlToday = 0;
  DateTime _sessionDate = DateTime.now();
  bool _manuallyPaused = false;

  RiskManager(this.settings);

  double get realizedPnlToday => _realizedPnlToday;
  double get realizedPnlPercentToday =>
      settings.accountEquity == 0 ? 0 : (_realizedPnlToday / settings.accountEquity) * 100;

  void _rolloverDayIfNeeded() {
    final now = DateTime.now();
    if (now.day != _sessionDate.day || now.month != _sessionDate.month || now.year != _sessionDate.year) {
      _realizedPnlToday = 0;
      _sessionDate = now;
    }
  }

  void recordClosedTradePnl(double pnl) {
    _rolloverDayIfNeeded();
    _realizedPnlToday += pnl;
  }

  void pauseManually() => _manuallyPaused = true;
  void resumeManually() => _manuallyPaused = false;

  /// Central safety gate. Call before opening any new position.
  TradingHaltReason canOpenNewPosition({
    required List<OpenPosition> currentOpenPositions,
    required double proposedPositionValue,
  }) {
    _rolloverDayIfNeeded();

    if (_manuallyPaused) return TradingHaltReason.manualPause;

    if (!settings.isValid) return TradingHaltReason.manualPause;

    final dailyLossLimit = settings.accountEquity * (settings.maxDailyLossPercent / 100);
    if (_realizedPnlToday <= -dailyLossLimit) {
      return TradingHaltReason.dailyLossLimitReached;
    }

    if (currentOpenPositions.length >= settings.maxOpenPositions) {
      return TradingHaltReason.maxPositionsReached;
    }

    final currentExposure = currentOpenPositions.fold<double>(
      0,
      (sum, p) => sum + (p.entryPrice * p.quantity),
    );
    final maxExposureValue = settings.accountEquity * (settings.maxExposurePercent / 100);
    if (currentExposure + proposedPositionValue > maxExposureValue) {
      return TradingHaltReason.exposureLimitReached;
    }

    return TradingHaltReason.none;
  }

  static String haltReasonLabelFa(TradingHaltReason reason) {
    switch (reason) {
      case TradingHaltReason.none:
        return 'مجاز به معامله';
      case TradingHaltReason.dailyLossLimitReached:
        return 'به حداکثر ضرر مجاز روزانه رسیده‌اید — معاملات خودکار متوقف شد';
      case TradingHaltReason.exposureLimitReached:
        return 'به حداکثر اکسپوژر مجاز رسیده‌اید';
      case TradingHaltReason.maxPositionsReached:
        return 'به حداکثر تعداد پوزیشن‌های باز رسیده‌اید';
      case TradingHaltReason.manualPause:
        return 'معاملات خودکار به‌صورت دستی یا به دلیل تنظیمات نامعتبر متوقف شده است';
    }
  }
}
