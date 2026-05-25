import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/dish.dart';
import '../services/storage_service.dart';
import '../utils/local_image.dart';
import '../utils/json_export.dart';
import 'dish_edit_screen.dart';
import 'dish_detail_screen.dart';
import 'cart_screen.dart';
import 'products_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  List<Dish> _dishes = [];
  bool _loading = true;

  // Режим выбора блюд для формирования корзины
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode([String? initialId]) {
    setState(() {
      _selectionMode = true;
      if (initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(Dish dish) {
    setState(() {
      if (_selectedIds.contains(dish.id)) {
        _selectedIds.remove(dish.id);
      } else {
        _selectedIds.add(dish.id);
      }
    });
  }

  Future<void> _openCart() async {
    final selected =
        _dishes.where((d) => _selectedIds.contains(d.id)).toList();
    if (selected.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CartScreen(dishes: selected)),
    );
    if (!mounted) return;
    _exitSelectionMode();
  }

  Future<void> _openProductsList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductsScreen()),
    );
  }

  Future<void> _addProductQuick() async {
    final result = await showProductEditDialog(context);
    if (result == null) return;
    final products = await _storage.loadProducts();
    products.add(result);
    await _storage.saveProducts(products);
    if (!mounted) return;
    _showSnack('Продукт «${result.name}» добавлен в каталог');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _storage.loadDishes();
    if (!mounted) return;
    setState(() {
      _dishes = list;
      _loading = false;
    });
  }

  Future<void> _saveAndRefresh() async {
    await _storage.saveDishes(_dishes);
    setState(() {});
  }

  Future<void> _addDish() async {
    final result = await Navigator.push<Dish>(
      context,
      MaterialPageRoute(builder: (_) => const DishEditScreen()),
    );
    if (result != null) {
      _dishes.add(result);
      await _saveAndRefresh();
    }
  }

  Future<void> _editDish(Dish dish) async {
    final result = await Navigator.push<Dish>(
      context,
      MaterialPageRoute(builder: (_) => DishEditScreen(dish: dish)),
    );
    if (result != null) {
      final idx = _dishes.indexWhere((d) => d.id == result.id);
      if (idx != -1) {
        _dishes[idx] = result;
      }
      await _saveAndRefresh();
    }
  }

  Future<void> _openDish(Dish dish) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DishDetailScreen(
          dish: dish,
          onEdit: () async {
            Navigator.pop(context);
            await _editDish(dish);
          },
          onDelete: () async {
            Navigator.pop(context);
            await _deleteDish(dish);
          },
        ),
      ),
    );
    // на всякий случай перерисуем список (если внутри что-то поменялось)
    await _load();
  }

  Future<void> _deleteDish(Dish dish) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить блюдо?'),
        content: Text('Блюдо «${dish.name}» будет удалено.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _storage.deleteImage(dish.imagePath);
    _dishes.removeWhere((d) => d.id == dish.id);
    await _saveAndRefresh();
  }

  Future<void> _shareDish(Dish dish) async {
    // Открываем корзину для одного блюда, чтобы перед отправкой можно было
    // снять лишние ингредиенты или добавить свои продукты.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CartScreen(dishes: [dish])),
    );
  }

  Future<void> _exportAll() async {
    if (_dishes.isEmpty) {
      _showSnack('Нет блюд для экспорта');
      return;
    }
    try {
      final json = _storage.exportDishesJson(_dishes);
      final ts = DateTime.now().millisecondsSinceEpoch;
      await shareOrDownloadJson(
        jsonContent: json,
        filename: 'dishes_export_$ts.json',
        subject: 'Экспорт блюд',
        text: 'Файл с моими блюдами',
      );
    } catch (e) {
      _showSnack('Ошибка экспорта: $e');
    }
  }

  Future<void> _importAll() async {
    try {
      // withData: true — чтобы байты загрузились в память на любой платформе
      // (на web `path` всегда null, читать нужно через bytes).
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) return;

      if (!mounted) return;
      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Импорт блюд'),
          content: const Text(
              'Заменить текущие блюда импортированными или добавить к существующим?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'merge'),
              child: const Text('Добавить'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Заменить'),
            ),
          ],
        ),
      );
      if (mode == null) return;

      final content = utf8.decode(bytes);
      final newList = await _storage.importDishesFromJson(
        content,
        current: _dishes,
        replace: mode == 'replace',
      );
      _dishes = newList;
      await _saveAndRefresh();
      _showSnack('Импортировано блюд: ${newList.length}');
    } catch (e) {
      _showSnack('Ошибка импорта: $e');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Отменить выбор',
                onPressed: _exitSelectionMode,
              )
            : null,
        title: Text(
          _selectionMode
              ? 'Выбрано: ${_selectedIds.length}'
              : 'Мои блюда',
        ),
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  tooltip: 'Сформировать корзину',
                  onPressed: _selectedIds.isEmpty ? null : _openCart,
                ),
              ]
            : [
                if (_dishes.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    tooltip: 'Сформировать корзину',
                    onPressed: () => _enterSelectionMode(),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'add_product') _addProductQuick();
                    if (value == 'products_list') _openProductsList();
                    if (value == 'export') _exportAll();
                    if (value == 'import') _importAll();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'add_product',
                      child: ListTile(
                        leading: Icon(Icons.add_shopping_cart),
                        title: Text('Добавить продукт'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'products_list',
                      child: ListTile(
                        leading: Icon(Icons.shopping_basket),
                        title: Text('Список продуктов'),
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'export',
                      child: ListTile(
                        leading: Icon(Icons.upload_file),
                        title: Text('Экспорт блюд в файл'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'import',
                      child: ListTile(
                        leading: Icon(Icons.download),
                        title: Text('Импорт файла с блюдами'),
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dishes.isEmpty
              ? _buildEmpty()
              : _buildList(),
      floatingActionButton: _selectionMode
          ? (_selectedIds.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: _openCart,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: Text('Сформировать (${_selectedIds.length})'),
                ))
          : FloatingActionButton.extended(
              onPressed: _addDish,
              icon: const Icon(Icons.add),
              label: const Text('Добавить блюдо'),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu,
                size: 96, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Пока нет блюд',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Нажмите «Добавить блюдо», чтобы создать первое',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: _dishes.length,
      itemBuilder: (context, index) {
        final dish = _dishes[index];
        final selected = _selectedIds.contains(dish.id);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          clipBehavior: Clip.antiAlias,
          color: _selectionMode && selected
              ? Colors.orange.shade50
              : null,
          child: InkWell(
            onTap: () {
              if (_selectionMode) {
                _toggleSelect(dish);
              } else {
                _openDish(dish);
              }
            },
            onLongPress: _selectionMode
                ? null
                : () => _enterSelectionMode(dish.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => _toggleSelect(dish),
                      ),
                    ),
                  _buildThumb(dish),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dish.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ингредиентов: ${dish.ingredients.length}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (!_selectionMode)
                    IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: 'Отправить',
                      onPressed: () => _shareDish(dish),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumb(Dish dish) {
    if (hasLocalImage(dish.imagePath)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: buildLocalImage(
          dish.imagePath!,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.restaurant, color: Colors.orange.shade700, size: 32),
    );
  }
}
