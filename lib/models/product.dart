import 'ingredient.dart';

class Product {
  String id;
  String name;
  double defaultAmount; // вес/количество по умолчанию
  String defaultUnit;   // единица по умолчанию
  // Цена за ОДНУ единицу defaultUnit (за кг, за шт, за уп и т.д.), не за
  // defaultAmount. Может отсутствовать. Стоимость ингредиента в блюде
  // считается умножением на нужное количество — см. costFor().
  double? defaultPrice;

  Product({
    required this.id,
    required this.name,
    this.defaultAmount = 100,
    this.defaultUnit = 'г',
    this.defaultPrice,
  });

  // Стоимость заданного количества этого продукта.
  // Возвращает null, если цена не задана или единицы несовместимы по семейству
  // (например, цена за шт, а в блюде граммы — пересчитать нельзя).
  double? costFor(double amount, String unit) {
    if (defaultPrice == null) return null;
    if (Ingredient.unitFamily(unit) != Ingredient.unitFamily(defaultUnit)) {
      return null;
    }
    // Цена за базовую единицу семейства (за грамм / за мл / за шт),
    // затем умножаем на количество, тоже приведённое к базовой единице.
    final pricePerBase = defaultPrice! / Ingredient.toBase(1, defaultUnit);
    return pricePerBase * Ingredient.toBase(amount, unit);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'defaultAmount': defaultAmount,
        'defaultUnit': defaultUnit,
        'defaultPrice': defaultPrice,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      defaultAmount: (json['defaultAmount'] as num?)?.toDouble() ?? 100,
      defaultUnit: (json['defaultUnit'] as String?) ?? 'г',
      defaultPrice: json['defaultPrice'] != null
          ? (json['defaultPrice'] as num).toDouble()
          : null,
    );
  }
}
