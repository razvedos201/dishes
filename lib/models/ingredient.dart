class Ingredient {
  String name;
  double weight; // количество в выбранной единице (см. unit)
  String unit;   // единица измерения: г, кг, мл, л, шт, уп
  double? price; // стоимость не обязательна

  Ingredient({
    required this.name,
    required this.weight,
    this.unit = 'г',
    this.price,
  });

  // Преобразование в JSON
  Map<String, dynamic> toJson() => {
        'name': name,
        'weight': weight,
        'unit': unit,
        'price': price,
      };

  // Создание из JSON. Старые данные без поля unit считаем граммами.
  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String,
      weight: (json['weight'] as num).toDouble(),
      unit: (json['unit'] as String?) ?? 'г',
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
    );
  }

  // Удобное отображение количества + единицы.
  // Автоматически переводит г→кг и мл→л при больших значениях.
  String get amountDisplay {
    if (unit == 'г' && weight >= 1000) {
      return '${_fmt(weight / 1000)} кг';
    }
    if (unit == 'мл' && weight >= 1000) {
      return '${_fmt(weight / 1000)} л';
    }
    return '${_fmt(weight)} $unit';
  }

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) {
      return v.toInt().toString();
    }
    final s = v.toStringAsFixed(2);
    // отрезаем лишние нули в конце ("1.50" → "1.5", "1.00" → "1")
    return s
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  // Список всех поддерживаемых единиц
  static const List<String> allUnits = ['г', 'кг', 'мл', 'л', 'шт', 'уп'];

  // Семейство единиц для агрегации в корзине
  static String unitFamily(String unit) {
    switch (unit) {
      case 'г':
      case 'кг':
        return 'mass';
      case 'мл':
      case 'л':
        return 'volume';
      default:
        return unit; // шт, уп — каждый в своём семействе
    }
  }

  // Базовая величина для агрегации (граммы для mass, мл для volume, иначе как есть)
  static double toBase(double value, String unit) {
    switch (unit) {
      case 'кг':
        return value * 1000;
      case 'л':
        return value * 1000;
      default:
        return value;
    }
  }

  // Базовая единица для семейства
  static String baseUnitOf(String family) {
    switch (family) {
      case 'mass':
        return 'г';
      case 'volume':
        return 'мл';
      default:
        return family;
    }
  }
}
