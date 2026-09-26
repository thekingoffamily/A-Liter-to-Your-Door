import 'dart:ui' show Color;

/// 16-цветная палитра в духе Pyxel.
///
/// Ограничение палитры 16 цветами задаёт ретро-вид и упрощает подбор цветов.
/// Значения взяты из палитры PYXEL (https://lospec.com/palette-list/pyxel).
class P {
  P._();

  /// RGB без альфы, индекс = номер цвета в палитре (0..15).
  static const List<int> rgb = <int>[
    0x000000, // 0  чёрный
    0x2b335f, // 1  тёмно-синий (асфальт ночью)
    0x7e2072, // 2  пурпурный
    0x19959c, // 3  бирюзовый
    0x8b4852, // 4  коричневый
    0x395c98, // 5  синий
    0xa9c1ff, // 6  светло-голубой
    0xeeeeee, // 7  белый
    0xd4186c, // 8  красный
    0xd38441, // 9  оранжевый
    0xe9c35b, // 10 жёлтый
    0xa3a3a3, // 11 серый
    0x70c6a9, // 12 мятный
    0x7696de, // 13 лавандовый
    0xff9798, // 14 розовый
    0xedc7b0, // 15 бежевый
  ];

  /// Непрозрачный цвет палитры.
  static Color get(int index) {
    final int v = rgb[index & 15];
    return Color(0xFF000000 | v);
  }

  /// Цвет палитры с заданной прозрачностью.
  static Color alpha(int index, double a) {
    final int v = rgb[index & 15];
    double k = a;
    if (k < 0) {
      k = 0;
    }
    if (k > 1) {
      k = 1;
    }
    final int al = (k * 255).round();
    return Color((al << 24) | v);
  }
}
