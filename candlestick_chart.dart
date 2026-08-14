import 'package:flutter/material.dart';
import '../core/models/candle.dart';
import '../core/models/trade_signal.dart';

/// Renders an OHLC candlestick chart (drawn manually via CustomPaint inside
/// a BarChart-compatible coordinate space, since fl_chart has no native
/// candlestick widget) with optional overlay lines for entry/SL/TP levels.
class CandlestickChart extends StatelessWidget {
  final List<Candle> candles;
  final TradeSignal? signal;
  final int maxCandles;

  const CandlestickChart({
    super.key,
    required this.candles,
    this.signal,
    this.maxCandles = 60,
  });

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(child: Text('داده‌ای برای نمایش نمودار موجود نیست')),
      );
    }

    final visible = candles.length > maxCandles
        ? candles.sublist(candles.length - maxCandles)
        : candles;

    final minLow = visible.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final maxHigh = visible.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final padding = (maxHigh - minLow) * 0.08;

    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
        child: CustomPaint(
          size: Size.infinite,
          painter: _CandlestickPainter(
            candles: visible,
            minY: minLow - padding,
            maxY: maxHigh + padding,
            signal: signal,
          ),
        ),
      ),
    );
  }
}

class _CandlestickPainter extends CustomPainter {
  final List<Candle> candles;
  final double minY;
  final double maxY;
  final TradeSignal? signal;

  _CandlestickPainter({
    required this.candles,
    required this.minY,
    required this.maxY,
    this.signal,
  });

  double _yFor(double price, double height) {
    final range = (maxY - minY) == 0 ? 1 : (maxY - minY);
    return height - ((price - minY) / range) * height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width;
    final chartHeight = size.height;
    final slotWidth = chartWidth / candles.length;
    final bodyWidth = slotWidth * 0.6;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = chartHeight / 4 * i;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    // Candles
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final centerX = slotWidth * i + slotWidth / 2;
      final color = c.isBullish ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
      final paint = Paint()..color = color;

      final highY = _yFor(c.high, chartHeight);
      final lowY = _yFor(c.low, chartHeight);
      canvas.drawLine(Offset(centerX, highY), Offset(centerX, lowY), paint..strokeWidth = 1.5);

      final openY = _yFor(c.open, chartHeight);
      final closeY = _yFor(c.close, chartHeight);
      final top = openY < closeY ? openY : closeY;
      final bottom = openY < closeY ? closeY : openY;
      final rect = Rect.fromLTRB(
        centerX - bodyWidth / 2,
        top,
        centerX + bodyWidth / 2,
        bottom == top ? top + 1 : bottom,
      );
      canvas.drawRect(rect, Paint()..color = color);
    }

    // Signal overlay lines (entry / SL / TPs)
    if (signal != null) {
      _drawLevelLine(canvas, chartWidth, chartHeight, signal!.entryMid, 'ورود', Colors.white);
      _drawLevelLine(canvas, chartWidth, chartHeight, signal!.stopLoss, 'حد ضرر', Colors.redAccent);
      _drawLevelLine(canvas, chartWidth, chartHeight, signal!.takeProfit1, 'TP1', Colors.greenAccent);
      _drawLevelLine(canvas, chartWidth, chartHeight, signal!.takeProfit2, 'TP2', Colors.greenAccent.shade700);
      _drawLevelLine(canvas, chartWidth, chartHeight, signal!.takeProfit3, 'TP3', Colors.green.shade900);
    }
  }

  void _drawLevelLine(Canvas canvas, double width, double height, double price, String label, Color color) {
    if (price < minY || price > maxY) return;
    final y = _yFor(price, height);
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    _drawDashedLine(canvas, Offset(0, y), Offset(width, y), paint);

    final textPainter = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: color, fontSize: 10)),
      textDirection: TextDirection.rtl,
    )..layout();
    textPainter.paint(canvas, Offset(4, y - 12));
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final dx = end.dx - start.dx;
    final distance = dx.abs();
    double covered = 0;
    while (covered < distance) {
      final x1 = start.dx + covered;
      final x2 = (x1 + dashWidth).clamp(start.dx, end.dx);
      canvas.drawLine(Offset(x1, start.dy), Offset(x2, start.dy), paint);
      covered += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return oldDelegate.candles != candles || oldDelegate.signal != signal;
  }
}
