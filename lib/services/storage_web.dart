import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dish.dart';
import '../models/product.dart';

// Реализация хранилища для веб-версии. Файловой системы нет — JSON блюд и
// продуктов хранится в shared_preferences (это IndexedDB/localStorage в браузере).
// Картинки не поддерживаются: image_picker в UI скрыт, saveImage кидает UnsupportedError.
class StorageService {
  static const String _dishesKey = 'dishes_json';
  static const String _productsKey = 'products_json';

  Future<List<Dish>> loadDishes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString(_dishesKey);
      if (content == null || content.trim().isEmpty) return [];
      final data = jsonDecode(content) as List<dynamic>;
      return data
          .map((e) => Dish.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Ошибка загрузки блюд: $e');
      return [];
    }
  }

  Future<void> saveDishes(List<Dish> dishes) async {
    final prefs = await SharedPreferences.getInstance();
    final data = dishes.map((d) {
      // в веб-версии картинок нет — нормализуем поле, чтобы не тащить мусор
      final json = d.toJson();
      json['imagePath'] = null;
      return json;
    }).toList();
    await prefs.setString(_dishesKey, jsonEncode(data));
  }

  Future<List<Product>> loadProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString(_productsKey);
      if (content == null || content.trim().isEmpty) return [];
      final data = jsonDecode(content) as List<dynamic>;
      return data
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Ошибка загрузки продуктов: $e');
      return [];
    }
  }

  Future<void> saveProducts(List<Product> products) async {
    final prefs = await SharedPreferences.getInstance();
    final data = products.map((p) => p.toJson()).toList();
    await prefs.setString(_productsKey, jsonEncode(data));
  }

  // Однократно (на первый запуск) подгружает встроенный каталог продуктов.
  // Если у пользователя уже есть продукты — ничего не меняем, только выставляем
  // флаг, чтобы больше не пытаться. Версионируем флаг (v1) на случай, если
  // в будущем понадобится принудительно перезалить дефолты.
  Future<void> initializeDefaultProductsIfNeeded(
      String defaultProductsJson) async {
    final prefs = await SharedPreferences.getInstance();
    const flagKey = 'default_products_loaded_v1';
    if (prefs.getBool(flagKey) == true) return;
    final current = await loadProducts();
    if (current.isEmpty) {
      final decoded = jsonDecode(defaultProductsJson) as List<dynamic>;
      final products = decoded
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
      await saveProducts(products);
    }
    await prefs.setBool(flagKey, true);
  }

  // На вебе картинки не поддерживаются. UI image_picker скрыт, но метод
  // должен быть в API, чтобы код компилировался.
  Future<String> saveImage(XFile source) async {
    throw UnsupportedError('Картинки блюд недоступны в веб-версии');
  }

  Future<void> deleteImage(String? imagePath) async {
    // на вебе картинок нет — no-op
  }

  String exportDishesJson(List<Dish> dishes) {
    final data = dishes.map((d) {
      final json = d.toJson();
      json['imagePath'] = null;
      return json;
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  String exportProductsJson(List<Product> products) {
    final data = products.map((p) => p.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<List<Dish>> importDishesFromJson(
    String jsonString, {
    required List<Dish> current,
    required bool replace,
  }) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException('Ожидался JSON-массив блюд');
    }
    if (decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map<String, dynamic>) {
        final looksLikeProduct = first.containsKey('defaultUnit') ||
            first.containsKey('defaultAmount');
        final hasIngredients = first.containsKey('ingredients');
        if (looksLikeProduct && !hasIngredients) {
          throw const FormatException(
              'Похоже, это файл каталога продуктов, а не блюд. '
              'Импортируйте его через «Список продуктов» → меню → Импорт.');
        }
      }
    }
    final imported = decoded
        .map((e) => Dish.fromJson(e as Map<String, dynamic>))
        .toList();
    if (replace) return imported;
    final existingIds = current.map((d) => d.id).toSet();
    for (final d in imported) {
      if (existingIds.contains(d.id)) {
        d.id = '${d.id}_${DateTime.now().microsecondsSinceEpoch}';
      }
    }
    return [...current, ...imported];
  }

  Future<List<Product>> importProductsFromJson(
    String jsonString, {
    required List<Product> current,
    required bool replace,
  }) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException('Ожидался JSON-массив продуктов');
    }
    if (decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map<String, dynamic> && first.containsKey('ingredients')) {
        throw const FormatException(
            'Похоже, это файл блюд, а не каталога продуктов. '
            'Импортируйте его на главном экране → меню → Импорт.');
      }
    }
    final imported = decoded
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
    if (replace) return imported;
    final existingNames =
        current.map((p) => p.name.trim().toLowerCase()).toSet();
    final existingIds = current.map((p) => p.id).toSet();
    final toAdd = <Product>[];
    for (final p in imported) {
      final key = p.name.trim().toLowerCase();
      if (existingNames.contains(key)) continue;
      if (existingIds.contains(p.id)) {
        p.id = '${p.id}_${DateTime.now().microsecondsSinceEpoch}';
      }
      toAdd.add(p);
    }
    return [...current, ...toAdd];
  }
}
