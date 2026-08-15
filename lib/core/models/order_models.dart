enum OrderSide { buy, sell }

enum OrderType { market, limit, stopLossLimit }

enum OrderStatus { new_, partiallyFilled, filled, canceled, rejected, unknown }

class TabdealOrder {
  final String symbol;
  final int? orderId;
  final OrderSide side;
  final OrderType type;
  final double origQty;
  final double executedQty;
  final double price;
  final OrderStatus status;
  final DateTime? transactTime;

  const TabdealOrder({
    required this.symbol,
    this.orderId,
    required this.side,
    required this.type,
    required this.origQty,
    required this.executedQty,
    required this.price,
    required this.status,
    this.transactTime,
  });

  factory TabdealOrder.fromJson(Map<String, dynamic> json) {
    return TabdealOrder(
      symbol: json['symbol'] as String? ?? '',
      orderId: json['orderId'] as int?,
      side: json['side'] == 'SELL' ? OrderSide.sell : OrderSide.buy,
      type: _parseType(json['type'] as String?),
      origQty: double.tryParse(json['origQty']?.toString() ?? '0') ?? 0,
      executedQty: double.tryParse(json['executedQty']?.toString() ?? '0') ?? 0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      status: _parseStatus(json['status'] as String?),
      transactTime: json['transactTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['transactTime'] as int)
          : null,
    );
  }

  static OrderType _parseType(String? raw) {
    switch (raw) {
      case 'MARKET': return OrderType.market;
      case 'STOP_LOSS_LIMIT': return OrderType.stopLossLimit;
      default: return OrderType.limit;
    }
  }

  static OrderStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'NEW': return OrderStatus.new_;
      case 'PARTIALLY_FILLED': return OrderStatus.partiallyFilled;
      case 'FILLED': return OrderStatus.filled;
      case 'CANCELED': return OrderStatus.canceled;
      case 'REJECTED': return OrderStatus.rejected;
      default: return OrderStatus.unknown;
    }
  }
}

class OpenPosition {
  final String id;
  final String symbol;
  final OrderSide side;
  final double entryPrice;
  final double quantity;
  final double stopLoss;
  final double takeProfit1;
  final double takeProfit2;
  final double takeProfit3;
  final DateTime openedAt;
  int? entryOrderId;
  int? stopOrderId;
  bool closed;
  double? closePrice;
  DateTime? closedAt;

  OpenPosition({
    required this.id,
    required this.symbol,
    required this.side,
    required this.entryPrice,
    required this.quantity,
    required this.stopLoss,
    required this.takeProfit1,
    required this.takeProfit2,
    required this.takeProfit3,
    required this.openedAt,
    this.entryOrderId,
    this.stopOrderId,
    this.closed = false,
    this.closePrice,
    this.closedAt,
  });

  double unrealizedPnl(double currentPrice) {
    final diff = side == OrderSide.buy ? currentPrice - entryPrice : entryPrice - currentPrice;
    return diff * quantity;
  }

  double unrealizedPnlPercent(double currentPrice) {
    if (entryPrice == 0) return 0;
    final diff = side == OrderSide.buy ? currentPrice - entryPrice : entryPrice - currentPrice;
    return (diff / entryPrice) * 100;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'symbol': symbol, 'side': side.name,
    'entryPrice': entryPrice, 'quantity': quantity,
    'stopLoss': stopLoss, 'takeProfit1': takeProfit1,
    'takeProfit2': takeProfit2, 'takeProfit3': takeProfit3,
    'openedAt': openedAt.toIso8601String(),
    'entryOrderId': entryOrderId, 'stopOrderId': stopOrderId,
    'closed': closed, 'closePrice': closePrice,
    'closedAt': closedAt?.toIso8601String(),
  };

  factory OpenPosition.fromJson(Map<String, dynamic> json) => OpenPosition(
    id: json['id'] as String,
    symbol: json['symbol'] as String,
    side: json['side'] == 'sell' ? OrderSide.sell : OrderSide.buy,
    entryPrice: (json['entryPrice'] as num).toDouble(),
    quantity: (json['quantity'] as num).toDouble(),
    stopLoss: (json['stopLoss'] as num).toDouble(),
    takeProfit1: (json['takeProfit1'] as num).toDouble(),
    takeProfit2: (json['takeProfit2'] as num).toDouble(),
    takeProfit3: (json['takeProfit3'] as num).toDouble(),
    openedAt: DateTime.parse(json['openedAt'] as String),
    entryOrderId: json['entryOrderId'] as int?,
    stopOrderId: json['stopOrderId'] as int?,
    closed: json['closed'] as bool? ?? false,
    closePrice: (json['closePrice'] as num?)?.toDouble(),
    closedAt: json['closedAt'] != null ? DateTime.parse(json['closedAt'] as String) : null,
  );
}
