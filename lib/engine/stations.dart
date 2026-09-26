import 'dart:math' as math;

/// Состояние АЗС.
enum StationState { open, empty, closed }

/// Машина, стоящая в очереди на АЗС.
///
/// Игрок — тоже такая машина, просто с [isPlayer] = true: тогда её позицию
/// ведёт движок, а не физика вождения.
class QueueCar {
  QueueCar({
    required this.color,
    required this.w,
    required this.h,
    this.isPlayer = false,
    this.slot = 0,
    required this.x,
    required this.y,
    required this.angle,
    this.refuelTime = 5.0,
  });

  bool isPlayer;
  int color;
  double w;
  double h;
  int slot;
  double x;
  double y;
  double angle;
  double refuelTime;
  double x0 = 0;
  double y0 = 0;

  /// Машина доехала до своего места в очереди (для отрисовки и заправки).
  double progress = 0;

  double get length => math.max(w, h);
}

/// Городская АЗС с колонкой, ценой и живой очередью.
class GasStation {
  GasStation({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.ux,
    required this.uy,
    required this.sideX,
    required this.sideY,
    required this.price,
    required this.capacity,
    required this.liters,
  });

  final int id;
  final String name;

  /// Позиция колонки (нос очереди).
  final double x;
  final double y;

  /// Единичный вектор «в хвост очереди» (вдоль улицы).
  final double ux;
  final double uy;

  /// Единичный вектор от колонки в сторону здания АЗС.
  final double sideX;
  final double sideY;

  StationState state = StationState.open;
  double price;
  double capacity;
  double liters;
  double refuelRate = 1.0;

  /// Лимит литров в одни руки (0 — нет лимита).
  double limit = 0;
  double reopenTimer = 0;
  double shiftTimer = 0;
  double eventTimer = 22;
  double brokenTimer = 0;
  double tankerTimer = 0;
  double limitTimer = 0;
  double flash = 0;
  String lastEvent = '';

  final List<QueueCar> queue = <QueueCar>[];

  static const double spacing = 15.0;

  bool get working => state == StationState.open && liters > 0.05 && brokenTimer <= 0;

  double slotX(int i) => x + ux * (i * spacing);
  double slotY(int i) => y + uy * (i * spacing);

  double get tailX => slotX(queue.length);
  double get tailY => slotY(queue.length);

  /// Направление, куда смотрит машина в очереди (в сторону колонки).
  double get queueAngle => math.atan2(-uy, -ux);

  /// Точка у входа в зону очереди — используется для подсказки игроку.
  double get enterX => slotX(queue.length);
  double get enterY => slotY(queue.length);

  double get fullness => capacity <= 0 ? 0 : liters / capacity;
}
