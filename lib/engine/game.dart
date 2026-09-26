import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../services/sfx.dart';
import 'city.dart';
import 'constants.dart';
import 'effects.dart';
import 'signal.dart';
import 'stations.dart';
import 'upgrades.dart';
import 'vehicles.dart';

/// Игровые сцены.
enum GameScene { title, playing, garage, dayResult, gameOver }

/// Режимы игры.
enum GameMode { freeRide, survival, campaign }

/// Тип ежедневной цели в кампании.
enum GoalKind { refuelLiters, earnMoney, surviveTime, reachHome, buyUpgrade }

/// Цель дня кампании.
class DayGoal {
  const DayGoal(this.title, this.desc, this.kind, this.target);

  final String title;
  final String desc;
  final GoalKind kind;
  final double target;
}

/// Всплывающая табличка-событие («БЕНЗИН КОНЧИЛСЯ», «БЕНЗОВОЗ В ПУТИ»).
class Notice {
  Notice(this.text, this.color, {this.life = 2.6}) : maxLife = life;

  final String text;
  final int color;
  double life;
  final double maxLife;
  bool get alive => life > 0;
}

/// Заказ на доставку: довезти груз из точки А в точку Б за деньги.
class DeliveryJob {
  DeliveryJob(this.pickX, this.pickY, this.dropX, this.dropY, this.reward);

  final double pickX;
  final double pickY;
  final double dropX;
  final double dropY;
  final int reward;
  bool picked = false;
}

/// Канистра с топливом, разбросанная по городу.
class Canister {
  Canister(this.x, this.y);

  double x;
  double y;
  bool taken = false;
}

/// Движок игры: город, машина, АЗС, очереди, события и экономика.
///
/// Разделение сигналов:
///  * сам движок ([emit]) уведомляет каждый кадр — на нём перерисовка;
///  * [ui] уведомляет редко (смена сцены, деньги, гараж) — на нём меню.
class GameEngine extends Signal {
  GameEngine({this.bestScore = 0}) {
    player = Car(carById(currentCarId), homeX, homeY - 22, -math.pi / 2);
    reserveLeft = reserveCap;
    _spawnWorld();
    updateCamera();
  }

  /// Вызывается, когда рекорд побит — виджет сохраняет его в память устройства.
  void Function(int score)? onBestChanged;
  void Function()? onGarageChanged;

  final Signal ui = Signal();
  final math.Random rnd = math.Random();

  /// Высота вида в виртуальных пикселях (задаётся из виджета по размеру экрана).
  double worldH = kWorldH;

  double time = 0;
  GameScene scene = GameScene.title;
  GameMode mode = GameMode.freeRide;
  bool paused = false;
  int bestScore;
  bool newRecord = false;
  int day = 1;
  bool campaignWon = false;

  int money = 700;
  int score = 0;
  double reputation = 0;
  double distance = 0;
  int jobsDone = 0;
  double litersBought = 0;

  late Car player;
  late City city;
  late List<GasStation> stations;
  final List<Canister> canisters = <Canister>[];

  DeliveryJob? job;
  double newJobTimer = 0;

  // --- Ввод ----------------------------------------------------------------
  bool joyActive = false;
  double joyX = 0;
  double joyY = 0;
  double joyOriginX = 0;
  double joyOriginY = 0;
  double joyMag = 0;

  bool engineOn = true;

  // --- Очередь -------------------------------------------------------------
  GasStation? queueStation;
  QueueCar? queueCar;
  double joinCooldown = 0;
  double queueTime = 0;
  double refueledThisVisit = 0;

  // --- Заглох / эвакуатор --------------------------------------------------
  bool stalled = false;
  double stallTimer = 0;
  static const int towCost = 180;

  // --- Камера --------------------------------------------------------------
  double camX = 0;
  double camY = 0;

  // --- Эффекты -------------------------------------------------------------
  final List<Particle> particles = <Particle>[];
  final List<FloatText> texts = <FloatText>[];
  final List<Puff> puffs = <Puff>[];
  final List<Notice> banners = <Notice>[];

  // --- Прогресс ------------------------------------------------------------
  final Map<String, int> levels = <String, int>{};
  final Set<String> ownedCars = <String>{'sedan'};
  String currentCarId = 'sedan';
  double reserveLeft = 0;

  // --- Кампания ------------------------------------------------------------
  double dayLiters = 0;
  int dayEarned = 0;
  double daySurvive = 0;
  int dayUpgrades = 0;
  bool dayHomeReached = false;
  bool homeBonusUsed = false;

  double rumorTimer = 14;
  double canisterTimer = 9;
  double tutorialTimer = 0;
  bool _lowFuelWarned = false;
  double _pumpSound = 0;

  /// Позиция дома героя.
  static const double homeX = 100;
  static const double homeY = 585;

  static const List<DayGoal> dayGoals = <DayGoal>[
    DayGoal('День 1. Найти топливо', 'Заправьте 15 литров', GoalKind.refuelLiters, 15),
    DayGoal('День 2. Дорога домой', 'Вернитесь домой с 10 л в баке', GoalKind.reachHome, 10),
    DayGoal('День 3. Подработка', 'Заработайте 500 ₽ на доставках', GoalKind.earnMoney, 500),
    DayGoal('День 4. Очередь века', 'Продержитесь 90 секунд в очередях', GoalKind.surviveTime, 90),
    DayGoal('День 5. План на зиму', 'Купите любое улучшение в гараже', GoalKind.buyUpgrade, 1),
    DayGoal('День 6. Дальний рейс', 'Заправьте 40 литров', GoalKind.refuelLiters, 40),
    DayGoal('День 7. Финал', 'Привезите домой 25 литров', GoalKind.reachHome, 25),
  ];

