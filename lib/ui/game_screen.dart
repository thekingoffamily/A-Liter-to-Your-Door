import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../engine/game.dart';
import '../engine/palette.dart';
import '../engine/view_transform.dart';
import '../services/sfx.dart';
import '../services/storage.dart';
import 'overlays.dart';
import 'pixel_view.dart';

/// Игровой экран: цикл кадров, ввод и слои интерфейса.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameEngine _engine;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Offset _joyOrigin = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = GameEngine();
    _engine.onBestChanged = (int score) {
      GameStore.saveBest(score);
    };
    _engine.onGarageChanged = () {
      GameStore.saveGarage(_engine.ownedCars, _engine.levels, _engine.currentCarId);
    };
    _restoreSettings();
    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _restoreSettings() async {
    final int best = await GameStore.loadBest();
    final bool sound = await GameStore.loadSound();
    final bool vibro = await GameStore.loadVibro();
    final GarageData garage = await GameStore.loadGarage();
    if (!mounted) {
      return;
    }
    _engine.bestScore = best;
    Sfx.sound = sound;
    Sfx.vibro = vibro;
    _engine.applyGarage(garage.cars, garage.upgrades, garage.currentCar);
    _engine.ui.emit();
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt < 0) {
      dt = 0;
    }
    if (dt > 0.05) {
      dt = 0.05;
    }
    _engine.update(dt);
    if (_engine.scene == GameScene.playing && _engine.engineOn && !_engine.paused) {
      final double ratio = _engine.spec.maxSpeed <= 0 ? 0 : _engine.player.speed / _engine.spec.maxSpeed;
      Sfx.engineVolume(ratio);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _engine.scene == GameScene.playing && !_engine.paused) {
      _engine.togglePause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    Sfx.engine(false);
    Sfx.pump(false);
    _engine.ui.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.get(0),
      body: ListenableBuilder(
        listenable: _engine.ui,
        builder: (BuildContext context, Widget? child) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final ViewTransform transform = ViewTransform(
                Size(constraints.maxWidth, constraints.maxHeight),
              );
              _engine.resizeWorld(transform.worldH);

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (DragStartDetails details) {
                      if (_engine.scene != GameScene.playing || _engine.paused) {
                        return;
                      }
                      _joyOrigin = transform.toVirtual(details.localPosition);
                      _engine.setJoystick(0, 0, 0, _joyOrigin.dx, _joyOrigin.dy);
                    },
                    onPanUpdate: (DragUpdateDetails details) {
                      if (_engine.scene != GameScene.playing || _engine.paused) {
                        return;
                      }
                      final Offset point = transform.toVirtual(details.localPosition);
                      final double dx = point.dx - _joyOrigin.dx;
                      final double dy = point.dy - _joyOrigin.dy;
                      final double len = math.sqrt(dx * dx + dy * dy);
                      const double maxR = 26;
                      final double mag = (len / maxR).clamp(0.0, 1.0);
                      _engine.setJoystick(dx, dy, mag, _joyOrigin.dx, _joyOrigin.dy);
                    },
                    onPanEnd: (DragEndDetails details) => _engine.clearJoystick(),
                    onPanCancel: () => _engine.clearJoystick(),
                    child: PixelView(engine: _engine, transform: transform),
                  ),
                  HudButtons(engine: _engine),
                  if (_engine.scene == GameScene.title) TitleOverlay(engine: _engine),
                  if (_engine.scene == GameScene.garage) GarageOverlay(engine: _engine),
                  if (_engine.scene == GameScene.dayResult) DayResultOverlay(engine: _engine),
                  if (_engine.scene == GameScene.gameOver) GameOverOverlay(engine: _engine),
                  if (_engine.scene == GameScene.playing && _engine.paused) PauseOverlay(engine: _engine),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
