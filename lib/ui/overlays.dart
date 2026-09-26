import 'package:flutter/material.dart';

import '../engine/game.dart';
import '../engine/palette.dart';
import '../engine/upgrades.dart';
import '../engine/vehicles.dart';
import '../services/sfx.dart';

/// Заголовок в ретро-стиле.
class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFFE9C35B), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
    );
  }
}

/// Непрозрачная подложка, перехватывающая касания под меню.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: P.alpha(1, 0.94),
        child: SafeArea(child: child),
      ),
    );
  }
}

Widget _buttonLabel(String text, {double size = 16}) => Text(
      text,
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: 1.0),
    );

/// Главное меню.
class TitleOverlay extends StatefulWidget {
  const TitleOverlay({super.key, required this.engine});

  final GameEngine engine;

  @override
  State<TitleOverlay> createState() => _TitleOverlayState();
}

class _TitleOverlayState extends State<TitleOverlay> {
  @override
  Widget build(BuildContext context) {
    final GameEngine engine = widget.engine;
    return _Backdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('logo-app.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 10),
              Text(
                'Бензин на нуле. Очередь на километр.',
                textAlign: TextAlign.center,
                style: TextStyle(color: P.get(6), fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(
                'РЕКОРД: ${engine.bestScore}',
                style: const TextStyle(color: Color(0xFFE9C35B), fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              _modeButton('СВОБОДНАЯ ПОЕЗДКА', GameMode.freeRide),
              _modeButton('ВЫЖИВАНИЕ (3 Л)', GameMode.survival),
              _modeButton('КАМПАНИЯ: 7 ДНЕЙ', GameMode.campaign),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Sfx.ui();
                    engine.openGarage();
                  },
                  icon: const Icon(Icons.build_circle_outlined),
                  label: _buttonLabel('ГАРАЖ', size: 14),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showHelp(context),
                      child: const Text('КАК ИГРАТЬ', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => Sfx.sound = !Sfx.sound),
                      child: Text(Sfx.sound ? 'ЗВУК: ВКЛ' : 'ЗВУК: ВЫКЛ', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: () => setState(() => Sfx.vibro = !Sfx.vibro),
                child: Text(Sfx.vibro ? 'ВИБРАЦИЯ: ВКЛ' : 'ВИБРАЦИЯ: ВЫКЛ', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 10),
              Text('v1.0.0 • бесплатная версия', style: TextStyle(color: P.get(11), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(String text, GameMode mode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: P.get(3),
            foregroundColor: P.get(0),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          onPressed: () {
            Sfx.ui();
            widget.engine.newGame(mode);
          },
          child: _buttonLabel(text, size: 14),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: P.get(1),
        title: const _Title('Как играть'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Нефтеград задыхается без бензина. Ищите работающие АЗС, '
                'вставайте в хвост очереди и не дайте наглым водителям '
                'оставить вас без топлива.',
                style: TextStyle(color: Color(0xFFEEEEEE), height: 1.4),
              ),
              SizedBox(height: 10),
              Text('Управление', style: TextStyle(color: Color(0xFFE9C35B), fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text(
                '• Потяните по экрану — виртуальный джойстик, машина едет за пальцем\n'
                '• Кнопка СТАРТ/СТОП — заглушить двигатель (экономия в очереди)\n'
                '• Кнопка СИГНАЛ — посигналить\n'
                '• В очереди появится кнопка ВЫЙТИ\n'
                '• Кнопка паузы сверху справа',
                style: TextStyle(color: Color(0xFFEEEEEE), height: 1.4),
              ),
              SizedBox(height: 10),
              Text('Мир игры', style: TextStyle(color: Color(0xFFE9C35B), fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text(
                '• АЗС бывают открыты, пусты или на ремонте\n'
                '• Цена и очередь меняются каждые полминуты\n'
                '• Слухи по радио могут врать\n'
                '• Канистры на дорогах дают топливо\n'
                '• Заказы (флажки) приносят деньги\n'
                '• Кончился бензин — вызывайте эвакуатор за 180₽\n'
                '• В гараже покупают машины и улучшения',
                style: TextStyle(color: Color(0xFFEEEEEE), height: 1.4),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ПОНЯТНО'),
          ),
        ],
      ),
    );
  }
}

/// Гараж: покупка машин и улучшений.
class GarageOverlay extends StatelessWidget {
  const GarageOverlay({super.key, required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    return _Backdrop(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(child: _Title('ГАРАЖ')),
                Text(engine.moneyText, style: const TextStyle(color: Color(0xFFE9C35B), fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Sfx.ui();
                    engine.closeGarage();
                  },
                  icon: const Icon(Icons.close),
                  color: P.get(7),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 6),
                    child: Text('АВТОМОБИЛИ', style: TextStyle(color: Color(0xFFE9C35B), fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  for (final CarSpec car in kCars) _carCard(car),
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 6),
                    child: Text('УЛУЧШЕНИЯ', style: TextStyle(color: Color(0xFFE9C35B), fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  for (final Upgrade up in kUpgrades) _upgradeCard(up),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carCard(CarSpec car) {
    final bool owned = engine.ownedCars.contains(car.id);
    final bool current = engine.currentCarId == car.id;
    final bool affordable = engine.money >= car.price;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: P.get(1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: current ? P.get(12) : P.get(5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(width: 12, height: 12, color: P.get(car.color)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(car.title, style: const TextStyle(color: Color(0xFFEEEEEE), fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              if (current)
                Text('ВЫБРАНО', style: TextStyle(color: P.get(12), fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(car.desc, style: TextStyle(color: P.get(6), fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            'Бак ${car.tank.toStringAsFixed(0)} л • расход x${car.consumption.toStringAsFixed(2)} • скорость ${car.maxSpeed.toStringAsFixed(0)}',
            style: TextStyle(color: P.get(11), fontSize: 11),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: owned
                ? OutlinedButton(
                    onPressed: current ? null : () => engine.selectCar(car.id),
                    child: Text(current ? 'АКТИВНА' : 'ВЫБРАТЬ'),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: affordable ? P.get(3) : P.get(5),
                      foregroundColor: affordable ? P.get(0) : P.get(11),
                    ),
                    onPressed: () => engine.buyCar(car.id),
                    child: Text('КУПИТЬ ${car.price}₽'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _upgradeCard(Upgrade up) {
    final int level = engine.lvl(up.id);
    final bool maxed = level >= up.maxLevel;
    final int price = up.priceFor(level);
    final bool affordable = engine.money >= price;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: P.get(1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: P.get(5), width: 2),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(up.title, style: const TextStyle(color: Color(0xFFEEEEEE), fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(up.desc, style: TextStyle(color: P.get(6), fontSize: 11)),
                const SizedBox(height: 3),
                Text('Уровень $level / ${up.maxLevel}', style: TextStyle(color: P.get(11), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          maxed
              ? Text('МАКС', style: TextStyle(color: P.get(12), fontWeight: FontWeight.w900))
              : FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: affordable ? P.get(3) : P.get(5),
                    foregroundColor: affordable ? P.get(0) : P.get(11),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () => engine.buyUpgrade(up.id),
                  child: Text('$price₽', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                ),
        ],
      ),
    );
  }
}

/// Итог дня кампании.
class DayResultOverlay extends StatelessWidget {
  const DayResultOverlay({super.key, required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    return _Backdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Title('ДЕНЬ ${engine.day} ВЫПОЛНЕН'),
              const SizedBox(height: 10),
              Text(engine.goal?.title ?? '', style: TextStyle(color: P.get(6), fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('В кошельке: ${engine.moneyText}', style: const TextStyle(color: Color(0xFFEEEEEE), fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Заработано за день: ${engine.jobsDone} заказов', style: TextStyle(color: P.get(11), fontSize: 12)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: P.get(3), foregroundColor: P.get(0), padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    Sfx.ui();
                    engine.openGarage();
                  },
                  child: _buttonLabel('ЗАЙТИ В ГАРАЖ', size: 14),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: P.get(12), foregroundColor: P.get(0), padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    Sfx.ui();
                    engine.nextDay();
                  },
                  child: _buttonLabel('СЛЕДУЮЩИЙ ДЕНЬ (+200₽)', size: 14),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Sfx.ui();
                    engine.toTitle();
                  },
                  child: const Text('В МЕНЮ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Финал: бак пуст или кампания пройдена.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final bool won = engine.campaignWon;
    return _Backdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                won ? 'КРИЗИС ПЕРЕЖИТ!' : 'БЕНЗИН КОНЧИЛСЯ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: won ? const Color(0xFF70C6A9) : const Color(0xFFD4186C),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                won
                    ? 'Вы продержались неделю в Нефтеграде. Город выжил.'
                    : 'Эвакуатор не приехал: денег на него не хватило.',
                textAlign: TextAlign.center,
                style: TextStyle(color: P.get(6), fontSize: 13),
              ),
              const SizedBox(height: 14),
              Text('ОЧКИ: ${engine.score}', style: const TextStyle(color: Color(0xFFEEEEEE), fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Заработано: ${engine.moneyText} • Заказов: ${engine.jobsDone}', style: TextStyle(color: P.get(6), fontSize: 13)),
              const SizedBox(height: 6),
              Text(
                engine.newRecord ? 'НОВЫЙ РЕКОРД!' : 'РЕКОРД: ${engine.bestScore}',
                style: const TextStyle(color: Color(0xFFE9C35B), fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              if (!won && engine.mode == GameMode.campaign)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: P.get(3), foregroundColor: P.get(0), padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: () {
                      Sfx.ui();
                      engine.retryDay();
                    },
                    child: _buttonLabel('ПОВТОРИТЬ ДЕНЬ ${engine.day}', size: 15),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: P.get(3), foregroundColor: P.get(0), padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: () {
                      Sfx.ui();
                      engine.newGame(engine.mode);
                    },
                    child: _buttonLabel('ЗАНОВО', size: 15),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Sfx.ui();
                    engine.toTitle();
                  },
                  child: const Text('В МЕНЮ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Пауза.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    return _Backdrop(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('ПАУЗА', style: TextStyle(color: Color(0xFFEEEEEE), fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3)),
            const SizedBox(height: 18),
            SizedBox(
              width: 230,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: P.get(3), foregroundColor: P.get(0)),
                onPressed: () {
                  Sfx.ui();
                  engine.togglePause();
                },
                child: const Text('ПРОДОЛЖИТЬ'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 230,
              child: OutlinedButton(
                onPressed: () {
                  Sfx.ui();
                  engine.openGarage();
                },
                child: const Text('ГАРАЖ'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 230,
              child: OutlinedButton(
                onPressed: () {
                  Sfx.ui();
                  engine.toTitle();
                },
                child: const Text('В МЕНЮ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Кнопки поверх боя: пауза, двигатель, сигнал, выход из очереди.
class HudButtons extends StatelessWidget {
  const HudButtons({super.key, required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    if (engine.scene != GameScene.playing) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              tooltip: 'Пауза',
              icon: const Icon(Icons.pause_circle_outline, size: 28),
              color: P.get(7),
              onPressed: () {
                Sfx.ui();
                engine.togglePause();
              },
            ),
          ),
          Positioned(
            left: 10,
            bottom: 14,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: engine.engineOn ? P.get(10) : P.get(7),
                side: BorderSide(color: engine.engineOn ? P.get(10) : P.get(6), width: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => engine.toggleEngine(),
              child: Text(engine.engineOn ? 'СТОП' : 'СТАРТ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 14,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: P.get(7),
                side: BorderSide(color: P.get(6), width: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => engine.honk(),
              child: const Text('СИГНАЛ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ),
          if (engine.inQueue)
            Positioned(
              left: 0,
              right: 0,
              bottom: 54,
              child: Center(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: P.get(8), foregroundColor: P.get(7)),
                  onPressed: () => engine.leaveQueue(),
                  child: const Text('ВЫЙТИ ИЗ ОЧЕРЕДИ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
