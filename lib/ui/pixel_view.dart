import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/city.dart';
import '../engine/constants.dart';
import '../engine/effects.dart';
import '../engine/game.dart';
import '../engine/palette.dart';
import '../engine/pixels.dart';
import '../engine/stations.dart';
import '../engine/view_transform.dart';

/// Отрисовка игрового мира и HUD.
///
/// Мир рисуется в виртуальном разрешении [kWorldW] x [ViewTransform.worldH]
/// и масштабируется целым числом — как экран ретро-консоли.
class PixelView extends StatelessWidget {
  const PixelView({super.key, required this.engine, required this.transform});

  final GameEngine engine;
  final ViewTransform transform;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PixelPainter(engine, transform),
      size: Size.infinite,
    );
  }
}

/// Художник кадра: мир в виртуальных пикселях + HUD.
class PixelPainter extends CustomPainter {
  PixelPainter(this.engine, this.transform) : super(repaint: engine);

  final GameEngine engine;
  final ViewTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = P.get(0));

    canvas.save();
    canvas.translate(transform.offsetX, transform.offsetY);
    canvas.scale(transform.scale);

    canvas.save();
    canvas.translate(-engine.camX, -engine.camY);
    _drawWorld(canvas);
    canvas.restore();

    if (engine.scene != GameScene.title) {
      _drawHud(canvas);
    }
    _drawBanners(canvas);
    if (engine.scene == GameScene.playing && !engine.paused) {
      _drawJoystick(canvas);
    }

    canvas.restore();
  }

  // --- Мир -----------------------------------------------------------------

  void _drawWorld(Canvas canvas) {
    Px.rect(canvas, 0, 0, kCityW, kCityH, 0);

    // Дорожная сетка: бордюры, проезжая часть, разметка.
    for (final double y in kRoadsY) {
      Px.rect(canvas, 0, y - kRoadHalf - 3, kCityW, (kRoadHalf + 3) * 2, 1);
      Px.rect(canvas, 0, y - kRoadHalf, kCityW, kRoadHalf * 2, 11);
    }
    for (final double x in kRoadsX) {
      Px.rect(canvas, x - kRoadHalf - 3, 0, (kRoadHalf + 3) * 2, kCityH, 1);
      Px.rect(canvas, x - kRoadHalf, 0, kRoadHalf * 2, kCityH, 11);
    }
    for (final double y in kRoadsY) {
      for (double x = 4; x < kCityW; x += 14) {
        Px.rect(canvas, x, y - 1, 7, 1, 10, 0.8);
      }
    }
    for (final double x in kRoadsX) {
      for (double y = 4; y < kCityH; y += 14) {
        Px.rect(canvas, x - 1, y, 1, 7, 10, 0.8);
      }
    }

    for (final Park park in engine.city.parks) {
      _drawPark(canvas, park);
    }
    for (final Building b in engine.city.buildings) {
      _drawBuilding(canvas, b);
    }

    _drawHome(canvas);

    for (final GasStation st in engine.stations) {
      _drawStation(canvas, st);
    }

    _drawJob(canvas);
    _drawCanisters(canvas);

    // Трафик.
    for (final NpcCar car in engine.city.traffic) {
      _drawCar(canvas, car.x, car.y, car.angle, car.color, 11, 17);
    }

    // Очереди на АЗС.
    for (final GasStation st in engine.stations) {
      for (final QueueCar q in st.queue) {
        if (q.isPlayer) {
          continue;
        }
        _drawCar(canvas, q.x, q.y, q.angle, q.color, q.w, q.h);
      }
    }

    // Игрок.
    _drawPlayer(canvas);

    for (final Puff p in engine.puffs) {
      Px.ring(canvas, p.x, p.y, p.radius, p.thickness, p.color, 0.8);
    }
    for (final Particle particle in engine.particles) {
      Px.rect(canvas, particle.x, particle.y, particle.size, particle.size, particle.color);
    }
  }

  void _drawPark(Canvas canvas, Park park) {
    if (park.kind == 0) {
      Px.rect(canvas, park.x, park.y, park.w, park.h, 12);
      for (double x = park.x + 5; x < park.x + park.w - 3; x += 13) {
        for (double y = park.y + 5; y < park.y + park.h - 3; y += 13) {
          Px.circle(canvas, x, y, 3, 3);
          Px.rect(canvas, x - 1, y + 2, 2, 3, 4);
        }
      }
    } else {
      Px.rect(canvas, park.x, park.y, park.w, park.h, 1);
      Px.rect(canvas, park.x + 2, park.y + 2, park.w - 4, park.h - 4, 11);
      for (double y = park.y + 6; y < park.y + park.h - 4; y += 10) {
        Px.rect(canvas, park.x + 3, y, park.w - 6, 1, 7, 0.5);
      }
    }
  }

  void _drawBuilding(Canvas canvas, Building b) {
    Px.rect(canvas, b.x, b.y, b.w, b.h, b.color);
    Px.rect(canvas, b.x, b.y, b.w, 1, 0, 0.35);
    Px.rect(canvas, b.x, b.y + b.h - 1, b.w, 1, 0, 0.35);
    if (!b.windows) {
      return;
    }
    final int color = engine.time % 2 < 1 ? 10 : 6;
    for (double x = b.x + 3; x < b.x + b.w - 3; x += 7) {
      for (double y = b.y + 3; y < b.y + b.h - 3; y += 7) {
        Px.rect(canvas, x, y, 2, 2, color, 0.85);
      }
    }
  }

  void _drawHome(Canvas canvas) {
    const double x = GameEngine.homeX;
    const double y = GameEngine.homeY;
    Px.rect(canvas, x - 18, y - 14, 36, 28, 11);
    Px.rect(canvas, x - 15, y - 11, 30, 22, 4);
    Px.rect(canvas, x - 15, y - 17, 30, 6, 8);
    Px.rect(canvas, x - 14, y - 15, 28, 2, 9);
    Px.rect(canvas, x - 5, y - 3, 10, 11, 4);
    Px.frame(canvas, x - 5, y - 3, 10, 11, 0);
    Px.rect(canvas, x + 6, y + 1, 3, 3, 10);
    final double pulse = 0.5 + 0.5 * math.sin(engine.time * 3);
    _worldText(canvas, 'ДОМ', x, y - 12, 7, 12, alpha: 0.7 + 0.3 * pulse);
  }

  void _drawStation(Canvas canvas, GasStation st) {
    final double cx = st.x + st.sideX * 30;
    final double cy = st.y + st.sideY * 30;

    // Площадка и подъезд.
    Px.rect(canvas, cx - 32, cy - 32, 64, 64, 11);
    Px.rect(canvas, cx - 32, cy - 32, 64, 3, 1);
    Px.rect(canvas, cx - 32, cy + 29, 64, 3, 1);

    // Навес над колонками.
    Px.rect(canvas, cx - 24, cy - 20, 48, 40, 1);
    Px.rect(canvas, cx - 22, cy - 18, 44, 36, 5);
    Px.rect(canvas, cx - 22, cy - 18, 44, 2, 13);

    // Магазин АЗС.
    Px.rect(canvas, cx + st.sideX * 8 - 12, cy + st.sideY * 8 - 12, 24, 24, 7);
    Px.rect(canvas, cx + st.sideX * 8 - 10, cy + st.sideY * 8 - 10, 20, 20, 5);
    Px.rect(canvas, cx + st.sideX * 8 - 8, cy + st.sideY * 8 - 8, 16, 10, 6, 0.8);

    // Колонки.
    Px.rect(canvas, cx - 6, cy - 6, 4, 12, 8);
    Px.rect(canvas, cx + 2, cy - 6, 4, 12, 8);

    // Носик к дороге.
    Px.rect(canvas, st.x - 2, st.y - 2, 4, 4, 0);
    if (st.working) {
      final double glow = 0.6 + 0.4 * math.sin(engine.time * 5);
      Px.circle(canvas, st.x, st.y, 2 + glow, 12, 0.9);
    }

    // Табличка с ценой и состоянием.
    final int signColor = st.state == StationState.empty
        ? 8
        : (st.brokenTimer > 0 ? 9 : (st.liters < 120 ? 10 : 12));
    Px.rect(canvas, cx - 16, cy - 30, 32, 11, 0);
    Px.rect(canvas, cx - 15, cy - 29, 30, 9, signColor, st.flash > 0 ? 1.0 : 0.9);
    if (st.flash > 0) {
      Px.frame(canvas, cx - 18, cy - 32, 36, 15, 7);
    }
    _worldText(
      canvas,
      st.state == StationState.empty
          ? 'ПУСТО'
          : '${st.price.toStringAsFixed(0)}₽',
      cx,
      cy - 25,
      6,
      0,
      align: TextAlign.center,
    );

    // Хвост очереди: пунктирная линия.
    final int n = st.queue.length;
    for (int i = 0; i <= n; i++) {
      final double x = st.slotX(i);
      final double y = st.slotY(i);
      Px.rect(canvas, x - 1, y - 1, 3, 3, st.working ? 3 : 8, 0.7);
    }
    if (n > 0) {
      _worldText(canvas, 'ОЧЕРЕДЬ: $n', st.slotX(n) + (st.ux != 0 ? st.ux * 10 : 0), st.slotY(n) - 10, 6, 10);
    } else if (st.state == StationState.open) {
      _worldText(canvas, 'СВОБОДНО', st.x, st.y - 12, 6, 12);
    }
    if (st.state != StationState.open || st.brokenTimer > 0) {
      _worldText(canvas, st.state == StationState.empty ? 'НЕТ ТОПЛИВА' : 'РЕМОНТ', cx, cy + 36, 6, 8);
    }
  }

  void _drawJob(Canvas canvas) {
    final DeliveryJob? j = engine.job;
    if (j == null) {
      return;
    }
    final double pulse = 0.6 + 0.4 * math.sin(engine.time * 4);
    if (!j.picked) {
      _flag(canvas, j.pickX, j.pickY, 9, 10, pulse);
      _worldText(canvas, 'ГРУЗ', j.pickX, j.pickY - 12, 6, 9);
    } else {
      _flag(canvas, j.dropX, j.dropY, 12, 12, pulse);
      _worldText(canvas, 'СДАТЬ ${j.reward}₽', j.dropX, j.dropY - 12, 6, 12);
    }
  }

  void _flag(Canvas canvas, double x, double y, int a, int b, double pulse) {
    Px.rect(canvas, x - 1, y - 8, 1, 14, 7);
    Px.rect(canvas, x, y - 8, 8, 6, a);
    Px.rect(canvas, x, y - 2, 8, 6, b);
    Px.ring(canvas, x + 3, y + 2, 8 + pulse * 3, 1, 7, 0.5);
  }

  void _drawCanisters(Canvas canvas) {
    for (final Canister c in engine.canisters) {
      final double bob = math.sin(engine.time * 3 + c.x) * 1.5;
      Px.rect(canvas, c.x - 4, c.y - 6 + bob, 8, 12, 4);
      Px.rect(canvas, c.x - 3, c.y - 5 + bob, 6, 10, 9);
      Px.rect(canvas, c.x - 2, c.y - 7 + bob, 4, 2, 4);
      Px.rect(canvas, c.x - 2, c.y - 1 + bob, 4, 2, 12);
    }
  }

  void _drawPlayer(Canvas canvas) {
    if (engine.inQueue) {
      Px.circle(canvas, engine.player.x, engine.player.y, 4, 3, 0.35);
    }
    _drawCar(canvas, engine.player.x, engine.player.y, engine.player.angle, engine.spec.color, engine.spec.w.toDouble(), engine.spec.h.toDouble(), player: true);
  }

  /// Топ-даун машина: кузов, кабина, стёкла, колёса.
  void _drawCar(
    Canvas canvas,
    double x,
    double y,
    double angle,
    int color,
    double w,
    double h, {
    bool player = false,
  }) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    final double l = h;
    final double t = w;
    // Тень.
    Px.rect(canvas, -l / 2 + 1, -t / 2 + 1, l, t, 0, 0.35);
    // Кузов.
    Px.rect(canvas, -l / 2, -t / 2, l, t, color);
    // Крыша.
    Px.rect(canvas, -l * 0.16, -t / 2 + 1, l * 0.34, t - 2, 0, 0.18);
    // Лобовое и заднее стекло.
    Px.rect(canvas, l * 0.2, -t / 2 + 1, 2, t - 2, 6, 0.9);
    Px.rect(canvas, -l * 0.34, -t / 2 + 1, 2, t - 2, 6, 0.6);
    // Колёса.
    Px.rect(canvas, l * 0.28, -t / 2 - 1, 3, 2, 0);
    Px.rect(canvas, l * 0.28, t / 2 - 1, 3, 2, 0);
    Px.rect(canvas, -l * 0.4, -t / 2 - 1, 3, 2, 0);
    Px.rect(canvas, -l * 0.4, t / 2 - 1, 3, 2, 0);
    if (player) {
      Px.rect(canvas, l / 2 - 1, -t / 2 + 1, 1, 2, 10);
      Px.rect(canvas, l / 2 - 1, t / 2 - 3, 1, 2, 10);
    }
    canvas.restore();
  }

  // --- HUD -----------------------------------------------------------------

  void _drawHud(Canvas canvas) {
    // Топливо.
    const double barW = 52.0;
    Px.frame(canvas, 6, 6, barW, 9, 0);
    Px.frame(canvas, 5, 5, barW + 2, 11, 7, 0.6);
    final int fuelColor = engine.fuelRatio > 0.5 ? 12 : (engine.fuelRatio > 0.22 ? 10 : 8);
    Px.rect(canvas, 7, 7, (barW - 2) * engine.fuelRatio, 7, fuelColor);
    if (engine.fuelRatio < 0.22 && engine.time % 0.8 < 0.5) {
      Px.frame(canvas, 5, 5, barW + 2, 11, 8);
    }
    _text(canvas, engine.fuelText, 6 + barW + 4, 6, 9, 7);

    // Деньги и очки.
    _text(canvas, engine.moneyText, 6, 18, 10, 10);
    _text(canvas, 'ОЧКИ ${engine.score}', 6, 30, 8, 6);

    // Задача.
    if (engine.scene == GameScene.playing) {
      _text(canvas, engine.objectiveTitle, 6, 42, 7, 13);
      _text(canvas, engine.objectiveLine, 6, 51, 7, 7, alpha: 0.85);
    }

    // Репутация / день.
    _text(canvas, 'РЕП ${engine.reputation.toStringAsFixed(0)}', kWorldW - 54, 30, 7, 6);
    if (engine.mode == GameMode.campaign) {
      _text(canvas, 'ДЕНЬ ${engine.day}', kWorldW - 54, 40, 7, 10);
    }

    // Очередь: подсказка.
    if (engine.inQueue && engine.queueStation != null) {
      final GasStation st = engine.queueStation!;
      final int ahead = st.queue.indexWhere((QueueCar q) => q.isPlayer);
      final String label = ahead <= 0 ? 'ВЫ У КОЛОНКИ' : 'ВПЕРЕДИ $ahead МАШИН';
      _text(canvas, label, kWorldW / 2, 42, 8, ahead <= 0 ? 12 : 7, align: TextAlign.center);
      _text(canvas, st.name, kWorldW / 2, 52, 7, 6, align: TextAlign.center);
    } else {
      final GasStation? near = engine.nearestStation;
      if (near != null) {
        final bool nearEnough = _dist(engine.player.x, engine.player.y, near.enterX, near.enterY) < 90;
        if (nearEnough) {
          _text(canvas, 'К АЗС: ${near.name}', kWorldW / 2, 42, 7, 6, align: TextAlign.center);
        }
      }
    }

    // Прицел очереди (метка входа).
    if (!engine.inQueue) {
      for (final GasStation st in engine.stations) {
        if (st.working) {
          final double pulse = 0.4 + 0.6 * math.sin(engine.time * 4);
          Px.ring(canvas, st.enterX - engine.camX, st.enterY - engine.camY, 10 + pulse * 2, 1, 3, 0.5);
        }
      }
    }

    _drawMinimap(canvas);

    if (engine.stalled) {
      _text(canvas, 'НУЛЕВОЙ БАК', kWorldW / 2, engine.worldH * 0.55, 12, 8, align: TextAlign.center);
      _text(canvas, 'ЭВАКУАТОР ${engine.stallTimer.ceil()}...', kWorldW / 2, engine.worldH * 0.55 + 14, 8, 11, align: TextAlign.center);
    }
  }

  void _drawMinimap(Canvas canvas) {
    const double size = 46;
    const double x = kWorldW - size - 5;
    const double y = 5;
    Px.rect(canvas, x, y, size, size, 0);
    Px.frame(canvas, x, y, size, size, 7, 0.7);
    final double s = size / kCityW;
    for (final double ry in kRoadsY) {
      Px.rect(canvas, x + 1, y + ry * s, size - 2, 1, 1, 0.9);
    }
    for (final double rx in kRoadsX) {
      Px.rect(canvas, x + rx * s, y + 1, 1, size - 2, 1, 0.9);
    }
    for (final GasStation st in engine.stations) {
      final int c = st.state == StationState.empty ? 8 : (st.working ? 12 : 9);
      Px.rect(canvas, x + st.x * s - 1, y + st.y * s - 1, 3, 3, c);
    }
    Px.rect(canvas, x + GameEngine.homeX * s - 1, y + GameEngine.homeY * s - 1, 3, 3, 10);
    final DeliveryJob? j = engine.job;
    if (j != null) {
      Px.rect(canvas, x + (j.picked ? j.dropX : j.pickX) * s - 1, y + (j.picked ? j.dropY : j.pickY) * s - 1, 3, 3, j.picked ? 12 : 9);
    }
    Px.rect(canvas, x + engine.player.x * s - 1, y + engine.player.y * s - 1, 3, 3, 7);
  }

  void _drawBanners(Canvas canvas) {
    double y = 66;
    for (final Notice b in engine.banners) {
      double alpha = b.life > b.maxLife - 0.3 ? (b.maxLife - b.life) / 0.3 : (b.life < 0.5 ? b.life / 0.5 : 1.0);
      alpha = alpha.clamp(0.0, 1.0);
      final String text = b.text;
      final TextPainter measure = _measure(text, 9);
      final double w = measure.width + 12;
      final double x = (kWorldW - w) / 2;
      Px.rect(canvas, x, y, w, 14, 0, 0.72 * alpha);
      Px.frame(canvas, x, y, w, 14, b.color, 0.85 * alpha);
      _text(canvas, text, kWorldW / 2, y + 3, 9, b.color, align: TextAlign.center, alpha: alpha);
      y += 16;
    }
  }

  void _drawJoystick(Canvas canvas) {
    if (!engine.joyActive || engine.joyMag <= 0.05) {
      return;
    }
    final double ox = engine.joyOriginX;
    final double oy = engine.joyOriginY;
    Px.ring(canvas, ox, oy, 26, 1, 7, 0.35);
    Px.ring(canvas, ox, oy, 4, 1, 7, 0.4);
    final double kx = ox + engine.joyX * engine.joyMag * 26;
    final double ky = oy + engine.joyY * engine.joyMag * 26;
    Px.circle(canvas, kx, ky, 5, 7, 0.5);
    Px.ring(canvas, kx, ky, 5, 1, 0, 0.6);
  }

  // --- Текст ---------------------------------------------------------------

  /// Размер строки в виртуальных пикселях.
  TextPainter _measure(String text, double fontSize) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: P.get(7),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }

  /// Текст в координатах вида (canvas уже отмасштабирован и сдвинут).
  void _text(
    Canvas canvas,
    String text,
    double vx,
    double vy,
    double fontSize,
    int color, {
    TextAlign align = TextAlign.left,
    double alpha = 1.0,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: P.alpha(color, alpha),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    double x = vx;
    if (align == TextAlign.center) {
      x -= painter.width / 2;
    } else if (align == TextAlign.right) {
      x -= painter.width;
    }
    painter.paint(canvas, Offset(x, vy));
  }

  /// Текст в мировых координатах (canvas уже сдвинут камерой).
  void _worldText(
    Canvas canvas,
    String text,
    double wx,
    double wy,
    double fontSize,
    int color, {
    TextAlign align = TextAlign.left,
    double alpha = 1.0,
  }) {
    _text(canvas, text, wx, wy, fontSize, color, align: align, alpha: alpha);
  }

  double _dist(double ax, double ay, double bx, double by) {
    final double dx = ax - bx;
    final double dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool shouldRepaint(covariant PixelPainter oldDelegate) {
    return oldDelegate.engine != engine || oldDelegate.transform.scale != transform.scale;
  }
}
