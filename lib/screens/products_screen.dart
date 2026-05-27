import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/ingredient.dart';
import '../services/storage_service.dart';
import '../utils/json_export.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final StorageService _storage = StorageService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<Product> _products = [];
  String _query = '';
  bool _loading = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Продукты, отфильтрованные по строке поиска (по названию, без учёта регистра).
  List<Product> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _storage.loadProducts();
    if (!mounted) return;
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _products = list;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _storage.saveProducts(_products);
  }

  Future<void> _addProduct() async {
    final result = await showProductEditDialog(context);
    if (result == null) return;
    _products.add(result);
    _products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _save();
    setState(() {});
  }

  Future<void> _editProduct(Product product) async {
    final result = await showProductEditDialog(context, product: product);
    if (result == null) return;
    final idx = _products.indexWhere((p) => p.id == result.id);
    if (idx != -1) {
      _products[idx] = result;
      _products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      await _save();
      setState(() {});
    }
  }

  Future<void> _exportProducts() async {
    if (_products.isEmpty) {
      _showSnack('Каталог пуст — нечего экспортировать');
      return;
    }
    try {
      final json = _storage.exportProductsJson(_products);
      final ts = DateTime.now().millisecondsSinceEpoch;
      await shareOrDownloadJson(
        jsonContent: json,
        filename: 'products_export_$ts.json',
        subject: 'Экспорт продуктов',
        text: 'Каталог продуктов',
      );
    } catch (e) {
      _showSnack('Ошибка экспорта: $e');
    }
  }

  Future<void> _importProducts() async {
    try {
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
          title: const Text('Импорт продуктов'),
          content: const Text(
              'Заменить текущий каталог импортированным или добавить к существующим?'),
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
      final newList = await _storage.importProductsFromJson(
        content,
        current: _products,
        replace: mode == 'replace',
      );
      newList.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _products = newList;
      await _save();
      if (!mounted) return;
      setState(() {});
      _showSnack('В каталоге продуктов: ${newList.length}');
    } catch (e) {
      _showSnack('Ошибка импорта: $e');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _deleteProduct(Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить продукт?'),
        content: Text('Продукт «${product.name}» будет удалён из каталога.'),
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
    _products.removeWhere((p) => p.id == product.id);
    await _save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список продуктов'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') _exportProducts();
              if (value == 'import') _importProducts();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Экспорт продуктов в файл'),
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Импорт файла с продуктами'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    _buildSearchField(),
                    Expanded(child: _buildList()),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        icon: const Icon(Icons.add),
        label: const Text('Добавить продукт'),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Поиск продукта...',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: const OutlineInputBorder(),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Очистить',
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Ничего не найдено',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final p = items[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Icon(Icons.shopping_basket, color: Colors.orange.shade700),
            ),
            title: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              p.defaultPrice != null
                  ? 'По умолчанию: ${_fmt(p.defaultAmount)} ${p.defaultUnit} • ${_fmt(p.defaultPrice!)} ₽/${p.defaultUnit}'
                  : 'По умолчанию: ${_fmt(p.defaultAmount)} ${p.defaultUnit}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteProduct(p),
            ),
            onTap: () => _editProduct(p),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket,
                size: 96, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Каталог продуктов пуст',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавляйте часто используемые продукты, чтобы быстро подставлять их в блюда',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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

// Диалог для добавления/редактирования продукта.
// Возвращает Product при сохранении или null при отмене.
Future<Product?> showProductEditDialog(
  BuildContext context, {
  Product? product,
}) {
  return showDialog<Product>(
    context: context,
    builder: (ctx) => _ProductEditDialog(product: product),
  );
}

class _ProductEditDialog extends StatefulWidget {
  final Product? product;
  const _ProductEditDialog({this.product});

  @override
  State<_ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<_ProductEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _priceCtrl;
  late String _unit;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _amountCtrl = TextEditingController(
      text: p == null ? '100' : _ProductsScreenState._fmt(p.defaultAmount),
    );
    _priceCtrl = TextEditingController(
      text: p?.defaultPrice != null
          ? _ProductsScreenState._fmt(p!.defaultPrice!)
          : '',
    );
    _unit = p?.defaultUnit ?? 'г';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    final amountText = _amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText) ?? 100;
    final priceText = _priceCtrl.text.trim().replaceAll(',', '.');
    final price = priceText.isEmpty ? null : double.tryParse(priceText);
    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: name,
      defaultAmount: amount,
      defaultUnit: _unit,
      defaultPrice: price,
    );
    Navigator.pop(context, product);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return AlertDialog(
      title: Text(isEdit ? 'Изменить продукт' : 'Новый продукт'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название *',
                isDense: true,
              ),
              autofocus: !isEdit,
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
                      labelText: 'По умолчанию',
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
                      final num = double.tryParse(t);
                      if (num == null || num <= 0) return '> 0';
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              decoration: InputDecoration(
                labelText: 'Цена за 1 $_unit (необязательно)',
                helperText: 'В блюде умножается на нужное количество',
                isDense: true,
                suffixText: '₽',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
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
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
