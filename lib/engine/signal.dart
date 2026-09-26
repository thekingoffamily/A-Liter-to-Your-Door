import 'package:flutter/foundation.dart';

/// Минимальный [ChangeNotifier] с публичным методом [emit].
///
/// Нужен, чтобы движок мог сообщать об изменениях снаружи класса и чтобы
/// отрисовка (CustomPainter.repaint) не зависела от перестроения виджетов.
class Signal extends ChangeNotifier {
  /// Уведомить слушателей.
  void emit() {
    notifyListeners();
  }
}
