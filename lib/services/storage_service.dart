import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/dish.dart';
import '../models/product.dart';

class StorageService {
  static const String _fileName = 'dishes.json';
  static const String _productsFileName = 'products.json';

  // Путь к файлу с блюдами в локальной папке приложения
  Future<File> get _localFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  // Путь к файлу с каталогом продуктов
  Future<File> get _productsFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _productsFileName));
  }

  // Папка для сохранения изображений блюд
  Future<Directory> get imagesDir async {
    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory(p.join(dir.path, 'dish_images'));
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }
    return imgDir;
  }

  // Загрузка всех блюд
  Future<List<Dish>> loadDishes() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
      }
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

  // Сохранение всех блюд
  Future<void> saveDishes(List<Dish> dishes) async {
    final file = await _localFile;
    final data = dishes.map((d) => d.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  // Загрузка каталога продуктов
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

  // Сохранение каталога продуктов
  Future<void> saveProducts(List<Product> products) async {
    final file = await _productsFile;
    final data = products.map((p) => p.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  // Сохранение картинки в локальное хранилище приложения
  // возвращает путь к скопированному файлу
  Future<String> saveImage(File source) async {
    final dir = await imagesDir;
    final ext = p.extension(source.path);
    final newName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final newPath = p.join(dir.path, newName);
    final copied = await source.copy(newPath);
    return copied.path;
  }

  // Удаление картинки (если файл существует и лежит в нашей папке)
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

  // Экспорт всех блюд в JSON-строку (для шаринга / сохранения файлом)
  Future<String> exportToJsonString(List<Dish> dishes) async {
    // При экспорте картинки не включаем (только пути) — пути будут невалидны на другом устройстве
    // поэтому сбрасываем imagePath
    final data = dishes.map((d) {
      final json = d.toJson();
      json['imagePath'] = null;
      return json;
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // Сохранение JSON-файла во временную папку (для шаринга)
  Future<File> writeExportFile(List<Dish> dishes) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'dishes_export_$ts.json'));
    final jsonStr = await exportToJsonString(dishes);
    await file.writeAsString(jsonStr);
    return file;
  }

  // Импорт из JSON-строки.
  // mode: 'replace' — заменить всё, 'merge' — добавить к существующим
  Future<List<Dish>> importFromJsonString(
    String jsonString, {
    required List<Dish> current,
    required bool replace,
  }) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException('Ожидался JSON-массив блюд');
    }
    final imported = decoded
        .map((e) => Dish.fromJson(e as Map<String, dynamic>))
        .toList();
    if (replace) {
      // Удаляем старые картинки
      for (final d in current) {
        await deleteImage(d.imagePath);
      }
      // У импортированных всё равно нет картинок
      return imported;
    }
    // merge: дописываем, при коллизии id перегенерируем
    final existingIds = current.map((d) => d.id).toSet();
    for (final d in imported) {
      if (existingIds.contains(d.id)) {
        d.id = '${d.id}_${DateTime.now().microsecondsSinceEpoch}';
      }
    }
    return [...current, ...imported];
  }
}
