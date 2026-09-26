import 'dart:math' as math;
import 'dart:ui';

import 'palette.dart';

/// Кэш красок: цвет палитры + шаг прозрачности (0..20).
final Map<int, Paint> _paintCache = <int, Paint>{};

Paint _fill(int color, double alpha) {
  final int a20 = (alpha * 20).round();
  final int safeA = a20 < 0 ? 0 : (a20 > 20 ? 20 : a20);
  final int key = (color & 15) * 32 + safeA;
  final Paint? cached = _paintCache[key];
  if (cached != null) {
    return cached;
  }
  final double a = safeA / 20.0;
  final Paint paint = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.fill
    ..color = a >= 1.0 ? P.get(color) : P.alpha(color, a);
  _paintCache[key] = paint;
  return paint;
}

/// Пиксельные примитивы. Все координаты — в виртуальных пикселях мира,
/// поэтому прямоугольники всегда выравниваются по пиксельной сетке.
class Px {
  Px._();

  /// Один пиксель.
  static void px(Canvas canvas, double x, double y, int color, [double alpha = 1.0]) {
    canvas.drawRect(
      Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 1, 1),
      _fill(color, alpha),
    );
  }

  /// Заполненный прямоугольник.
  static void rect(Canvas canvas, double x, double y, double w, double h, int color, [double alpha = 1.0]) {
    if (w <= 0 || h <= 0) {
      return;
    }
    canvas.drawRect(
      Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), w.roundToDouble(), h.roundToDouble()),
      _fill(color, alpha),
    );
  }

  /// Контур прямоугольника толщиной 1 пиксель.
  static void frame(Canvas canvas, double x, double y, double w, double h, int color, [double alpha = 1.0]) {
    rect(canvas, x, y, w, 1, color, alpha);
    rect(canvas, x, y + h - 1, w, 1, color, alpha);
    rect(canvas, x, y, 1, h, color, alpha);
    rect(canvas, x + w - 1, y, 1, h, color, alpha);
  }

  /// Заполненный пиксельный круг (scanline, без сглаживания).
  static void circle(Canvas canvas, double cx, double cy, double r, int color, [double alpha = 1.0]) {
    final int rr = r.round();
    if (rr <= 0) {
      px(canvas, cx, cy, color, alpha);
      return;
    }
    final int x0 = cx.round();
    final int y0 = cy.round();
    for (int y = -rr; y <= rr; y++) {
      final double inner = math.max(0.0, (rr * rr - y * y).toDouble());
      final int w = math.sqrt(inner).floor();
      rect(canvas, (x0 - w).toDouble(), (y0 + y).toDouble(), (w * 2 + 1).toDouble(), 1, color, alpha);
    }
  }

  /// Кольцо (контур круга) заданной толщины.
  static void ring(Canvas canvas, double cx, double cy, double r, double thickness, int color, [double alpha = 1.0]) {
    final int rr = r.round();
    if (rr <= 0) {
      px(canvas, cx, cy, color, alpha);
      return;
    }
    final int ri = math.max(0, rr - thickness.round());
    final int x0 = cx.round();
    final int y0 = cy.round();
    for (int y = -rr; y <= rr; y++) {
      final double outer = math.max(0.0, (rr * rr - y * y).toDouble());
      final int wo = math.sqrt(outer).floor();
      if (y >= -ri && y <= ri) {
        final double innerV = math.max(0.0, (ri * ri - y * y).toDouble());
        final int wi = math.sqrt(innerV).floor();
        final int thick = wo - wi;
        if (thick > 0) {
          rect(canvas, (x0 - wo).toDouble(), (y0 + y).toDouble(), thick.toDouble(), 1, color, alpha);
          rect(canvas, (x0 + wi + 1).toDouble(), (y0 + y).toDouble(), thick.toDouble(), 1, color, alpha);
        }
      } else {
        rect(canvas, (x0 - wo).toDouble(), (y0 + y).toDouble(), (wo * 2 + 1).toDouble(), 1, color, alpha);
      }
    }
  }

  /// Линия из пикселей (алгоритм Брезенхэма).
  static void line(Canvas canvas, double x1, double y1, double x2, double y2, int color, [double alpha = 1.0]) {
    int x = x1.round();
    int y = y1.round();
    final int xEnd = x2.round();
    final int yEnd = y2.round();
    final int dx = (xEnd - x).abs();
    final int dy = (yEnd - y).abs();
    final int sx = x < xEnd ? 1 : -1;
    final int sy = y < yEnd ? 1 : -1;
    int err = dx - dy;
    while (true) {
      px(canvas, x.toDouble(), y.toDouble(), color, alpha);
      if (x == xEnd && y == yEnd) {
        break;
      }
      final int e2 = err * 2;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
  }
}
