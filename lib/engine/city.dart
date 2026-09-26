import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'constants.dart';
import 'vehicles.dart';

/// Городское здание (непроходимое препятствие).
class Building {
  Building(this.x, this.y, this.w, this.h, this.color, {this.windows = true});

  final double x;
  final double y;
  final double w;
  final double h;
  final int color;
  final bool windows;

  Rect get rect => Rect.fromLTWH(x, y, w, h);
}

/// Сквер или площадка (декор, проезжать можно).
class Park {
  Park(this.x, this.y, this.w, this.h, this.kind);

  final double x;
  final double y;
  final double w;
  final double h;
  final int kind; // 0 — деревья, 1 — парковка
}

/// Машина дорожного трафика (живёт сама по себе).
class NpcCar {
  NpcCar({
    required this.x,
    required this.y,
    required this.angle,
    required this.color,
    required this.dirX,
    required this.dirY,
    required this.ix,
    required this.iy,
    required this.tx,
    required this.ty,
    this.speed = 46,
  });

  double x;
  double y;
  double angle;
  double speed;
  int color;
  int dirX;
  int dirY;
  int ix;
  int iy;
  double tx;
  double ty;
}

/// Генерация и логика города: улицы, кварталы, препятствия и трафик.
class City {
  City(this.rnd, {List<Rect> reserved = const <Rect>[]}) : _reserved = reserved {
    _generateBuildings();
    _spawnTraffic();
  }

  final math.Random rnd;
  final List<Rect> _reserved;

  final List<Building> buildings = <Building>[];
  final List<Park> parks = <Park>[];
  final List<NpcCar> traffic = <NpcCar>[];

  static const List<int> _buildingColors = <int>[5, 8, 4, 2, 13, 1, 11];

  /// Пятна кварталов между улицами (см. kRoadsX/kRoadsY).
  static const List<List<double>> _blockX = <List<double>>[
    <double>[4, 60],
    <double>[100, 220],
    <double>[260, 380],
    <double>[420, 540],
    <double>[580, 636],
  ];
  static const List<List<double>> _blockY = <List<double>>[
    <double>[4, 60],
    <double>[100, 220],
    <double>[260, 380],
    <double>[420, 540],
    <double>[580, 636],
  ];

  void _generateBuildings() {
    for (final List<double> bx in _blockX) {
      for (final List<double> by in _blockY) {
        _fillBlock(bx[0], by[0], bx[1], by[1]);
      }
    }
  }

  void _fillBlock(double x0, double y0, double x1, double y1) {
    final double w = x1 - x0;
    final double h = y1 - y0;
    if (w < 18 || h < 18) {
      return;
    }
    final double roll = rnd.nextDouble();
    if (roll < 0.16) {
      parks.add(Park(x0, y0, w, h, 0));
      return;
    }
    if (roll < 0.26) {
      parks.add(Park(x0, y0, w, h, 1));
      return;
    }
    final int cols = w > 90 ? 2 : 1;
    final int rows = h > 90 ? 2 : 1;
    final double cw = w / cols;
    final double ch = h / rows;
    for (int cx = 0; cx < cols; cx++) {
      for (int cy = 0; cy < rows; cy++) {
        final double bw = cw - 6 - rnd.nextDouble() * 6;
        final double bh = ch - 6 - rnd.nextDouble() * 6;
        final double px = x0 + cx * cw + 3 + rnd.nextDouble() * 3;
        final double py = y0 + cy * ch + 3 + rnd.nextDouble() * 3;
        if (bw < 14 || bh < 14) {
          continue;
        }
        final Rect r = Rect.fromLTWH(px, py, bw, bh);
        if (_blocked(r)) {
          continue;
        }
        buildings.add(Building(
          px,
          py,
          bw,
          bh,
          _buildingColors[rnd.nextInt(_buildingColors.length)],
          windows: rnd.nextDouble() < 0.8,
        ));
      }
    }
  }

  bool _blocked(Rect r) {
    for (final Rect res in _reserved) {
      if (res.overlaps(r.inflate(2))) {
        return true;
      }
    }
    return false;
  }

  // --- Трафик ---------------------------------------------------------------

  static const List<List<int>> _dirs = <List<int>>[
    <int>[1, 0],
    <int>[-1, 0],
    <int>[0, 1],
    <int>[0, -1],
  ];

  double _laneOffsetX(int dirX, int dirY) {
    if (dirX == 0) {
      return dirY > 0 ? -5 : 5;
    }
    return 0;
  }

  double _laneOffsetY(int dirX, int dirY) {
    if (dirY == 0) {
      return dirX > 0 ? 5 : -5;
    }
    return 0;
  }

