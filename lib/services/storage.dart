import 'package:shared_preferences/shared_preferences.dart';

/// Данные гаража: купленные машины и уровни улучшений.
class GarageData {
  const GarageData(this.cars, this.upgrades, this.currentCar);

  final Set<String> cars;
  final Map<String, int> upgrades;
  final String currentCar;
}

/// Локальное хранилище: рекорд, гараж и настройки.
///
/// Данные не покидают устройство — приложению не нужен интернет и не нужно
/// разрешение на сеть. Любая ошибка хранилища не должна ломать игру.
class GameStore {
  GameStore._();

  static const String _keyBest = 'best_score';
  static const String _keySound = 'sound_on';
  static const String _keyVibro = 'vibro_on';
  static const String _keyCars = 'garage_cars';
  static const String _keyUpgrades = 'garage_upgrades';
  static const String _keyCurrent = 'garage_current';

  static Future<int> loadBest() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyBest) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> saveBest(int value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyBest, value);
    } catch (_) {}
  }

  static Future<bool> loadSound() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keySound) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> loadVibro() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyVibro) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveSound(bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySound, value);
    } catch (_) {}
  }

  static Future<void> saveVibro(bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyVibro, value);
    } catch (_) {}
  }

  static Future<GarageData> loadGarage() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> cars = prefs.getStringList(_keyCars) ?? <String>['sedan'];
      final List<String> raw = prefs.getStringList(_keyUpgrades) ?? <String>[];
      final Map<String, int> levels = <String, int>{};
      for (final String item in raw) {
        final int sep = item.indexOf(':');
        if (sep <= 0) {
          continue;
        }
        final int? value = int.tryParse(item.substring(sep + 1));
        if (value != null) {
          levels[item.substring(0, sep)] = value;
        }
      }
      final String current = prefs.getString(_keyCurrent) ?? 'sedan';
      return GarageData(cars.toSet(), levels, current);
    } catch (_) {
      return const GarageData(<String>{'sedan'}, <String, int>{}, 'sedan');
    }
  }

  static Future<void> saveGarage(Set<String> cars, Map<String, int> levels, String current) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyCars, cars.toList());
      await prefs.setStringList(
        _keyUpgrades,
        <String>[for (final MapEntry<String, int> e in levels.entries) '${e.key}:${e.value}'],
      );
      await prefs.setString(_keyCurrent, current);
    } catch (_) {}
  }
}
