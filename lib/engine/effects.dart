import 'dart:math' as math;

/// Осколок / искра / монетка.
class Particle {
  Particle(this.x, this.y, this.vx, this.vy, this.color, this.life, {this.size = 1.0});

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final int color;
  final double size;
  bool alive = true;

  void update(double dt) {
    life -= dt;
    if (life <= 0) {
      alive = false;
      return;
    }
    x += vx * dt;
    y += vy * dt;
    vy += 14 * dt;
    vx *= (1 - dt * 0.6);
  }
}

/// Всплывающий текст («+5 л», «-52₽», «ПОЛНЫЙ БАК»).
class FloatText {
  FloatText(this.x, this.y, this.text, this.color, {this.size = 8.0});

  final double x;
  double y;
  final String text;
  final int color;
  final double size;
  double life = 1.1;
  bool alive = true;

  void update(double dt) {
    life -= dt;
    if (life <= 0) {
      alive = false;
      return;
    }
    y -= 14 * dt;
  }
}

/// Расширяющееся кольцо (заправка, пыль, выхлоп, вспышка).
class Puff {
  Puff(this.x, this.y, this.maxRadius, this.color, {this.life = 0.5, this.thickness = 1.0})
      : maxLife = life;

  double x;
  double y;
  double radius = 1.0;
  final double maxRadius;
  final int color;
  double life;
  final double maxLife;
  final double thickness;
  bool alive = true;

  void update(double dt) {
    life -= dt;
    if (life <= 0) {
      alive = false;
      return;
    }
    final double t = 1.0 - (life / maxLife);
    radius = 1.0 + (maxRadius - 1.0) * math.min(1.0, t);
  }
}
