import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/dish.dart';
import '../models/ingredient.dart';
import '../models/product.dart';
import '../services/storage_service.dart';
import '../widgets/product_picker_sheet.dart';

class _CartEntry {
  final String name;
  double amount; // в базовой единице семейства (г для mass, мл для volume, иначе как есть)
  final String baseUnit;
  bool checked = true;

  _CartEntry({
    required this.name,
    required this.amount,
    required this.baseUnit,
  });

  // Отображаем количество с автоконвертацией г→кг и мл→л
  String get amountDisplay {
    if (baseUnit == 'г' && amount >= 1000) {
      return '${_fmt(amount / 1000)} кг';
    }
    if (baseUnit == 'мл' && amount >= 1000) {
      return '${_fmt(amount / 1000)} л';
    }
    return '${_fmt(amount)} $baseUnit';
  }

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}

class CartScreen extends StatefulWidget {
  final List<Dish> dishes;

  const CartScreen({super.key, required this.dishes});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<_CartEntry> _entries;
  final StorageService _storage = StorageService();
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _entries = _mergeIngredients(widget.dishes);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final list = await _storage.loadProducts();
    if (!mounted) return;
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _products = list;
    });
  }

  Future<void> _addItemDialog() async {
    final result = await showDialog<_NewCartItem>(
      context: context,
      builder: (_) => _AddCartItemDialog(products: _products),
    );
    if (result == null) return;
    _addOrMerge(result);
  }

  void _addOrMerge(_NewCartItem item) {
    final cleanName = item.name.trim();
    if (cleanName.isEmpty) return;
    final family = Ingredient.unitFamily(item.unit);
    final baseValue = Ingredient.toBase(item.amount, item.unit);
    setState(() {
      final idx = _entries.indexWhere((e) =>
          e.name.toLowerCase() == cleanName.toLowerCase() &&
          Ingredient.unitFamily(e.baseUnit) == family);
      if (idx != -1) {
        _entries[idx].amount += baseValue;
        _entries[idx].checked = true;
      } else {
        _entries.add(_CartEntry(
          name: cleanName,
          amount: baseValue,
          baseUnit: Ingredient.baseUnitOf(family),
        ));
        _entries.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
    });
  }

  // Объединяем одноимённые ингредиенты, суммируя количество в пределах семейства единиц.
  // Разные семейства (например г и шт) остаются отдельными строками.
  List<_CartEntry> _mergeIngredients(List<Dish> dishes) {
    final Map<String, _CartEntry> map = {};
    for (final dish in dishes) {
      for (final ing in dish.ingredients) {
        final cleanName = ing.name.trim();
        if (cleanName.isEmpty) continue;
        final family = Ingredient.unitFamily(ing.unit);
        final key = '${cleanName.toLowerCase()}|$family';
        final baseValue = Ingredient.toBase(ing.weight, ing.unit);
        final existing = map[key];
        if (existing != null) {
          existing.amount += baseValue;
        } else {
          map[key] = _CartEntry(
            name: cleanName,
            amount: baseValue,
            baseUnit: Ingredient.baseUnitOf(family),
          );
        }
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  String _buildShareText() {
    final buffer = StringBuffer();
    final needed = _entries.where((e) => e.checked).toList();
    buffer.writeln('🛒 Список покупок');
    if (widget.dishes.length == 1) {
      buffer.writeln('Для блюда: ${widget.dishes.first.name}');
    } else {
      buffer.writeln('Для блюд (${widget.dishes.length}):');
      for (final d in widget.dishes) {
        buffer.writeln('  • ${d.name}');
      }
    }
    buffer.writeln('');
    buffer.writeln('📝 Нужно купить:');
    for (final entry in needed) {
      buffer.writeln('• ${entry.name} — ${entry.amountDisplay}');
    }
    return buffer.toString();
  }

  Future<void> _share() async {
    final hasChecked = _entries.any((e) => e.checked);
    if (!hasChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Список пуст — нечего отправлять')),
      );
      return;
    }
    final text = _buildShareText();
    // Картинку отправляем только если выбрано ровно одно блюдо
    if (widget.dishes.length == 1) {
      final dish = widget.dishes.first;
      if (dish.imagePath != null && File(dish.imagePath!).existsSync()) {
        await Share.shareXFiles(
          [XFile(dish.imagePath!)],
          text: text,
          subject: 'Список покупок',
        );
        return;
      }
    }
    await Share.share(text, subject: 'Список покупок');
  }

  void _toggleAll(bool value) {
    setState(() {
      for (final e in _entries) {
        e.checked = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkedCount = _entries.where((e) => e.checked).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина покупок'),
        actions: [
          if (_entries.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'select_all') _toggleAll(true);
                if (value == 'deselect_all') _toggleAll(false);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'select_all',
                  child: ListTile(
                    leading: Icon(Icons.check_box),
                    title: Text('Выбрать все'),
                  ),
                ),
                PopupMenuItem(
                  value: 'deselect_all',
                  child: ListTile(
                    leading: Icon(Icons.check_box_outline_blank),
                    title: Text('Снять все'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'В выбранных блюдах нет ингредиентов',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
                    itemCount: _entries.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _entries.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 4),
                          child: OutlinedButton.icon(
                            onPressed: _addItemDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить продукт в корзину'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        );
                      }
                      final entry = _entries[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: CheckboxListTile(
                          value: entry.checked,
                          onChanged: (v) {
                            setState(() {
                              entry.checked = v ?? false;
                            });
                          },
                          title: Text(
                            entry.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              decoration: entry.checked
                                  ? null
                                  : TextDecoration.lineThrough,
                              color: entry.checked
                                  ? null
                                  : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            entry.amountDisplay,
                            style: TextStyle(
                              color: entry.checked
                                  ? null
                                  : Colors.grey.shade400,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _entries.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'К покупке: $checkedCount из ${_entries.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: checkedCount > 0 ? _share : null,
                      icon: const Icon(Icons.share),
                      label: const Text('Отправить'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final dishesCount = widget.dishes.length;
    final label = dishesCount == 1
        ? 'Для блюда: ${widget.dishes.first.name}'
        : 'Выбрано блюд: $dishesCount';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.shopping_cart, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Возвращаемое значение из диалога добавления продукта
class _NewCartItem {
  final String name;
  final double amount;
  final String unit;
  _NewCartItem({required this.name, required this.amount, required this.unit});
}

class _AddCartItemDialog extends StatefulWidget {
  final List<Product> products;
  const _AddCartItemDialog({required this.products});

  @override
  State<_AddCartItemDialog> createState() => _AddCartItemDialogState();
}

class _AddCartItemDialogState extends State<_AddCartItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '1');
  String _unit = 'шт';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromCatalog() async {
    if (widget.products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Каталог пуст. Добавьте продукты через меню.'),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductPickerSheet(products: widget.products),
    );
    if (picked == null) return;
    setState(() {
      _nameCtrl.text = picked.name;
      _amountCtrl.text = _fmt(picked.defaultAmount);
      _unit = picked.defaultUnit;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount =
        double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    Navigator.pop(
      context,
      _NewCartItem(
        name: _nameCtrl.text.trim(),
        amount: amount,
        unit: _unit,
      ),
    );
  }

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить в корзину'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Название *',
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.list_alt),
                  tooltip: 'Выбрать из каталога',
                  onPressed: _pickFromCatalog,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите название' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Количество',
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    validator: (v) {
                      final t = (v ?? '').trim().replaceAll(',', '.');
                      if (t.isEmpty) return 'Введите';
                      final n = double.tryParse(t);
                      if (n == null || n <= 0) return '> 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(
                      labelText: 'Ед.',
                      isDense: true,
                    ),
                    items: Ingredient.allUnits
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _unit = v);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
