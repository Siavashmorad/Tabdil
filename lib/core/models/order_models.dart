class OrderBookLevel {
  final double price;
  final double quantity;
  const OrderBookLevel({required this.price, required this.quantity});
}

class OrderBook {
  final List<OrderBookLevel> bids;
  final List<OrderBookLevel> asks;
  const OrderBook({this.bids = const [], this.asks = const []});
}