  // --- Характеристики с учётом улучшений -----------------------------------

  int lvl(String id) => levels[id] ?? 0;

  CarSpec get spec => player.spec;

  double get tankCap => spec.tank + lvl('tank') * 10.0;

  double get consumptionMult => spec.consumption * (1 - lvl('engine') * 0.08);

  double get fastPumpMult => 1 + lvl('fastpump') * 0.3;

  double get priceFactor {
    double d = lvl('discount') * 0.06 + reputation * 0.004;
    if (d > 0.3) {
      d = 0.3;
    }
    return 1 - d;
  }

  double get reserveCap => spec.canister * 5.0 + lvl('canister') * 6.0;

  double get fuelRatio => tankCap <= 0 ? 0 : (player.fuel / tankCap).clamp(0, 1);

  DayGoal? get goal => mode == GameMode.campaign ? dayGoals[math.min(day - 1, dayGoals.length - 1)] : null;

  bool get inQueue => queueStation != null;

  String get modeTitle {
    switch (mode) {
      case GameMode.freeRide:
        return 'СВОБОДНАЯ ПОЕЗДКА';
      case GameMode.survival:
        return 'ВЫЖИВАНИЕ';
      case GameMode.campaign:
        return 'КАМПАНИЯ';
    }
  }

  String get objectiveTitle => mode == GameMode.campaign ? (goal?.title ?? '') : modeTitle;

  String get objectiveLine {
    if (mode == GameMode.campaign) {
      final DayGoal g = goal!;
      switch (g.kind) {
        case GoalKind.refuelLiters:
          return 'Заправлено: ${dayLiters.toStringAsFixed(0)} / ${g.target.toStringAsFixed(0)} л';
        case GoalKind.earnMoney:
          return 'Заработано: $dayEarned / ${g.target.toStringAsFixed(0)} ₽';
        case GoalKind.surviveTime:
          return 'В очередях: ${daySurvive.toStringAsFixed(0)} / ${g.target.toStringAsFixed(0)} с';
        case GoalKind.reachHome:
          return 'Дома с ${g.target.toStringAsFixed(0)} л — ${(player.fuel >= g.target && _nearHome()) ? "ГОТОВО" : "в пути"}';
        case GoalKind.buyUpgrade:
          return 'Улучшений куплено: $dayUpgrades / 1';
      }
    }
    if (mode == GameMode.survival) {
      return 'Топливо тает. Продержитесь как можно дольше.';
    }
    return 'Ищите АЗС, стойте в очередях, возите заказы.';
  }

  bool _nearHome() {
    final double dx = player.x - homeX;
    final double dy = player.y - homeY;
    return dx * dx + dy * dy < 26 * 26;
  }

  // --- Управление игрой ----------------------------------------------------

  void resizeWorld(double height) {
    if (height <= 0) {
      return;
    }
    worldH = height;
    updateCamera();
  }

  void updateCamera() {
    final double maxX = math.max(0.0, kCityW - kWorldW);
    final double maxY = math.max(0.0, kCityH - worldH);
    camX = (player.x - kWorldW / 2).clamp(0.0, maxX);
    camY = (player.y - worldH / 2).clamp(0.0, maxY);
  }

  /// Начать новую партию в выбранном режиме.
  void newGame(GameMode selected) {
    mode = selected;
    paused = false;
    score = 0;
    newRecord = false;
    campaignWon = false;
    day = 1;
    distance = 0;
    jobsDone = 0;
    litersBought = 0;
    reputation = 0;
    levels.clear();
    _resetRun();
    scene = GameScene.playing;
    _addBanner('ПОЕХАЛИ!', 3);
    if (selected == GameMode.survival) {
      player.fuel = 3;
      money = 180;
    } else if (selected == GameMode.campaign) {
      player.fuel = 15;
      money = 600;
    } else {
      player.fuel = tankCap;
      money = 700;
    }
    if (selected == GameMode.freeRide) {
      tutorialTimer = 6;
    }
    ui.emit();
    emit();
  }

  void _resetRun() {
    _spawnWorld();
    player = Car(carById(currentCarId), homeX, homeY - 22, -math.pi / 2);
    reserveLeft = reserveCap;
    queueStation = null;
    queueCar = null;
    stalled = false;
    stallTimer = 0;
    engineOn = true;
    Sfx.engine(false);
    particles.clear();
    texts.clear();
    puffs.clear();
    banners.clear();
    dayLiters = 0;
    dayEarned = 0;
    daySurvive = 0;
    dayUpgrades = 0;
    dayHomeReached = false;
    homeBonusUsed = false;
    _lowFuelWarned = false;
    newJobTimer = 0;
    rumorTimer = 12;
    canisterTimer = 6;
    job = null;
    updateCamera();
  }

  void _spawnWorld() {
    stations = _buildStations();
    final List<Rect> reserved = <Rect>[
      for (final GasStation st in stations)
        Rect.fromCenter(
          center: Offset(st.x + st.sideX * 34, st.y + st.sideY * 34),
          width: 92,
          height: 92,
        ),
      Rect.fromLTWH(homeX - 34, homeY - 34, 68, 68),
    ];
    city = City(rnd, reserved: reserved);
    canisters.clear();
    for (int i = 0; i < 6; i++) {
      _spawnCanister();
    }
  }

