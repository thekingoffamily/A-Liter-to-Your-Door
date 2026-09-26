/// Характеристики автомобиля.
///
/// Скорости — в виртуальных пикселях в секунду, расход — множитель к
/// базовому расходу топлива, tank — объём бака в литрах.
class CarSpec {
  const CarSpec({
    required this.id,
    required this.title,
    required this.desc,
    required this.tank,
    required this.consumption,
    required this.maxSpeed,
    required this.turnRate,
    required this.price,
    required this.canister,
    required this.color,
    required this.w,
    required this.h,
  });

  final String id;
  final String title;
  final String desc;
  final double tank;
  final double consumption;
  final double maxSpeed;
  final double turnRate;
  final int price;
  final int canister;
  final int color;
  final int w;
  final int h;
}

/// Стартовый седан плюс машины, которые открываются в гараже.
const List<CarSpec> kCars = <CarSpec>[
  CarSpec(
    id: 'sedan',
    title: 'Старый седан',
    desc: 'Маленький бак, высокий расход, дёшево чинить',
    tank: 50,
    consumption: 1.0,
    maxSpeed: 96,
    turnRate: 3.1,
    price: 0,
    canister: 0,
    color: 11,
    w: 11,
    h: 17,
  ),
  CarSpec(
    id: 'hatch',
    title: 'Компактный хэтчбек',
    desc: 'Экономичный и юркий в пробках',
    tank: 42,
    consumption: 0.82,
    maxSpeed: 108,
    turnRate: 3.6,
    price: 1200,
    canister: 0,
    color: 8,
    w: 10,
    h: 16,
  ),
  CarSpec(
    id: 'wagon',
    title: 'Универсал',
    desc: 'Возит канистры и помогает другим',
    tank: 62,
    consumption: 1.02,
    maxSpeed: 92,
    turnRate: 2.9,
    price: 2200,
    canister: 2,
    color: 12,
    w: 11,
    h: 18,
  ),
  CarSpec(
    id: 'taxi',
    title: 'Такси',
    desc: 'Возит пассажиров: доход, но и расход',
    tank: 46,
    consumption: 0.92,
    maxSpeed: 112,
    turnRate: 3.4,
    price: 3200,
    canister: 0,
    color: 10,
    w: 11,
    h: 17,
  ),
  CarSpec(
    id: 'van',
    title: 'Микроавтобус',
    desc: 'Огромный бак, плохая манёвренность',
    tank: 84,
    consumption: 1.28,
    maxSpeed: 78,
    turnRate: 2.3,
    price: 4800,
    canister: 3,
    color: 6,
    w: 12,
    h: 20,
  ),
];

CarSpec carById(String id) => kCars.firstWhere((CarSpec c) => c.id == id, orElse: () => kCars.first);

/// Машина на карте (позиция, угол, скорость, топливо).
class Car {
  Car(this.spec, this.x, this.y, this.angle) : fuel = spec.tank;

  CarSpec spec;
  double x;
  double y;
  double angle;
  double speed = 0;
  double fuel;

  double get w => spec.w.toDouble();
  double get h => spec.h.toDouble();
}
