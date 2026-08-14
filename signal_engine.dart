import '../models/candle.dart';
import '../models/trade_signal.dart';
import 'indicators.dart';
import 'market_structure.dart';
import 'candlestick_patterns.dart';

/// A single vote cast by one analysis method toward the final ensemble
/// decision. `weight` lets some methods count more than others.
class _Vote {
  final String reasonFa;
  final SignalDirection direction;
  final double weight;
  _Vote(this.reasonFa, this.direction, this.weight);
}

/// Combines multiple independent technical methods (trend, momentum,
/// structure, candlestick patterns, Fibonacci confluence, volatility) into
/// a single ensemble trade signal, per the project requirement that a
/// signal only fires when multiple independent conditions align.
///
/// This does NOT use machine learning (see README for why: on-device ML
/// training/inference at production quality is out of scope for a
/// phone-only, no-backend build). It is a transparent, rule-based ensemble,
/// which is arguably more auditable for a personal trading tool anyway.
class SignalEngine {
  final MarketStructureAnalyzer structureAnalyzer;
  final int minVotesRequired;
  final double minConfidenceToFire;

  SignalEngine({
    MarketStructureAnalyzer? structureAnalyzer,
    this.minVotesRequired = 3,
    this.minConfidenceToFire = 60,
  }) : structureAnalyzer = structureAnalyzer ?? MarketStructureAnalyzer();