  List<GasStation> _buildStations() {
    final List<GasStation> result = <GasStation>[
      GasStation(
        id: 0,
        name: 'АЗС «Капля»',
        x: 300,
        y: 250,
        ux: 1,
        uy: 0,
        sideX: 0,
        sideY: 1,
        price: 34 + rnd.nextDouble() * 8,
        capacity: 900,
        liters: 520 + rnd.nextDouble() * 300,
      ),
      GasStation(
        id: 1,
        name: 'АЗС «Нефтегаз»',
        x: 410,
        y: 300,
        ux: 0,
        uy: 1,
        sideX: -1,
        sideY: 0,
        price: 39 + rnd.nextDouble() * 8,
        capacity: 1200,
        liters: 800 + rnd.nextDouble() * 400,
      ),
      GasStation(
        id: 2,
        name: 'АЗС «Пустой бак»',
        x: 160,
        y: 550,
        ux: 1,
        uy: 0,
        sideX: 0,
        sideY: -1,
        price: 29 + rnd.nextDouble() * 7,
        capacity: 700,
        liters: 300 + rnd.nextDouble() * 220,
      ),
      GasStation(
        id: 3,
        name: 'АЗС «Трасса»',
        x: 230,
        y: 480,
        ux: 0,
        uy: -1,
        sideX: -1,
        sideY: 0,
        price: 31 + rnd.nextDouble() * 6,
        capacity: 1000,
        liters: 600 + rnd.nextDouble() * 300,
      ),
    ];
    for (final GasStation st in result) {
      _fillStationQueue(st);
    }
    return result;
  }

  void _fillStationQueue(GasStation st) {
    // Чем дешевле бензин, тем длиннее очередь.
    final double cheap = (40 - st.price).clamp(0.0, 14.0);
    int count = (1 + cheap * 0.9 + rnd.nextDouble() * 4).round();
    if (count > kMaxQueue) {
      count = kMaxQueue;
    }
    final List<int> colors = <int>[8, 9, 13, 5, 2, 4, 6, 10, 14, 12, 11, 15];
    for (int i = 0; i < count; i++) {
      st.queue.add(QueueCar(
        color: colors[rnd.nextInt(colors.length)],
        w: 11,
        h: 17,
        slot: i,
        x: st.slotX(i),
        y: st.slotY(i),
        angle: st.queueAngle,
        refuelTime: 3.5 + rnd.nextDouble() * 4,
      ));
    }
    st.shiftTimer = count > 0 ? 3.5 + rnd.nextDouble() * 4 : 0;
  }

  void _spawnCanister() {
    for (int i = 0; i < 40; i++) {
      final double x = 24 + rnd.nextDouble() * (kCityW - 48);
      final double y = 24 + rnd.nextDouble() * (kCityH - 48);
      if (city.freePoint(x, y)) {
        canisters.add(Canister(x, y));
        return;
      }
    }
  }

  void toTitle() {
    scene = GameScene.title;
    paused = false;
    Sfx.engine(false);
    Sfx.pump(false);
    ui.emit();
    emit();
  }

  GameScene _garageReturn = GameScene.playing;

  void openGarage() {
    if (scene != GameScene.playing && scene != GameScene.dayResult && scene != GameScene.title) {
      return;
    }
    _garageReturn = scene;
    scene = GameScene.garage;
    paused = true;
    Sfx.engine(false);
    Sfx.pump(false);
    ui.emit();
    emit();
  }

  void closeGarage() {
    if (scene != GameScene.garage) {
      return;
    }
    scene = _garageReturn;
    paused = false;
    ui.emit();
    emit();
  }

  void togglePause() {
    if (scene != GameScene.playing) {
      return;
    }
    paused = !paused;
    if (paused) {
      Sfx.engine(false);
      Sfx.pump(false);
    }
    ui.emit();
  }

  // --- Ввод ----------------------------------------------------------------

