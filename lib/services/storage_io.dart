import 'dart:convert';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/dish.dart';
import '../models/product.dart';

// Реализация хранилища для мобильных платформ (Android/iOS) и десктопа.
// Данные пишутся в JSON-файлы в getApplicationDocumentsDirectory(),
// картинки блюд — в подпапку dish_images/.
class StorageService {
  static const String _fileName = 'dishes.json';
  static const String _productsFileName = 'products.json';

  Future<File> get _localFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<File> get _productsFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _productsFileName));
  }

  Future<Directory> get _imagesDir async {
    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory(p.join(dir.path, 'dish_images'));
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }
    return imgDir;
  }

  Future<List<Dish>> loadDishes() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
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
    final file = await _localFile;
    final data = dishes.map((d) => d.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  Future<List<Product>> loadProducts() async {
    try {
      final file = await _productsFile;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
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
    final file = await _productsFile;
    final data = products.map((p) => p.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  // Сохранение картинки в локальное хранилище приложения.
  // Принимает XFile (cross-platform), но реально использует path — на web этот метод
  // не вызывается, так как image_picker отключён в UI.
  Future<String> saveImage(XFile source) async {
    final dir = await _imagesDir;
    final ext = p.extension(source.path);
    final newName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final newPath = p.join(dir.path, newName);
    final copied = await File(source.path).copy(newPath);
    return copied.path;
  }

  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null) return;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // молча игнорируем ошибки удаления картинки
    }
  }

  // Экспорт в JSON-строку. Картинки в выгрузку не попадают (пути локального
  // устройства бессмысленны на другом).
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

  // Импорт из JSON-строки.
  // replace=true — заменить всё; false — мерджить.
  Future<List<Dish>> importDishesFromJson(
    String jsonString, {
    required List<Dish> current,
    required bool replace,
  }) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException('Ожидался JSON-массив блюд');
    }
    // Сначала валидируем формат: если первый элемент похож на продукт (есть
    // defaultUnit/defaultAmount, нет ingredients) — пользователь явно
    // перепутал кнопку импорта.
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
    if (replace) {
      for (final d in current) {
        await deleteImage(d.imagePath);
      }
      return imported;
    }
    final existingIds = current.map((d) => d.id).toSet();
    for (final d in imported) {
      if (existingIds.contains(d.id)) {
        d.id = '${d.id}_${DateTime.now().microsecondsSinceEpoch}';
      }
    }
    return [...current, ...imported];
  }

  // Импорт продуктов: replace=true — полностью заменяем; false — мерджим по имени
  // (case-insensitive, существующие записи не трогаем, чтобы не сбить defaultAmount/Unit).
  Future<List<Product>> importProductsFromJson(
    String jsonString, {
    required List<Product> current,
    required bool replace,
  }) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException('Ожидался JSON-массив продуктов');
    }
    // Симметрично: если первый элемент явно похож на блюдо — это не сюда.
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
    if (replace) {
      return imported;
    }
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