  void _spawnTraffic() {
    const int count = 16;
    for (int i = 0; i < count; i++) {
      final int ix = rnd.nextInt(kRoadsX.length);
      final int iy = rnd.nextInt(kRoadsY.length);
      final List<int> dir = _pickDirection(ix, iy, 0, 0, true);
      final NpcCar car = NpcCar(
        x: kRoadsX[ix] + (rnd.nextDouble() - 0.5) * 0,
        y: kRoadsY[iy],
        angle: 0,
        color: <int>[8, 9, 13, 5, 2, 4, 6, 10, 14, 12, 11, 15][rnd.nextInt(12)],
        dirX: dir[0],
        dirY: dir[1],
        ix: ix,
        iy: iy,
        tx: 0,
        ty: 0,
        speed: 34 + rnd.nextDouble() * 26,
      );
      car.x = kRoadsX[ix] + _laneOffsetX(dir[0], dir[1]);
      car.y = kRoadsY[iy] + _laneOffsetY(dir[0], dir[1]);
      _setTarget(car);
      // Разнести машины вдоль улицы, чтобы они не стартовали стопкой.
      car.x += dir[0] * rnd.nextDouble() * kRoadPitch * 0.7;
      car.y += dir[1] * rnd.nextDouble() * kRoadPitch * 0.7;
      car.angle = math.atan2(dir[1].toDouble(), dir[0].toDouble());
      traffic.add(car);
    }
  }

  List<int> _pickDirection(int ix, int iy, int prevX, int prevY, bool allowReverse) {
    final List<List<int>> options = <List<int>>[];
    for (final List<int> d in _dirs) {
      final int nx = ix + d[0];
      final int ny = iy + d[1];
      if (nx < 0 || ny < 0 || nx >= kRoadsX.length || ny >= kRoadsY.length) {
        continue;
      }
      final bool reverse = d[0] == -prevX && d[1] == -prevY;
      if (reverse && !allowReverse) {
        continue;
      }
      options.add(d);
    }
    if (options.isEmpty) {
      return <int>[prevX, prevY];
    }
    // Предпочитаем ехать прямо.
    final List<List<int>> straight = options
        .where((List<int> d) => d[0] == prevX && d[1] == prevY && (prevX != 0 || prevY != 0))
        .toList();
    if (straight.isNotEmpty && rnd.nextDouble() < 0.62) {
      return straight.first;
    }
    return options[rnd.nextInt(options.length)];
  }

  void _setTarget(NpcCar car) {
    car.ix += car.dirX;
    car.iy += car.dirY;
    car.tx = kRoadsX[car.ix] + _laneOffsetX(car.dirX, car.dirY);
    car.ty = kRoadsY[car.iy] + _laneOffsetY(car.dirX, car.dirY);
  }

  void updateTraffic(double dt) {
    for (final NpcCar car in traffic) {
      final double dx = car.tx - car.x;
      final double dy = car.ty - car.y;
      final double dist = math.sqrt(dx * dx + dy * dy);
      final double step = car.speed * dt;
      if (dist <= step + 0.5) {
        car.x = car.tx;
        car.y = car.ty;
        if (car.ix < 0 || car.iy < 0 || car.ix >= kRoadsX.length || car.iy >= kRoadsY.length) {
          return;
        }
        final List<int> next = _pickDirection(car.ix, car.iy, car.dirX, car.dirY, false);
        car.dirX = next[0];
        car.dirY = next[1];
        _setTarget(car);
        car.angle = math.atan2(car.dirY.toDouble(), car.dirX.toDouble());
      } else {
        car.x += dx / dist * step;
        car.y += dy / dist * step;
        car.angle = math.atan2(dy, dx);
      }
    }
  }

  // --- Препятствия ----------------------------------------------------------

  /// Выталкивает машину из зданий. Возвращает true, если было столкновение.
  bool resolveCar(Car car, double r) {
    bool hit = false;
    final double nx = car.x.clamp(6.0, kCityW - 6.0);
    final double ny = car.y.clamp(6.0, kCityH - 6.0);
    if (nx != car.x || ny != car.y) {
      car.x = nx;
      car.y = ny;
      hit = true;
    }
    for (final Building b in buildings) {
      if (car.x + r <= b.x || car.x - r >= b.x + b.w || car.y + r <= b.y || car.y - r >= b.y + b.h) {
        continue;
      }
      final double left = (car.x + r) - b.x;
      final double right = (b.x + b.w) - (car.x - r);
      final double top = (car.y + r) - b.y;
      final double bottom = (b.y + b.h) - (car.y - r);
      final double m = math.min(math.min(left, right), math.min(top, bottom));
      if (m == left) {
        car.x = b.x - r;
      } else if (m == right) {
        car.x = b.x + b.w + r;
      } else if (m == top) {
        car.y = b.y - r;
      } else {
        car.y = b.y + b.h + r;
      }
      hit = true;
    }
    return hit;
  }

  /// Свободна ли точка (для спавна канистр), не в здании.
  bool freePoint(double x, double y) {
    for (final Building b in buildings) {
      if (x > b.x - 6 && x < b.x + b.w + 6 && y > b.y - 6 && y < b.y + b.h + 6) {
        return false;
      }
    }
    return true;
  }
}
