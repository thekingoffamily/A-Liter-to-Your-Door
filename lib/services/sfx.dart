import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Звуковые эффекты и вибрация.
///
/// Короткие 8-bit сэмплы из assets/audio генерируются tool/gen_sounds.dart.
/// На каждый звук держится пул проигрывателей, чтобы эффекты накладывались
/// друг на друга, а не обрывали предыдущий. Двигатель и колонка — циклы.
class Sfx {
  Sfx._();

  static bool sound = true;
  static bool vibro = true;

  static bool _broken = false;
  static bool _ready = false;
  static bool _initializing = false;

  static const Map<String, int> _poolSize = <String, int>{
    'ui': 3,
    'coin': 4,
    'full': 1,
    'horn': 2,
    'crash': 3,
    'event': 2,
    'win': 1,
    'lose': 1,
    'siren': 1,
    'low': 2,
  };

  static const Map<String, double> _volume = <String, double>{
    'ui': 0.4,
    'coin': 0.5,
    'full': 0.6,
    'horn': 0.5,
    'crash': 0.6,
    'event': 0.5,
    'win': 0.7,
    'lose': 0.7,
    'siren': 0.6,
    'low': 0.5,
  };

  static final Map<String, List<AudioPlayer>> _players = <String, List<AudioPlayer>>{};
  static final Map<String, int> _cursor = <String, int>{};
  static AudioPlayer? _engine;
  static AudioPlayer? _pump;
  static double _engineVolume = 0;

  /// Прогревает сэмплы. Безопасно вызывать повторно и в юнит-тестах.
  static Future<void> init() async {
    if (_ready || _broken || _initializing) {
      return;
    }
    _initializing = true;
    try {
      for (final MapEntry<String, int> entry in _poolSize.entries) {
        final List<AudioPlayer> list = <AudioPlayer>[];
        for (int i = 0; i < entry.value; i++) {
          final AudioPlayer player = AudioPlayer();
          await _configure(player, entry.key);
          list.add(player);
        }
        _players[entry.key] = list;
        _cursor[entry.key] = 0;
      }

      _engine = AudioPlayer();
      await _configure(_engine!, 'engine');
      await _engine!.setReleaseMode(ReleaseMode.loop);
      await _engine!.setVolume(0);

      _pump = AudioPlayer();
      await _configure(_pump!, 'pump');
      await _pump!.setReleaseMode(ReleaseMode.loop);
      await _pump!.setVolume(0.5);

      await AudioCache.instance.loadAll(<String>[
        ..._poolSize.keys.map((String name) => 'audio/$name.wav'),
        'audio/engine.wav',
        'audio/pump.wav',
      ]);
      _ready = true;
    } catch (_) {
      // Плагин недоступен (например, в тестах) — просто молчим.
      _broken = true;
    } finally {
      _initializing = false;
    }
  }

  static Future<void> _configure(AudioPlayer player, String name) async {
    try {
      await player.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {
      // Режим поддерживается не везде — не критично.
    }
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(_volume[name] ?? 0.6);
    } catch (_) {
      // Игнорируем: настройка применится по умолчанию.
    }
  }

  static void dispose() {
    for (final List<AudioPlayer> pool in _players.values) {
      for (final AudioPlayer player in pool) {
        try {
          player.dispose();
        } catch (_) {}
      }
    }
    _players.clear();
    _cursor.clear();
    try {
      _engine?.dispose();
      _pump?.dispose();
    } catch (_) {}
    _engine = null;
    _pump = null;
    _ready = false;
  }

  static void _play(String name) {
    if (!sound || _broken || !_ready) {
      return;
    }
    final List<AudioPlayer>? pool = _players[name];
    if (pool == null || pool.isEmpty) {
      return;
    }
    final int index = _cursor[name] ?? 0;
    _cursor[name] = (index + 1) % pool.length;
    final AudioPlayer player = pool[index];
    try {
      player.stop().catchError((Object _) {});
      player.play(AssetSource('audio/$name.wav')).catchError((Object _) {});
    } catch (_) {
      _broken = true;
    }
  }

  static void _haptic(Future<void> Function() action) {
    if (!vibro) {
      return;
    }
    try {
      action().catchError((Object _) {});
    } catch (_) {}
  }

  /// Двигатель: включить/выключить цикл.
  static void engine(bool on) {
    if (_broken || !_ready || _engine == null) {
      return;
    }
    try {
      if (on && sound) {
        _engine!.play(AssetSource('audio/engine.wav')).catchError((Object _) {});
      } else {
        _engine!.stop().catchError((Object _) {});
      }
    } catch (_) {}
  }

  /// Громкость двигателя в зависимости от скорости (0..1).
  static void engineVolume(double v) {
    if (_broken || !_ready || _engine == null) {
      return;
    }
    if (!sound) {
      return;
    }
    final double target = (0.15 + 0.5 * v.clamp(0.0, 1.0));
    if ((target - _engineVolume).abs() < 0.03) {
      return;
    }
    _engineVolume = target;
    try {
      _engine!.setVolume(target).catchError((Object _) {});
    } catch (_) {}
  }

  /// Колонка: звук заправки циклом.
  static void pump(bool on) {
    if (_broken || !_ready || _pump == null) {
      return;
    }
    try {
      if (on && sound) {
        _pump!.play(AssetSource('audio/pump.wav')).catchError((Object _) {});
      } else {
        _pump!.stop().catchError((Object _) {});
      }
    } catch (_) {}
  }

  static void ui() => _play('ui');
  static void coin() => _play('coin');
  static void full() {
    _play('full');
    _haptic(HapticFeedback.mediumImpact);
  }

  static void horn() => _play('horn');

  static void crash() {
    _play('crash');
    _haptic(HapticFeedback.lightImpact);
  }

  static void event() => _play('event');

  static void siren() {
    _play('siren');
    _haptic(HapticFeedback.lightImpact);
  }

  static void low() {
    _play('low');
    _haptic(HapticFeedback.selectionClick);
  }

  static void win() {
    _play('win');
    _haptic(HapticFeedback.mediumImpact);
  }

  static void lose() {
    _play('lose');
    _haptic(HapticFeedback.heavyImpact);
  }
}
