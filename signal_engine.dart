import 'candle.dart';
import 'trade_signal.dart';
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

class SignalEngine {
  final MarketStructureAnalyzer structureAnalyzer;
  final int minVotesRequired;
  final double minConfidenceToFire;

  SignalEngine({MarketStructureAnalyzer? structureAnalyzer,this.minVotesRequired=3,this.minConfidenceToFire=60}) : structureAnalyzer=structureAnalyzer ?? MarketStructureAnalyzer();

  TradeSignal? analyze({required String symbol,required String exchange,required List<Candle> candles}) {
    if (candles.length < 60) return null;
    final votes=< _Vote>[]; final risks=<String>[];
    final trend=Indicators.trendDirection(candles);
    if(trend=='uptrend') votes.add(_Vote('روند میان‌مدت صعودی است (شیب EMA50 مثبت)',SignalDirection.long,1.0));
    else if(trend=='downtrend') votes.add(_Vote('روند میان‌مدت نزولی است (شیب EMA50 منفی)',SignalDirection.short,1.0));
    final rsiSeries=Indicators.rsi(candles); final lastRsi=rsiSeries.last;
    if(lastRsi!=null){if(lastRsi<35) votes.add(_Vote('RSI در محدوده اشباع فروش قرار دارد (${lastRsi.toStringAsFixed(1)})',SignalDirection.long,.8)); else if(lastRsi>65) votes.add(_Vote('RSI در محدوده اشباع خرید قرار دارد (${lastRsi.toStringAsFixed(1)})',SignalDirection.short,.8)); if(lastRsi>75) risks.add('RSI بسیار بالا؛ احتمال اصلاح قیمتی وجود دارد'); if(lastRsi<25) risks.add('RSI بسیار پایین؛ احتمال ادامه فشار فروش وجود دارد');}
    final macd=Indicators.macd(candles).histogram;
    if(macd.length>=2&&macd[macd.length-1]!=null&&macd[macd.length-2]!=null){final c=macd[macd.length-1]!;final p=macd[macd.length-2]!;if(p<0&&c>0) votes.add(_Vote('هیستوگرام MACD تازه مثبت شده',SignalDirection.long,.9));else if(p>0&&c<0) votes.add(_Vote('هیستوگرام MACD تازه منفی شده',SignalDirection.short,.9));}
    final sb=structureAnalyzer.detectLatestBreak(candles);
    switch(sb){case StructureBreak.bullishBOS:votes.add(_Vote('شکست ساختار صعودی (Bullish BOS) تأیید شده',SignalDirection.long,1.2));break;case StructureBreak.bullishCHoCH:votes.add(_Vote('تغییر کاراکتر بازار به صعودی (Bullish CHoCH)',SignalDirection.long,1));break;case StructureBreak.bearishBOS:votes.add(_Vote('شکست ساختار نزولی (Bearish BOS) تأیید شده',SignalDirection.short,1.2));break;case StructureBreak.bearishCHoCH:votes.add(_Vote('تغییر کاراکتر بازار به نزولی (Bearish CHoCH)',SignalDirection.short,1));break;case StructureBreak.none:break;}
    final zones=structureAnalyzer.findSupplyDemandZones(candles);final lastPrice=candles.last.close;
    for(final z in zones.reversed.take(5)){if(lastPrice>=z.bottom&&lastPrice<=z.top){votes.add(_Vote(z.isDemand?'قیمت درون ناحیه تقاضا':'قیمت درون ناحیه عرضه',z.isDemand?SignalDirection.long:SignalDirection.short,.9));break;}}
    final pattern=CandlestickPatternDetector.detectAt(candles,candles.length-1);final bull={CandlePattern.bullishEngulfing,CandlePattern.hammer,CandlePattern.morningStar};final bear={CandlePattern.bearishEngulfing,CandlePattern.shootingStar,CandlePattern.eveningStar};
    if(bull.contains(pattern)) votes.add(_Vote('الگوی صعودی در کندل اخیر',SignalDirection.long,.7)); else if(bear.contains(pattern)) votes.add(_Vote('الگوی نزولی در کندل اخیر',SignalDirection.short,.7));
    final fib=structureAnalyzer.fibonacciRetracement(candles);final f618=fib['0.618'];final f50=fib['0.5'];if(f618!=null&&(lastPrice-f618).abs()/lastPrice<.005) votes.add(_Vote('واکنش به فیبوناچی ۰.۶۱۸',SignalDirection.long,.6)); else if(f50!=null&&(lastPrice-f50).abs()/lastPrice<.005) votes.add(_Vote('واکنش به فیبوناچی ۰.۵',SignalDirection.long,.4));
    final atr=Indicators.atr(candles).last;if(atr!=null&&atr/lastPrice>.05) risks.add('نوسان‌پذیری ATR بسیار بالاست');
    final ls=votes.where((v)=>v.direction==SignalDirection.long).fold<double>(0,(a,v)=>a+v.weight);final ss=votes.where((v)=>v.direction==SignalDirection.short).fold<double>(0,(a,v)=>a+v.weight);final lv=votes.where((v)=>v.direction==SignalDirection.long).length;final sv=votes.where((v)=>v.direction==SignalDirection.short).length;final direction=ls>ss?SignalDirection.long:SignalDirection.short;final winningVotes=direction==SignalDirection.long?lv:sv;final total=ls+ss;final win=direction==SignalDirection.long?ls:ss;if(winningVotes<minVotesRequired||total==0)return null;final confidence=(win/total*100).clamp(0,100).toDouble();if(confidence<minConfidenceToFire)return null;
    final atrNow=atr??(candles.last.high-candles.last.low);final entryLow=direction==SignalDirection.long?lastPrice-atrNow*.1:lastPrice;final entryHigh=direction==SignalDirection.long?lastPrice:lastPrice+atrNow*.1;final stop=direction==SignalDirection.long?lastPrice-atrNow*1.5:lastPrice+atrNow*1.5;final tp1=direction==SignalDirection.long?lastPrice+atrNow*1.5:lastPrice-atrNow*1.5;final tp2=direction==SignalDirection.long?lastPrice+atrNow*2.5:lastPrice-atrNow*2.5;final tp3=direction==SignalDirection.long?lastPrice+atrNow*4:lastPrice-atrNow*4;final risk=(lastPrice-stop).abs();final reward=(tp1-lastPrice).abs();risks.add('این سیگنال تضمینی برای سودآوری نیست');
    return TradeSignal(symbol:symbol,exchange:exchange,direction:direction,entryZoneLow:entryLow<entryHigh?entryLow:entryHigh,entryZoneHigh:entryLow<entryHigh?entryHigh:entryLow,stopLoss:stop,takeProfit1:tp1,takeProfit2:tp2,takeProfit3:tp3,riskRewardRatio:risk==0?0:reward/risk,confidenceScore:confidence,reasons:votes.where((v)=>v.direction==direction).map((v)=>v.reasonFa).toList(),keyRisks:risks,invalidationLevel:stop,generatedAt:DateTime.now());
  }
}