  /// Runs the full ensemble against [candles] (oldest -> newest) for
  /// [symbol] and returns a [TradeSignal] if conditions align, or null if
  /// there isn't enough confluence to justify a trade idea.
  TradeSignal? analyze({
    required String symbol,
    required String exchange,
    required List<Candle> candles,
  }) {
    if (candles.length < 60) return null; // not enough history for reliable reads

    final votes = <_Vote>[];
    final risks = <String>[];

    // --- 1. Trend (EMA50 slope) ---
    final trend = Indicators.trendDirection(candles);
    if (trend == 'uptrend') {
      votes.add(_Vote('روند میان‌مدت صعودی است (شیب EMA50 مثبت)', SignalDirection.long, 1.0));
    } else if (trend == 'downtrend') {
      votes.add(_Vote('روند میان‌مدت نزولی است (شیب EMA50 منفی)', SignalDirection.short, 1.0));
    }

    // --- 2. Momentum (RSI) ---
    final rsiSeries = Indicators.rsi(candles);
    final lastRsi = rsiSeries.last;
    if (lastRsi != null) {
      if (lastRsi < 35) {
        votes.add(_Vote('RSI در محدوده اشباع فروش قرار دارد (${lastRsi.toStringAsFixed(1)})',
            SignalDirection.long, 0.8));
      } else if (lastRsi > 65) {
        votes.add(_Vote('RSI در محدوده اشباع خرید قرار دارد (${lastRsi.toStringAsFixed(1)})',
            SignalDirection.short, 0.8));
      }
      if (lastRsi > 75) risks.add('RSI بسیار بالا؛ احتمال اصلاح قیمتی وجود دارد');
      if (lastRsi < 25) risks.add('RSI بسیار پایین؛ احتمال ادامه فشار فروش وجود دارد');
    }

    // --- 3. MACD momentum shift ---
    final macdResult = Indicators.macd(candles);
    final hist = macdResult.histogram;
    if (hist.length >= 2 && hist[hist.length - 1] != null && hist[hist.length - 2] != null) {
      final curr = hist[hist.length - 1]!;
      final prev = hist[hist.length - 2]!;
      if (prev < 0 && curr > 0) {
        votes.add(_Vote('هیستوگرام MACD تازه مثبت شده (شتاب صعودی)', SignalDirection.long, 0.9));
      } else if (prev > 0 && curr < 0) {
        votes.add(_Vote('هیستوگرام MACD تازه منفی شده (شتاب نزولی)', SignalDirection.short, 0.9));
      }
    }

    // --- 4. Market structure (SMC-style BOS/CHoCH) ---
    final structureBreak = structureAnalyzer.detectLatestBreak(candles);
    switch (structureBreak) {
      case StructureBreak.bullishBOS:
        votes.add(_Vote('شکست ساختار صعودی (Bullish BOS) تأیید شده', SignalDirection.long, 1.2));
        break;
      case StructureBreak.bullishCHoCH:
        votes.add(_Vote('تغییر کاراکتر بازار به صعودی (Bullish CHoCH)', SignalDirection.long, 1.0));
        risks.add('CHoCH یک سیگنال بازگشتی زودهنگام است و ریسک شکست کاذب دارد');
        break;
      case StructureBreak.bearishBOS:
        votes.add(_Vote('شکست ساختار نزولی (Bearish BOS) تأیید شده', SignalDirection.short, 1.2));
        break;
      case StructureBreak.bearishCHoCH:
        votes.add(_Vote('تغییر کاراکتر بازار به نزولی (Bearish CHoCH)', SignalDirection.short, 1.0));
        risks.add('CHoCH یک سیگنال بازگشتی زودهنگام است و ریسک شکست کاذب دارد');
        break;
      case StructureBreak.none:
        break;
    }

    // --- 5. Supply/Demand zone proximity ---
    final zones = structureAnalyzer.findSupplyDemandZones(candles);
    final lastPrice = candles.last.close;
    for (final zone in zones.reversed.take(5)) {
      final withinZone = lastPrice >= zone.bottom && lastPrice <= zone.top;
      if (withinZone && zone.isDemand) {
        votes.add(_Vote('قیمت درون یک ناحیه تقاضا (Demand Zone) قرار دارد', SignalDirection.long, 0.9));
        break;
      } else if (withinZone && !zone.isDemand) {
        votes.add(_Vote('قیمت درون یک ناحیه عرضه (Supply Zone) قرار دارد', SignalDirection.short, 0.9));
        break;
      }
    }

    // --- 6. Candlestick pattern at latest candle ---
    final pattern = CandlestickPatternDetector.detectAt(candles, candles.length - 1);
    final bullishPatterns = {CandlePattern.bullishEngulfing, CandlePattern.hammer, CandlePattern.morningStar};
    final bearishPatterns = {CandlePattern.bearishEngulfing, CandlePattern.shootingStar, CandlePattern.eveningStar};
    if (bullishPatterns.contains(pattern)) {
      votes.add(_Vote(
          '${CandlestickPatternDetector.patternLabelFa(pattern)} در کندل اخیر شکل گرفته',
          SignalDirection.long,
          0.7));
    } else if (bearishPatterns.contains(pattern)) {
      votes.add(_Vote(
          '${CandlestickPatternDetector.patternLabelFa(pattern)} در کندل اخیر شکل گرفته',
          SignalDirection.short,
          0.7));
    }

    // --- 7. Fibonacci confluence ---
    final fib = structureAnalyzer.fibonacciRetracement(candles);
    if (fib.isNotEmpty) {
      final fib618 = fib['0.618'];
      final fib50 = fib['0.5'];
      if (fib618 != null && (lastPrice - fib618).abs() / lastPrice < 0.005) {
        votes.add(_Vote('قیمت به محدوده فیبوناچی ۰.۶۱۸ واکنش نشان داده', SignalDirection.long, 0.6));
      } else if (fib50 != null && (lastPrice - fib50).abs() / lastPrice < 0.005) {
        votes.add(_Vote('قیمت به محدوده فیبوناچی ۰.۵ واکنش نشان داده', SignalDirection.long, 0.4));
      }
    }

    // --- 8. Volatility check (risk note only, not a vote) ---
    final atrSeries = Indicators.atr(candles);
    final lastAtr = atrSeries.last;
    if (lastAtr != null && lastAtr / lastPrice > 0.05) {
      risks.add('نوسان‌پذیری (ATR) بسیار بالاست؛ ریسک نوسان شدید قیمت وجود دارد');
    }

    // --- Tally votes ---
    final longScore = votes.where((v) => v.direction == SignalDirection.long).fold(0.0, (a, v) => a + v.weight);
    final shortScore = votes.where((v) => v.direction == SignalDirection.short).fold(0.0, (a, v) => a + v.weight);
    final longVotes = votes.where((v) => v.direction == SignalDirection.long).length;
    final shortVotes = votes.where((v) => v.direction == SignalDirection.short).length;

    final direction = longScore > shortScore ? SignalDirection.long : SignalDirection.short;
    final winningVotes = direction == SignalDirection.long ? longVotes : shortVotes;
    final totalScore = longScore + shortScore;
    final winningScore = direction == SignalDirection.long ? longScore : shortScore;

    if (winningVotes < minVotesRequired || totalScore == 0) {
      return null; // not enough independent confluence — per spec, no signal
    }

    final confidence = ((winningScore / (totalScore == 0 ? 1 : totalScore)) * 100)
        .clamp(0, 100)
        .toDouble();

    if (confidence < minConfidenceToFire) return null;

    // --- Build entry/SL/TP using ATR-based structure ---
    final atrNow = lastAtr ?? (candles.last.high - candles.last.low);
    final entryLow = direction == SignalDirection.long ? lastPrice - atrNow * 0.1 : lastPrice;
    final entryHigh = direction == SignalDirection.long ? lastPrice : lastPrice + atrNow * 0.1;
    final stopLoss = direction == SignalDirection.long
        ? lastPrice - atrNow * 1.5
        : lastPrice + atrNow * 1.5;
    final tp1 = direction == SignalDirection.long ? lastPrice + atrNow * 1.5 : lastPrice - atrNow * 1.5;
    final tp2 = direction == SignalDirection.long ? lastPrice + atrNow * 2.5 : lastPrice - atrNow * 2.5;
    final tp3 = direction == SignalDirection.long ? lastPrice + atrNow * 4.0 : lastPrice - atrNow * 4.0;
    final invalidation = stopLoss;

    final riskAmount = (lastPrice - stopLoss).abs();
    final rewardAmount = (tp1 - lastPrice).abs();
    final rr = riskAmount == 0 ? 0.0 : rewardAmount / riskAmount;

    risks.add('این سیگنال تضمینی برای سودآوری نیست و صرفاً بر اساس تحلیل تکنیکال گذشته‌نگر است');

    return TradeSignal(
      symbol: symbol,
      exchange: exchange,
      direction: direction,
      entryZoneLow: entryLow < entryHigh ? entryLow : entryHigh,
      entryZoneHigh: entryLow < entryHigh ? entryHigh : entryLow,
      stopLoss: stopLoss,
      takeProfit1: tp1,
      takeProfit2: tp2,
      takeProfit3: tp3,
      riskRewardRatio: rr,
      confidenceScore: confidence,
      reasons: votes.where((v) => v.direction == direction).map((v) => v.reasonFa).toList(),
      keyRisks: risks,
      invalidationLevel: invalidation,
      generatedAt: DateTime.now(),
    );
  }
}
