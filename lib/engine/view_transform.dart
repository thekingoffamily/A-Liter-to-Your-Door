import 'dart:math' as math;
import 'dart:ui';

import 'constants.dart';

/// Пересчёт координат: экран -> виртуальные пиксели вида.
///
/// Масштаб всегда целочисленный (пиксель остаётся квадратным и чётким),
/// а высота вида подстраивается под экран, поэтому чёрных полос сверху и
/// снизу нет — остаётся только небольшая рамка по бокам на необычных экранах.
class ViewTransform {
  ViewTransform(this.size) {
    double s = math.min(size.width / kWorldW, size.height / kWorldH);
    if (s > 1.0) {
      s = s.floorToDouble();
    }
    if (s < 0.2) {
      s = 0.2;
    }
    scale = s;

    double h = size.height / s;
    if (h < kMinWorldH) {
      h = kMinWorldH;
    }
    if (h > kMaxWorldH) {
      h = kMaxWorldH;
    }
    worldH = h;

    offsetX = (size.width - kWorldW * s) / 2.0;
    offsetY = (size.height - worldH * s) / 2.0;
  }

  final Size size;
  late final double scale;
  late final double worldH;
  late final double offsetX;
  late final double offsetY;

  /// Экранные координаты -> координаты вида (с учётом чёрных полей).
  Offset toVirtual(Offset position) {
    return Offset((position.dx - offsetX) / scale, (position.dy - offsetY) / scale);
  }
}
