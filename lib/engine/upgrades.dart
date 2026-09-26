/// Улучшение автомобиля, покупаемое в гараже.
class Upgrade {
  const Upgrade({
    required this.id,
    required this.title,
    required this.desc,
    required this.maxLevel,
    required this.cost,
  });

  final String id;
  final String title;
  final String desc;
  final int maxLevel;
  final int cost;

  /// Стоимость следующего уровня.
  int priceFor(int level) => cost * (level + 1);
}

/// Полный список улучшений (бесплатная версия — всё доступно без покупок).
const List<Upgrade> kUpgrades = <Upgrade>[
  Upgrade(id: 'tank', title: 'Увеличенный бак', desc: '+10 л к объёму бака', maxLevel: 4, cost: 350),
  Upgrade(id: 'engine', title: 'Экономичный двигатель', desc: '−8% к расходу топлива', maxLevel: 4, cost: 400),
  Upgrade(id: 'fastpump', title: 'Быстрая заправка', desc: '+30% к скорости колонки', maxLevel: 3, cost: 280),
  Upgrade(id: 'canister', title: 'Канистра в багажнике', desc: '+6 л аварийного запаса', maxLevel: 3, cost: 300),
  Upgrade(id: 'discount', title: 'Скидочная карта', desc: '−6% к цене бензина', maxLevel: 4, cost: 320),
  Upgrade(id: 'bumper', title: 'Усиленный бампер', desc: 'Мягче столкновения, меньше потерь', maxLevel: 2, cost: 260),
  Upgrade(id: 'radio', title: 'Рация', desc: 'Слухи о АЗС приходят чаще', maxLevel: 2, cost: 240),
  Upgrade(id: 'navigator', title: 'Навигатор', desc: 'Слухи о АЗС точнее', maxLevel: 2, cost: 360),
];