  void setJoystick(double dx, double dy, double mag, double ox, double oy) {
    joyOriginX = ox;
    joyOriginY = oy;
    joyMag = mag.clamp(0.0, 1.0);
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len > 0.0001) {
      joyX = dx / len;
      joyY = dy / len;
    }
    joyActive = true;
    if (joyMag > 0.15 && !inQueue && !stalled) {
      if (!engineOn) {
        engineOn = true;
        if (player.fuel > 0) {
          Sfx.engine(true);
        }
      }
    }
  }

  void clearJoystick() {
    joyActive = false;
    joyMag = 0;
  }

  void toggleEngine() {
    if (player.fuel <= 0) {
      _addBanner('БАК ПУСТ — НЕ ЗАВЕДЁТСЯ', 8);
      return;
    }
    engineOn = !engineOn;
    Sfx.engine(engineOn);
    _addBanner(engineOn ? 'ДВИГАТЕЛЬ ЗАПУЩЕН' : 'ДВИГАТЕЛЬ ЗАГЛУШЕН', engineOn ? 12 : 11);
    ui.emit();
  }

  void honk() {
    Sfx.horn();
    _addBanner('БИИИП!', 10);
  }

  void leaveQueue() {
    final GasStation? st = queueStation;
    final QueueCar? qc = queueCar;
    if (st == null || qc == null) {
      return;
    }
    st.queue.remove(qc);
    if (st.queue.isNotEmpty && st.queue[0].isPlayer) {
      // не должно случаться, но подстрахуемся
    }
    player.x = qc.x;
    player.y = qc.y;
    player.speed = 0;
    queueStation = null;
    queueCar = null;
    joinCooldown = 2.5;
    refueledThisVisit = 0;
    Sfx.pump(false);
    _addBanner('ВЫ ВЫШЛИ ИЗ ОЧЕРЕДИ', 11);
    ui.emit();
  }

  void _joinQueue(GasStation st) {
    final QueueCar qc = QueueCar(
      color: spec.color,
      w: spec.w.toDouble(),
      h: spec.h.toDouble(),
      isPlayer: true,
      slot: st.queue.length,
      x: player.x,
      y: player.y,
      angle: st.queueAngle,
    );
    st.queue.add(qc);
    if (st.queue.length == 1) {
      st.shiftTimer = 0;
    }
    queueStation = st;
    queueCar = qc;
    refueledThisVisit = 0;
    player.speed = 0;
    final int ahead = st.queue.length - 1;
    _addBanner(ahead <= 0 ? 'ВЫ У КОЛОНКИ!' : 'В ОЧЕРЕДИ: впереди $ahead', 3);
    Sfx.ui();
    ui.emit();
  }

  // --- Основной цикл -------------------------------------------------------

  void update(double dt) {
    if (dt <= 0) {
      return;
    }
    time += dt;

    for (int i = banners.length - 1; i >= 0; i--) {
      banners[i].life -= dt;
      if (!banners[i].alive) {
        banners.removeAt(i);
      }
    }
    for (int i = texts.length - 1; i >= 0; i--) {
      texts[i].update(dt);
      if (!texts[i].alive) {
        texts.removeAt(i);
      }
    }
    for (int i = particles.length - 1; i >= 0; i--) {
      particles[i].update(dt);
      if (!particles[i].alive) {
        particles.removeAt(i);
      }
    }
    for (int i = puffs.length - 1; i >= 0; i--) {
      puffs[i].update(dt);
      if (!puffs[i].alive) {
        puffs.removeAt(i);
      }
    }

    if (scene != GameScene.playing || paused) {
      emit();
      return;
    }

    _updatePlayer(dt);
    _updateStationQueues(dt);
    _updateStations(dt);
    city.updateTraffic(dt);
    _updateJobs(dt);
    _updateCanisters(dt);
    _updateRumors(dt);
    _updateBannersHint(dt);
    _checkGoal(dt);
    _updateStall(dt);
    updateCamera();

    emit();
  }

  void _updatePlayer(double dt) {
    if (joinCooldown > 0) {
      joinCooldown -= dt;
    }

    if (inQueue) {
      // В очереди машина стоит: работает только холостой расход.
      if (engineOn && player.fuel > 0) {
        player.fuel -= 0.02 * consumptionMult * dt;
        if (player.fuel <= 0) {
          player.fuel = 0;
          engineOn = false;
          Sfx.engine(false);
        }
      }
      return;
    }

    // Физика вождения.
    if (!stalled && engineOn && joyMag > 0.15) {
      final double desired = math.atan2(joyY, joyX);
      double diff = desired - player.angle;
      while (diff > math.pi) {
        diff -= math.pi * 2;
      }
      while (diff < -math.pi) {
        diff += math.pi * 2;
      }
      final double maxStep = spec.turnRate * dt * (0.5 + 0.5 * (player.speed / spec.maxSpeed));
      if (diff.abs() <= maxStep) {
        player.angle = desired;
      } else {
        player.angle += maxStep * diff.sign;
      }
      final double targetSpeed = spec.maxSpeed * joyMag;
      player.speed += (targetSpeed - player.speed) * math.min(1.0, dt * 2.6);
    } else {
      player.speed -= player.speed * math.min(1.0, dt * 2.2);
      if (player.speed.abs() < 0.6) {
        player.speed = 0;
      }
    }

    player.x += math.cos(player.angle) * player.speed * dt;
    player.y += math.sin(player.angle) * player.speed * dt;
    distance += player.speed * dt;
    score += (player.speed * dt * 0.05).round();

    // Топливо.
    if (engineOn && !stalled) {
      final double burnPerSec = (0.025 + 0.25 * (player.speed / spec.maxSpeed).clamp(0.0, 1.0)) *
          consumptionMult *
          (player.speed < 1 ? 1.0 : 1.0);
      final double burn = burnPerSec * dt;
      player.fuel -= burn;
      if (player.fuel <= 0) {
        player.fuel = 0;
        Sfx.engine(false);
      }
    }

    // Столкновения со зданиями.
    if (city.resolveCar(player, 7)) {
      if (player.speed.abs() > 30) {
        player.speed *= -0.15;
        _crash();
      } else {
        player.speed = 0;
      }
    }

    // Столкновения с трафиком.
    for (final NpcCar c in city.traffic) {
      final double dx = c.x - player.x;
      final double dy = c.y - player.y;
      final double d2 = dx * dx + dy * dy;
      if (d2 < 13 * 13 && d2 > 0.01) {
        final double d = math.sqrt(d2);
        final double push = (13 - d) / 2 + 0.5;
        player.x -= dx / d * push;
        player.y -= dy / d * push;
        c.x += dx / d * push * 0.3;
        c.y += dy / d * push * 0.3;
        if (player.speed.abs() > 26) {
          player.speed *= -0.12;
          _crash();
        } else {
          player.speed *= 0.5;
        }
      }
    }

    // Выезд за город.
    player.x = player.x.clamp(8.0, kCityW - 8.0);
    player.y = player.y.clamp(8.0, kCityH - 8.0);

    // Попытка встать в очередь.
    if (!inQueue && joinCooldown <= 0 && player.speed.abs() < 26) {
      for (final GasStation st in stations) {
        if (st.state != StationState.open) {
          continue;
        }
        final double dx = player.x - st.enterX;
        final double dy = player.y - st.enterY;
        if (dx * dx + dy * dy < 30 * 30) {
          if (st.queue.length >= kMaxQueue) {
            joinCooldown = 3;
            _addBanner('ОЧЕРЕДЬ БИТКОМ', 8);
          } else {
            _joinQueue(st);
          }
          break;
        }
      }
    }

    // Дом.
    if (_nearHome()) {
      if (!homeBonusUsed && player.fuel < tankCap - 0.5) {
        homeBonusUsed = true;
        final double add = math.min(2.0, tankCap - player.fuel);
        player.fuel += add;
        texts.add(FloatText(player.x, player.y - 12, '+${add.toStringAsFixed(0)} л (дом)', 12));
        _addBanner('ДОМАШНИЙ ЗАПАС +${add.toStringAsFixed(0)} л', 12);
      }
    }

    // Заказы.
    final DeliveryJob? j = job;
    if (j != null) {
      final double pdx = player.x - j.pickX;
      final double pdy = player.y - j.pickY;
      if (!j.picked && pdx * pdx + pdy * pdy < 15 * 15) {
        j.picked = true;
        Sfx.coin();
        _addBanner('ГРУЗ ПРИНЯТ → ВЕЗИ К ФЛАЖКУ', 13);
      } else if (j.picked) {
        final double ddx = player.x - j.dropX;
        final double ddy = player.y - j.dropY;
        if (ddx * ddx + ddy * ddy < 15 * 15) {
          money += j.reward;
          dayEarned += j.reward;
          score += j.reward ~/ 3;
          jobsDone++;
          reputation += 1;
          Sfx.coin();
          _addBanner('ЗАКАЗ ДОСТАВЛЕН +${j.reward}₽', 10);
          texts.add(FloatText(player.x, player.y - 12, '+${j.reward}₽', 10));
          job = null;
          newJobTimer = 2.5;
          ui.emit();
        }
      }
    }
  }

  void _crash() {
    Sfx.crash();
    puffs.add(Puff(player.x, player.y, 12, 7, life: 0.3));
    for (int i = 0; i < 5; i++) {
      final double a = rnd.nextDouble() * math.pi * 2;
      particles.add(Particle(player.x, player.y, math.cos(a) * 40, math.sin(a) * 40, 10, 0.3));
    }
    if (lvl('bumper') == 0 && rnd.nextDouble() < 0.4) {
      final double cost = 15 + rnd.nextDouble() * 20;
      money = math.max(0, money - cost.round());
      texts.add(FloatText(player.x, player.y - 10, '-${cost.round()}₽ ремонт', 8));
      ui.emit();
    }
  }

  // --- АЗС -----------------------------------------------------------------

  void _updateStationQueues(double dt) {
    for (final GasStation st in stations) {
      // Машины подтягиваются к своим местам.
      for (int i = 0; i < st.queue.length; i++) {
        final QueueCar q = st.queue[i];
        q.slot = i;
        final double tx = st.slotX(i);
        final double ty = st.slotY(i);
        final double dx = tx - q.x;
        final double dy = ty - q.y;
        final double d = math.sqrt(dx * dx + dy * dy);
        if (d > 0.4) {
          final double step = math.min(d, 34 * dt);
          q.x += dx / d * step;
          q.y += dy / d * step;
        }
        q.progress = (1 - (d / GasStation.spacing)).clamp(0.0, 1.0);
      }

      // Игрока в очереди ведёт сама очередь.
      if (queueStation == st && queueCar != null) {
        player.x = queueCar!.x;
        player.y = queueCar!.y;
        player.speed = 0;
        double diff = st.queueAngle - player.angle;
        while (diff > math.pi) {
          diff -= math.pi * 2;
        }
        while (diff < -math.pi) {
          diff += math.pi * 2;
        }
        player.angle += diff * math.min(1.0, dt * 6);
      }

      if (st.queue.isEmpty) {
        continue;
      }

      final QueueCar front = st.queue[0];

      // Пустая АЗС: очередь разъезжается (кроме игрока).
      if (st.state == StationState.empty) {
        st.reopenTimer -= dt;
        if (st.shiftTimer <= 0) {
          if (!front.isPlayer) {
            st.queue.removeAt(0);
            st.shiftTimer = 1.4;
          }
        } else {
          st.shiftTimer -= dt;
        }
        if (st.reopenTimer <= 0 && st.state == StationState.empty) {
          st.state = StationState.open;
          st.liters = st.capacity * (0.55 + rnd.nextDouble() * 0.45);
          st.reopenTimer = 0;
          _addBanner('${st.name}: ЗАВОЗ! АЗС ОТКРЫЛАСЬ', 12);
          _stationFlash(st);
        }
        continue;
      }

      if (!st.working) {
        continue;
      }

      if (front.isPlayer) {
        _refuelPlayer(st, dt);
      } else {
        st.shiftTimer -= dt;
        if (st.shiftTimer <= 0) {
          st.queue.removeAt(0);
          final QueueCar? next = st.queue.isEmpty ? null : st.queue[0];
          if (next != null) {
            st.shiftTimer = next.isPlayer ? 0 : (3.5 + rnd.nextDouble() * 4);
          }
        }
      }

      // Игрок не у колонки — колонка для него молчит.
      if (!front.isPlayer) {
        _setPumpSound(false);
      }
    }
  }

  void _refuelPlayer(GasStation st, double dt) {
    if (player.fuel >= tankCap - 0.01) {
      _setPumpSound(false);
      return;
    }
    if (money <= 0) {
      _setPumpSound(false);
      if (rnd.nextDouble() < 0.02) {
        _addBanner('ДЕНЬГИ КОНЧИЛИСЬ', 8);
      }
      return;
    }
    final double price = st.price * priceFactor;
    double amount = st.refuelRate * fastPumpMult * dt;
    amount = math.min(amount, tankCap - player.fuel);
    amount = math.min(amount, st.liters);
    amount = math.min(amount, money / price);
    if (st.limit > 0) {
      amount = math.min(amount, st.limit - refueledThisVisit);
    }
    if (amount <= 0) {
      _setPumpSound(false);
      return;
    }
    final double cost = amount * price;
    player.fuel += amount;
    st.liters -= amount;
    refueledThisVisit += amount;
    money = math.max(0, (money - cost).round());
    litersBought += amount;
    dayLiters += amount;
    score += (amount * 2).round();
    st.flash = 0.25;
    _setPumpSound(true);

    if (rnd.nextDouble() < 0.5) {
      puffs.add(Puff(st.x, st.y - 2, 5 + rnd.nextDouble() * 3, 12, life: 0.3));
    }
    if (player.fuel >= tankCap - 0.05) {
      _addBanner('БАК ПОЛОН — МОЖНО УЕЗЖАТЬ', 12);
      Sfx.full();
      _setPumpSound(false);
      ui.emit();
    } else if (st.limit > 0 && refueledThisVisit >= st.limit - 0.01) {
      _addBanner('ЛИМИТ ${st.limit.toStringAsFixed(0)} Л ИСЧЕРПАН', 8);
      _setPumpSound(false);
    }
  }

  void _setPumpSound(bool on) {
    if (on && _pumpSound <= 0) {
      Sfx.pump(true);
      _pumpSound = 1;
    } else if (!on && _pumpSound > 0) {
      Sfx.pump(false);
      _pumpSound = 0;
    }
  }

  void _updateStations(double dt) {
    for (final GasStation st in stations) {
      if (st.flash > 0) {
        st.flash = math.max(0, st.flash - dt);
      }
      if (st.brokenTimer > 0) {
        st.brokenTimer -= dt;
        if (st.brokenTimer <= 0) {
          _addBanner('${st.name}: КОЛОНКА ПОЧИНЕНА', 12);
          _stationFlash(st);
        }
      }
      if (st.limitTimer > 0) {
        st.limitTimer -= dt;
        if (st.limitTimer <= 0) {
          st.limit = 0;
        }
      }
      if (st.tankerTimer > 0) {
        st.tankerTimer -= dt;
        if (st.tankerTimer <= 0) {
          st.liters = st.capacity;
          st.state = StationState.open;
          _addBanner('${st.name}: БЕНЗОВОЗ ПРИБЫЛ!', 12);
          Sfx.event();
          _stationFlash(st);
        }
      }

      if (st.state != StationState.open) {
        continue;
      }

      st.eventTimer -= dt;
      if (st.eventTimer <= 0) {
        st.eventTimer = 16 + rnd.nextDouble() * 24 - lvl('radio') * 4;
        if (st.eventTimer < 8) {
          st.eventTimer = 8;
        }
        _rollStationEvent(st);
      }
    }
  }

  void _rollStationEvent(GasStation st) {
    final double roll = rnd.nextDouble();
    if (roll < 0.26) {
      st.price = (28 + rnd.nextDouble() * 20).clamp(22.0, 58.0);
      st.lastEvent = 'ЦЕНА ОБНОВЛЕНА';
      _addBanner('${st.name}: ЦЕНА ${st.price.toStringAsFixed(0)}₽/л', 10);
    } else if (roll < 0.48) {
      final double loss = 40 + rnd.nextDouble() * 80;
      st.liters -= loss;
      if (st.liters <= 0) {
        st.liters = 0;
        st.state = StationState.empty;
        st.reopenTimer = 16 + rnd.nextDouble() * 22;
        st.lastEvent = 'БЕНЗИН КОНЧИЛСЯ';
        _addBanner('${st.name}: БЕНЗИН КОНЧИЛСЯ!', 8);
        Sfx.event();
        _stationFlash(st);
      } else {
        _addBanner('${st.name}: ОСТАЛОСЬ ${st.liters.toStringAsFixed(0)} л', 9);
      }
    } else if (roll < 0.62) {
      st.limit = <double>[10, 15, 20][rnd.nextInt(3)];
      st.limitTimer = 22;
      st.lastEvent = 'ЛИМИТ ${st.limit.toStringAsFixed(0)} Л';
      _addBanner('${st.name}: НЕ БОЛЕЕ ${st.limit.toStringAsFixed(0)} Л В РУКИ', 9);
    } else if (roll < 0.74) {
      st.tankerTimer = 8 + rnd.nextDouble() * 8;
      st.lastEvent = 'БЕНЗОВОЗ В ПУТИ';
      _addBanner('${st.name}: БЕНЗОВОЗ В ПУТИ', 13);
      for (final QueueCar q in st.queue) {
        q.refuelTime += 0.4;
      }
    } else if (roll < 0.86) {
      st.brokenTimer = 6 + rnd.nextDouble() * 6;
      st.lastEvent = 'КОЛОНКА СЛОМАЛАСЬ';
      _addBanner('${st.name}: КОЛОНКА СЛОМАЛАСЬ!', 8);
      Sfx.event();
    } else {
      st.shiftTimer += 2;
      st.lastEvent = 'ОЧЕРЕДЬ ДВИЖЕТСЯ';
      if (st.queue.any((QueueCar q) => q.isPlayer)) {
        _addBanner('КТО-ТО ЛЕЗЕТ БЕЗ ОЧЕРЕДИ!', 8);
      }
    }
  }

  void _stationFlash(GasStation st) {
    st.flash = 0.6;
  }

  // --- Слухи ---------------------------------------------------------------

  void _updateRumors(double dt) {
    rumorTimer -= dt;
    if (rumorTimer > 0) {
      return;
    }
    rumorTimer = 16 + rnd.nextDouble() * 12 - lvl('radio') * 4;
    if (rumorTimer < 7) {
      rumorTimer = 7;
    }
    if (stations.isEmpty) {
      return;
    }
    final GasStation st = stations[rnd.nextInt(stations.length)];
    final bool accurate = lvl('navigator') > 0 || rnd.nextDouble() < 0.67;
    if (accurate) {
      String state;
      if (st.state == StationState.empty) {
        state = 'ПУСТО';
      } else if (st.brokenTimer > 0) {
        state = 'КОЛОНКА НЕ РАБОТАЕТ';
      } else {
        state = '${st.liters.toStringAsFixed(0)} л';
      }
      _addBanner('РАДИО: ${st.name} — ${st.price.toStringAsFixed(0)}₽ • $state', 6);
    } else {
      final String lie = rnd.nextBool()
          ? 'ПУСТО, НЕ ЕДЬ'
          : 'ЗАВОЗ, МНОГО БЕНЗИНА (${(st.price - 6).clamp(18, 60).toStringAsFixed(0)}₽)';
      _addBanner('СЛУХ: ${st.name} — $lie', 2);
    }
  }

  void _updateBannersHint(double dt) {
    if (tutorialTimer > 0) {
      tutorialTimer -= dt;
      if (tutorialTimer <= 0) {
        _addBanner('СОВЕТ: В ОЧЕРЕДИ ГЛУШИТЕ ДВИГАТЕЛЬ', 13);
      }
    }
    if (!_lowFuelWarned && fuelRatio < 0.18 && fuelRatio > 0) {
      _lowFuelWarned = true;
      _addBanner('НИЗКИЙ УРОВЕНЬ ТОПЛИВА!', 8);
      Sfx.low();
    }
    if (fuelRatio > 0.35) {
      _lowFuelWarned = false;
    }
  }

  // --- Заказы и канистры ---------------------------------------------------

  void _updateJobs(double dt) {
    if (job == null) {
      newJobTimer -= dt;
      if (newJobTimer <= 0) {
        newJobTimer = 999;
        job = _makeJob();
        _addBanner('НОВЫЙ ЗАКАЗ: К ОРАНЖЕВОМУ ФЛАЖКУ', 13);
        Sfx.event();
      }
      return;
    }
  }

  DeliveryJob _makeJob() {
    final double px = 40 + rnd.nextDouble() * (kCityW - 80);
    final double py = 40 + rnd.nextDouble() * (kCityH - 80);
    double dx = 0;
    double dy = 0;
    for (int i = 0; i < 30; i++) {
      dx = 40 + rnd.nextDouble() * (kCityW - 80);
      dy = 40 + rnd.nextDouble() * (kCityH - 80);
      final double ddx = dx - px;
      final double ddy = dy - py;
      if (ddx * ddx + ddy * ddy > 240 * 240) {
        break;
      }
    }
    final int reward = 300 + rnd.nextInt(4) * 90;
    return DeliveryJob(px, py, dx, dy, reward);
  }

  void _updateCanisters(double dt) {
    canisterTimer -= dt;
    if (canisterTimer <= 0 && canisters.length < 8) {
      canisterTimer = 10 + rnd.nextDouble() * 10;
      _spawnCanister();
    }
    for (final Canister c in canisters) {
      if (c.taken) {
        continue;
      }
      final double dx = player.x - c.x;
      final double dy = player.y - c.y;
      if (dx * dx + dy * dy < 13 * 13) {
        c.taken = true;
        final double add = math.min(3.5, tankCap - player.fuel);
        player.fuel += add;
        money += 25;
        score += 20;
        dayEarned += 25;
        Sfx.coin();
        texts.add(FloatText(c.x, c.y - 8, '+${add.toStringAsFixed(1)} л', 12));
        _addBanner('КАНИСТРА: +${add.toStringAsFixed(1)} л и +25₽', 12);
        ui.emit();
      }
    }
    for (int i = canisters.length - 1; i >= 0; i--) {
      if (canisters[i].taken) {
        canisters.removeAt(i);
      }
    }
  }

  // --- Нулевой бак и эвакуатор --------------------------------------------

  void _updateStall(double dt) {
    if (player.fuel <= 0 && !stalled && !inQueue) {
      if (reserveLeft > 0.4) {
        final double use = math.min(reserveLeft, 6.0);
        reserveLeft -= use;
        player.fuel += use;
        _addBanner('КАНИСТРА: +${use.toStringAsFixed(0)} л АВАРИЙНОГО ЗАПАСА', 12);
        Sfx.coin();
        engineOn = true;
        Sfx.engine(true);
      } else {
        stalled = true;
        stallTimer = 4;
        engineOn = false;
        Sfx.engine(false);
        Sfx.low();
        _addBanner('БЕНЗИН КОНЧИЛСЯ! ЖДЁМ ЭВАКУАТОР...', 8);
      }
    }
    if (!stalled) {
      return;
    }
    player.speed = 0;
    stallTimer -= dt;
    if (stallTimer > 0) {
      return;
    }
    if (money >= towCost) {
      money -= towCost;
      final GasStation st = _nearestStation();
      player.x = st.enterX;
      player.y = st.enterY;
      stalled = false;
      engineOn = false;
      Sfx.siren();
      _addBanner('ЭВАКУАТОР: -$towCost₽ — ВЫ У ${st.name}', 11);
      ui.emit();
    } else {
      _gameOver();
    }
  }

  GasStation _nearestStation() {
    GasStation best = stations.first;
    double bestD = double.infinity;
    for (final GasStation st in stations) {
      final double dx = st.x - player.x;
      final double dy = st.y - player.y;
      final double d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = st;
      }
    }
    return best;
  }

  GasStation? get nearestStation {
    if (stations.isEmpty) {
      return null;
    }
    return _nearestStation();
  }

  // --- Цели и конец игры ---------------------------------------------------

  void _checkGoal(double dt) {
    if (mode != GameMode.campaign) {
      return;
    }
    if (inQueue) {
      daySurvive += dt;
    }
    final DayGoal g = goal!;
    bool done = false;
    switch (g.kind) {
      case GoalKind.refuelLiters:
        done = dayLiters >= g.target;
        break;
      case GoalKind.earnMoney:
        done = dayEarned >= g.target;
        break;
      case GoalKind.surviveTime:
        done = daySurvive >= g.target;
        break;
      case GoalKind.reachHome:
        done = _nearHome() && player.fuel >= g.target;
        break;
      case GoalKind.buyUpgrade:
        done = dayUpgrades >= 1;
        break;
    }
    if (done) {
      _completeDay();
    }
  }

  void _completeDay() {
    if (scene != GameScene.playing) {
      return;
    }
    Sfx.win();
    _addBanner('ДЕНЬ ВЫПОЛНЕН!', 12);
    if (day >= dayGoals.length) {
      campaignWon = true;
      _gameOver();
      return;
    }
    scene = GameScene.dayResult;
    paused = true;
    Sfx.engine(false);
    Sfx.pump(false);
    leaveQueue();
    ui.emit();
    emit();
  }

  void nextDay() {
    if (scene != GameScene.dayResult) {
      return;
    }
    day++;
    money += 200;
    player.fuel = math.min(tankCap, 25);
    dayLiters = 0;
    dayEarned = 0;
    daySurvive = 0;
    dayUpgrades = 0;
    dayHomeReached = false;
    homeBonusUsed = false;
    _lowFuelWarned = false;
    player.x = homeX;
    player.y = homeY - 22;
    player.angle = -math.pi / 2;
    player.speed = 0;
    engineOn = true;
    scene = GameScene.playing;
    paused = false;
    _addBanner('ДЕНЬ $day: ${goal!.title}', 3);
    newJobTimer = 1;
    ui.emit();
    emit();
  }

  void retryDay() {
    if (mode != GameMode.campaign) {
      newGame(mode);
      return;
    }
    final int keepDay = day;
    newGame(GameMode.campaign);
    day = keepDay;
    player.fuel = math.min(tankCap, 15);
    money = 300;
    _addBanner('ПОВТОР ДНЯ $day', 3);
  }

  void _gameOver() {
    if (scene == GameScene.gameOver) {
      return;
    }
    scene = GameScene.gameOver;
    paused = false;
    stalled = false;
    Sfx.engine(false);
    Sfx.pump(false);
    if (!campaignWon) {
      Sfx.lose();
    }
    score += jobsDone * 120;
    if (score > bestScore) {
      bestScore = score;
      newRecord = true;
      final void Function(int)? cb = onBestChanged;
      if (cb != null) {
        cb(score);
      }
    }
    ui.emit();
    emit();
  }

  // --- Гараж ---------------------------------------------------------------

  void buyUpgrade(String id) {
    final Upgrade up = kUpgrades.firstWhere((Upgrade u) => u.id == id, orElse: () => kUpgrades.first);
    if (up.id != id) {
      return;
    }
    final int level = lvl(id);
    if (level >= up.maxLevel) {
      return;
    }
    final int price = up.priceFor(level);
    if (money < price) {
      _addBanner('НЕ ХВАТАЕТ ДЕНЕГ', 8);
      return;
    }
    money -= price;
    levels[id] = level + 1;
    if (id == 'tank') {
      player.fuel += 10;
    }
    if (id == 'canister') {
      reserveLeft = reserveCap;
    }
    dayUpgrades++;
    Sfx.coin();
    _addBanner('${up.title}: УРОВЕНЬ ${level + 1}', 12);
    final void Function()? cb = onGarageChanged;
    if (cb != null) {
      cb();
    }
    ui.emit();
  }

  void buyCar(String id) {
    final CarSpec s = carById(id);
    if (ownedCars.contains(id)) {
      selectCar(id);
      return;
    }
    if (money < s.price) {
      _addBanner('НЕ ХВАТАЕТ ДЕНЕГ', 8);
      ui.emit();
      return;
    }
    money -= s.price;
    ownedCars.add(id);
    currentCarId = id;
    final double oldFuel = player.fuel;
    player.spec = s;
    player.fuel = math.min(oldFuel, tankCap);
    reserveLeft = reserveCap;
    dayUpgrades++;
    Sfx.coin();
    _addBanner('КУПЛЕНО: ${s.title}', 12);
    final void Function()? cb = onGarageChanged;
    if (cb != null) {
      cb();
    }
    ui.emit();
  }

  /// Применить сохранённый гараж (при запуске приложения).
  void applyGarage(Set<String> cars, Map<String, int> savedLevels, String current) {
    ownedCars
      ..clear()
      ..addAll(cars)
      ..add('sedan');
    levels
      ..clear()
      ..addAll(savedLevels);
    currentCarId = ownedCars.contains(current) ? current : 'sedan';
    final double oldFuel = player.fuel;
    player.spec = carById(currentCarId);
    player.fuel = math.min(oldFuel, tankCap);
    reserveLeft = reserveCap;
    emit();
  }

  void selectCar(String id) {
    if (!ownedCars.contains(id)) {
      return;
    }
    currentCarId = id;
    final double oldFuel = player.fuel;
    player.spec = carById(id);
    player.fuel = math.min(oldFuel, tankCap);
    reserveLeft = reserveCap;
    Sfx.ui();
    final void Function()? cb = onGarageChanged;
    if (cb != null) {
      cb();
    }
    ui.emit();
  }

  // --- Вспомогательное -----------------------------------------------------

  void _addBanner(String text, int color) {
    banners.insert(0, Notice(text, color));
    if (banners.length > 4) {
      banners.removeLast();
    }
    ui.emit();
  }

  String get fuelText => '${player.fuel.toStringAsFixed(1)} / ${tankCap.toStringAsFixed(0)} л';

  String get moneyText => '$money ₽';

  /// Кто первый в очереди выбранной АЗС (для HUD).
  int queueAheadOf(GasStation st) {
    final QueueCar? qc = queueCar;
    if (qc == null || queueStation != st) {
      return -1;
    }
    return qc.slot;
  }
}
