import 'dart:ui';

import 'palette.dart';

/// Спрайт, описанный «картой символов» — как `pyxel.images[0].set(...)`.
///
/// Каждый символ строки — индекс цвета палитры в hex (0..9, a..f),
/// точка или пробел — прозрачный пиксель.
///
/// Контуры всех цветов спрайта заранее собираются в [Path]: при отрисовке
/// остаётся один drawPath на цвет, а не сотни drawRect на пиксель.
class Sprite {
  Sprite(List<String> rows)
      : h = rows.length,
        w = _maxWidth(rows),
        _paths = _buildPaths(rows);

  final int w;
  final int h;
  final List<MapEntry<int, Path>> _paths;
  final Map<int, List<Paint>> _paintCache = <int, List<Paint>>{};

  static int _maxWidth(List<String> rows) {
    int maxW = 0;
    for (final String row in rows) {
      if (row.length > maxW) {
        maxW = row.length;
      }
    }
    return maxW;
  }

  static List<MapEntry<int, Path>> _buildPaths(List<String> rows) {
    final Map<int, Path> byColor = <int, Path>{};
    for (int y = 0; y < rows.length; y++) {
      final String row = rows[y];
      for (int x = 0; x < row.length; x++) {
        final int? color = _hexValue(row.codeUnitAt(x));
        if (color == null) {
          continue;
        }
        final Path path = byColor.putIfAbsent(color, () => Path());
        path.addRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1));
      }
    }
    return byColor.entries.toList(growable: false);
  }

  static int? _hexValue(int code) {
    if (code >= 0x30 && code <= 0x39) {
      return code - 0x30;
    }
    if (code >= 0x61 && code <= 0x66) {
      return code - 0x61 + 10;
    }
    if (code >= 0x41 && code <= 0x46) {
      return code - 0x41 + 10;
    }
    return null;
  }

  List<Paint> _paints(double alpha) {
    final int a20 = (alpha * 20).round();
    final int safeA = a20 < 0 ? 0 : (a20 > 20 ? 20 : a20);
    final List<Paint>? cached = _paintCache[safeA];
    if (cached != null) {
      return cached;
    }
    final double a = safeA / 20.0;
    final List<Paint> paints = <Paint>[
      for (final MapEntry<int, Path> entry in _paths)
        Paint()
          ..isAntiAlias = false
          ..style = PaintingStyle.fill
          ..color = a >= 1.0 ? P.get(entry.key) : P.alpha(entry.key, a),
    ];
    _paintCache[safeA] = paints;
    return paints;
  }

  List<Paint> _overridePaints(int color, double alpha) {
    final int key = 100 + (color & 15) * 32 + (alpha * 20).round();
    final List<Paint>? cached = _paintCache[key];
    if (cached != null) {
      return cached;
    }
    final Paint paint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.fill
      ..color = alpha >= 1.0 ? P.get(color) : P.alpha(color, alpha);
    final List<Paint> paints = <Paint>[for (int i = 0; i < _paths.length; i++) paint];
    _paintCache[key] = paints;
    return paints;
  }

  /// Нарисовать спрайт левым верхним углом в точке ([x], [y]).
  void draw(
    Canvas canvas,
    double x,
    double y, {
    bool flip = false,
    double alpha = 1.0,
    int? override,
  }) {
    if (_paths.isEmpty) {
      return;
    }
    final List<Paint> paints = override == null ? _paints(alpha) : _overridePaints(override, alpha);
    canvas.save();
    canvas.translate(x.roundToDouble(), y.roundToDouble());
    if (flip) {
      canvas.translate(w.toDouble(), 0);
      canvas.scale(-1, 1);
    }
    for (int i = 0; i < _paths.length && i < paints.length; i++) {
      canvas.drawPath(_paths[i].value, paints[i]);
    }
    canvas.restore();
  }
}

/// Иконка «капля топлива» (для HUD). Силуэт — красится через override.
final Sprite sprDrop = Sprite(<String>[
  '..0..',
  '..0..',
  '.000.',
  '00000',
  '00000',
  '.000.',
  '..0..',
]);

/// Иконка «монета» (деньги).
final Sprite sprCoin = Sprite(<String>[
  '.00000.',
  '0000000',
  '0000000',
  '0000000',
  '0000000',
  '0000000',
  '.00000.',
]);

/// Иконка «бензоколонка».
final Sprite sprPump = Sprite(<String>[
  '..0000..',
  '..0000..',
  '.000000.',
  '.0.00.0.',
  '.0.00.0.',
  '.0.00.0.',
  '.000000.',
  '.0.00.0.',
  '.000000.',
  '..0000..',
]);

/// Иконка «канистра».
final Sprite sprCanister = Sprite(<String>[
  '..0000..',
  '.0....0.',
  '..0000..',
  '.000000.',
  '.000000.',
  '.000000.',
  '.000000.',
  '.000000.',
  '.000000.',
]);

/// Иконка «дом».
final Sprite sprHome = Sprite(<String>[
  '....0....',
  '...000...',
  '..00000..',
  '.0000000.',
  '000000000',
  '000000000',
  '0000.0000',
  '000000000',
  '000000000',
]);

/// Флажок цели на мини-карте.
final Sprite sprFlag = Sprite(<String>[
  '0......',
  '00000..',
  '0000000',
  '00000..',
  '0......',
  '0......',
  '0......',
]);
