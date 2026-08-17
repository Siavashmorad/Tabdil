import 'dart:math' as math;
import '../api/tabdeal_api_service.dart';

class LiveSignal {
  final String symbol;
  final String direction;
  final double entry;
  final double stopLoss;
  final double takeProfit1;
  final double takeProfit2;
  final double score;
  final double riskReward;
  final double spreadPercent;
  final String reason;

  const LiveSignal({required this.symbol, required this.direction, required this.entry, required this.stopLoss, required this.takeProfit1, required this.takeProfit2, required this.score, required this.riskReward, required this.spreadPercent, required this.reason});
}

/// Signal-only scanner. It never places an order.
class LiveSignalScanner {
  final TabdealApiService api;
  LiveSignalScanner({TabdealApiService? api}) : api = api ?? TabdealApiService();

  double _number(dynamic value) => double.tryParse('$value') ?? 0;
  List<List<dynamic>> _levels(dynamic value) => value is List ? value.whereType<List>().where((e) => e.length >= 2).toList() : const [];
  String? _symbol(Map<String, dynamic> info) => (info['symbol'] ?? info['s'] ?? info['market'])?.toString();
  bool _active(Map<String, dynamic> info) {
    final status = '${info['status'] ?? 'TRADING'}'.toUpperCase();
    return status.isEmpty || status == 'TRADING' || status == 'ACTIVE' || status == '1';
  }

  Future<LiveSignal?> scanBest({int maxMarkets = 30}) async {
    final markets = await api.exchangeInfo();
    final candidates = markets.where(_active).map(_symbol).whereType<String>().where((s) => s.toUpperCase().contains('USDT') || s.toUpperCase().contains('IRT')).take(maxMarkets).toList();
    LiveSignal? best;
    for (final symbol in candidates) {
      try {
        final signal = await _analyze(symbol);
        if (signal != null && (best == null || signal.score > best.score)) best = signal;
      } catch (_) {}
    }
    return best;
  }

  Future<LiveSignal?> _analyze(String symbol) async {
    final results = await Future.wait([api.trades(symbol, limit: 120), api.depth(symbol, limit: 20)]);
    final trades = results[0] as List<Map<String, dynamic>>;
    final book = results[1] as Map<String, dynamic>;
    if (trades.length < 12) return null;
    final bids = _levels(book['bids']);
    final asks = _levels(book['asks']);
    if (bids.isEmpty || asks.isEmpty) return null;

    final bestBid = _number(bids.first[0]);
    final bestAsk = _number(asks.first[0]);
    if (bestBid <= 0 || bestAsk <= 0 || bestAsk < bestBid) return null;
    final mid = (bestBid + bestAsk) / 2;
    final spread = (bestAsk - bestBid) / mid * 100;
    if (spread > 1.0) return null;

    final prices = <double>[];
    double buyQty = 0, sellQty = 0;
    for (final trade in trades) {
      final price = _number(trade['price'] ?? trade['p']);
      final qty = _number(trade['qty'] ?? trade['quantity'] ?? trade['q']);
      if (price > 0) prices.add(price);
      final maker = trade['isBuyerMaker'] ?? trade['m'];
      if (maker == true || maker == 'true') sellQty += qty; else buyQty += qty;
    }
    if (prices.length < 12) return null;

    final first = prices.first, last = prices.last;
    final momentum = first == 0 ? 0 : (last - first) / first;
    final recent = prices.sublist(math.max(0, prices.length - 20));
    final recentMean = recent.reduce((a, b) => a + b) / recent.length;
    final recentMove = recentMean == 0 ? 0 : (last - recentMean) / recentMean;

    double bidDepth = 0, askDepth = 0;
    for (final level in bids.take(10)) bidDepth += _number(level[1]);
    for (final level in asks.take(10)) askDepth += _number(level[1]);
    final depthTotal = bidDepth + askDepth;
    final imbalance = depthTotal == 0 ? 0 : (bidDepth - askDepth) / depthTotal;
    final tradeTotal = buyQty + sellQty;
    final flow = tradeTotal == 0 ? 0 : (buyQty - sellQty) / tradeTotal;

    final directionScore = momentum * 100 + recentMove * 120 + imbalance * 35 + flow * 35;
    final direction = directionScore >= 0 ? 'LONG' : 'SHORT';
    final strength = directionScore.abs();
    if (strength < 4) return null;

    final returns = <double>[];
    for (var i = 1; i < prices.length; i++) if (prices[i - 1] > 0) returns.add((prices[i] - prices[i - 1]).abs() / prices[i - 1]);
    final volatility = returns.isEmpty ? 0.002 : returns.reduce((a, b) => a + b) / returns.length;
    final riskPct = math.max(0.0035, math.min(0.02, volatility * 4 + spread / 100));
    final rewardPct = riskPct * 1.8;
    final entry = direction == 'LONG' ? bestAsk : bestBid;
    final stop = direction == 'LONG' ? entry * (1 - riskPct) : entry * (1 + riskPct);
    final tp1 = direction == 'LONG' ? entry * (1 + rewardPct) : entry * (1 - rewardPct);
    final tp2 = direction == 'LONG' ? entry * (1 + rewardPct * 1.7) : entry * (1 - rewardPct * 1.7);
    final score = math.min(100.0, 45 + strength * 3 + imbalance.abs() * 15 + flow.abs() * 15 - spread * 5);

    return LiveSignal(symbol: symbol, direction: direction, entry: entry, stopLoss: stop, takeProfit1: tp1, takeProfit2: tp2, score: score, riskReward: rewardPct / riskPct, spreadPercent: spread, reason: 'مومنتوم کوتاه‌مدت، جریان معاملات و عدم‌تعادل Order Book هم‌جهت شده‌اند.');
  }

  void dispose() => api.dispose();
}
