import 'ingredient.dart';

class Dish {
  String id;
  String name;
  List<Ingredient> ingredients;
  String? imagePath; // путь к локальному файлу картинки

  Dish({
    required this.id,
    required this.name,
    required this.ingredients,
    this.imagePath,
  });

  // Преобразование в JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'imagePath': imagePath,
      };

  // Создание из JSON
  factory Dish.fromJson(Map<String, dynamic> json) {
    return Dish(
      id: json['id'] as String,
      name: json['name'] as String,
      ingredients: (json['ingredients'] as List)
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      imagePath: json['imagePath'] as String?,
    );
  }

  // Формирование текста для отправки через мессенджеры
  String toShareText() {
    final buffer = StringBuffer();
    buffer.writeln('🍽 Блюдо: $name');
    buffer.writeln('');
    buffer.writeln('📝 Необходимые продукты:');
    for (final ing in ingredients) {
      final priceStr = ing.price != null
          ? ' — ${ing.price!.toStringAsFixed(2)} ₽'
          : '';
      buffer.writeln('• ${ing.name} — ${ing.amountDisplay}$priceStr');
    }
    // Подсчёт общей стоимости, если у всех ингредиентов есть цена
    final total = totalPrice;
    if (total != null) {
      buffer.writeln('');
      buffer.writeln('💰 Итого: ${total.toStringAsFixed(2)} ₽');
    }
    return buffer.toString();
  }

  // Суммарная стоимость блюда. null, если ни у одного ингредиента нет цены
  // (тогда показывать «—» не имеет смысла).
  double? get totalPrice {
    double total = 0;
    bool hasAny = false;
    for (final ing in ingredients) {
      if (ing.price != null) {
        total += ing.price!;
        hasAny = true;
      }
    }
    return hasAny ? total : null;
  }
}
