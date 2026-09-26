import 'package:flutter_test/flutter_test.dart';
import 'package:litr_do_doma/engine/game.dart';
import 'package:litr_do_doma/engine/stations.dart';
import 'package:litr_do_doma/engine/upgrades.dart';
import 'package:litr_do_doma/engine/vehicles.dart';
import 'package:litr_do_doma/services/sfx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Sfx.sound = false;
    Sfx.vibro = false;
  });

  test('свободная поездка стартует с полным баком', () {
    final GameEngine engine = GameEngine();
    engine.newGame(GameMode.freeRide);
    expect(engine.scene, GameScene.playing);
    expect(engine.player.fuel, closeTo(engine.tankCap, 0.001));
    expect(engine.stations.length, 4);
  });

  test('выживание начинается с трёх литров', () {
    final GameEngine engine = GameEngine();
    engine.newGame(GameMode.survival);
    expect(engine.player.fuel, closeTo(3, 0.001));
    expect(engine.money, 180);
  });

  test('у кампании есть цель дня', () {
    final GameEngine engine = GameEngine();
    engine.newGame(GameMode.campaign);
    expect(engine.goal, isNotNull);
    expect(engine.day, 1);
  });

  test('на АЗС стоят очереди', () {
    final GameEngine engine = GameEngine();
    engine.newGame(GameMode.freeRide);
    final int total = engine.stations.fold<int>(0, (int sum, GasStation st) => sum + st.queue.length);
    expect(total, greaterThan(0));
  });

  test('игрок встаёт в очередь у входа', () {
    final GameEngine engine = GameEngine();
    engine.newGame(GameMode.freeRide);
    final GasStation st = engine.stations.first;
    engine.player.x = st.enterX;
    engine.player.y = st.enterY;
    engine.player.speed = 0;
    for (int i = 0; i < 20; i++) {
      engine.update(1 / 60);
    }
    expect(engine.inQueue, isTrue);
  });

  test('заправка у колонки увеличивает бак и тратит деньги', () {
    final GameEngine engine = GameEngine();
    engine.newGame(GameMode.freeRide);
    final GasStation st = engine.stations.first;
    engine.player.x = st.enterX;
    engine.player.y = st.enterY;
    for (int i = 0; i < 20; i++) {
      engine.update(1 / 60);
    }
    expect(engine.inQueue, isTrue);
    // Убираем NPC впереди — игрок мгновенно у колонки.
    st.queue.removeWhere((QueueCar q) => !q.isPlayer);
    engine.player.fuel = 5;
    final double beforeFuel = engine.player.fuel;
    final int beforeMoney = engine.money;
    for (int i = 0; i < 120; i++) {
      engine.update(1 / 60);
    }
    expect(engine.player.fuel, greaterThan(beforeFuel));
    expect(engine.money, lessThan(beforeMoney));
  });

  test('без бензина и денег игра заканчивается', () {
    final GameEngine engine = GameEngine();
    engine.newGame(GameMode.freeRide);
    // Подальше от дома и канистр, чтобы не было случайной подпитки.
    engine.player.x = 320;
    engine.player.y = 320;
    engine.canisters.clear();
    engine.job = null;
    engine.newJobTimer = 9999;
    engine.player.fuel = 0;
    engine.money = 0;
    engine.reserveLeft = 0;
    for (int i = 0; i < 60; i++) {
      engine.update(0.2);
    }
    expect(engine.scene, GameScene.gameOver);
  });

  test('улучшение поднимает уровень и списывает деньги', () {
    final GameEngine engine = GameEngine();
    engine.newGame(GameMode.freeRide);
    engine.money = 5000;
    engine.buyUpgrade('tank');
    expect(engine.lvl('tank'), 1);
    expect(engine.money, lessThan(5000));
  });

  test('таблица машин согласована', () {
    expect(carById('van').tank, greaterThan(carById('hatch').tank));
    expect(carById('hatch').consumption, lessThan(carById('van').consumption));
    expect(kUpgrades, isNotEmpty);
  });

  test('долгий прогон не ломает состояние', () {
    final GameEngine engine = GameEngine();
    engine.newGame(GameMode.freeRide);
    engine.setJoystick(1, 0, 1, 90, 200);
    for (int i = 0; i < 900; i++) {
      engine.update(1 / 60);
    }
    expect(engine.scene, isNotNull);
    expect(engine.player.fuel, lessThanOrEqualTo(engine.tankCap + 0.001));
  });
}
