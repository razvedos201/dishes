import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/dish.dart';
import '../models/ingredient.dart';
import '../models/product.dart';
import '../services/storage_service.dart';
import '../utils/local_image.dart';
import '../widgets/product_picker_sheet.dart';

class DishEditScreen extends StatefulWidget {
  final Dish? dish; // null = создание, иначе редактирование
  const DishEditScreen({super.key, this.dish});

  @override
  State<DishEditScreen> createState() => _DishEditScreenState();
}

class _DishEditScreenState extends State<DishEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<_IngredientForm> _ingredients = [];
  String? _imagePath;
  bool _imageChanged = false;
  String? _oldImagePathForCleanup;
  final StorageService _storage = StorageService();
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    final d = widget.dish;
    if (d != null) {
      _nameController.text = d.name;
      _imagePath = d.imagePath;
      for (final ing in d.ingredients) {
        _ingredients.add(_IngredientForm.fromIngredient(ing));
      }
    }
    if (_ingredients.isEmpty) {
      _ingredients.add(_IngredientForm());
    }
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

  Future<void> _pickFromCatalog(int index) async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Каталог пуст. Добавьте продукты через меню на главном экране.'),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductPickerSheet(products: _products),
    );
    if (picked == null) return;
    setState(() {
      final f = _ingredients[index];
      f.nameCtrl.text = picked.name;
      f.weightCtrl.text = _fmt(picked.defaultAmount);
      f.unit = picked.defaultUnit;
    });
  }

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final f in _ingredients) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final saved = await _storage.saveImage(picked);
      setState(() {
        // Если уже была картинка — запомним для удаления при сохранении
        if (_imagePath != null && _imagePath != saved) {
          _oldImagePathForCleanup = _imagePath;
        }
        _imagePath = saved;
        _imageChanged = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Не удалось добавить фото: $e')));
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить фото',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _oldImagePathForCleanup = _imagePath;
                    _imagePath = null;
                    _imageChanged = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngredientForm());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients[index].dispose();
      _ingredients.removeAt(index);
      if (_ingredients.isEmpty) {
        _ingredients.add(_IngredientForm());
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // отбрасываем пустые строки ингредиентов
    final ingredients = <Ingredient>[];
    for (final f in _ingredients) {
      final name = f.nameCtrl.text.trim();
      if (name.isEmpty) continue;
      final amount = f.parsedAmount;
      if (amount == null || amount <= 0) continue;
      double? price;
      final priceText = f.priceCtrl.text.trim().replaceAll(',', '.');
      if (priceText.isNotEmpty) {
        price = double.tryParse(priceText);
      }
      ingredients.add(Ingredient(
        name: name,
        weight: amount,
        unit: f.unit,
        price: price,
      ));
    }

    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы один ингредиент')),
      );
      return;
    }

    // Если меняли картинку — удалить старую
    if (_imageChanged && _oldImagePathForCleanup != null) {
      await _storage.deleteImage(_oldImagePathForCleanup);
    }

    final id = widget.dish?.id ?? const Uuid().v4();
    final dish = Dish(
      id: id,
      name: _nameController.text.trim(),
      ingredients: ingredients,
      imagePath: _imagePath,
    );

    if (!mounted) return;
    Navigator.pop(context, dish);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.dish != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Редактировать блюдо' : 'Новое блюдо'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Сохранить',
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // На вебе картинки не поддерживаются — скрываем блок целиком.
            if (!kIsWeb) ...[
              _buildImagePicker(),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название блюда *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.restaurant_menu),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Введите название'
                  : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.list_alt),
                SizedBox(width: 8),
                Text(
                  'Ингредиенты',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _ingredients.length; i++)
              _buildIngredientCard(i),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add),
              label: const Text('Добавить ингредиент'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Сохранить блюдо'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _showImagePicker,
        child: Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: hasLocalImage(_imagePath)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      buildLocalImage(_imagePath!, fit: BoxFit.cover),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('Изменить',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo,
                        size: 48, color: Colors.grey.shade500),
                    const SizedBox(height: 8),
                    Text(
                      'Добавить фото блюда',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildIngredientCard(int i) {
    final f = _ingredients[i];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ингредиент ${i + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeIngredient(i),
                  tooltip: 'Удалить',
                ),
              ],
            ),
            TextFormField(
              controller: f.nameCtrl,
              decoration: InputDecoration(
                labelText: 'Название',
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.list_alt),
                  tooltip: 'Выбрать из каталога',
                  onPressed: () => _pickFromCatalog(i),
                ),
              ),
              validator: (v) {
                // если совсем пустой — можно пропустить, отфильтруем при сохранении
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: f.weightCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Количество',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: f.unit,
                    decoration: const InputDecoration(
                      labelText: 'Ед.',
                      isDense: true,
                    ),
                    items: Ingredient.allUnits
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => f.unit = v);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: f.priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Стоимость (необязательно)',
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
    );
  }
}

// Вспомогательный класс — состояние формы одного ингредиента
class _IngredientForm {
  final TextEditingController nameCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController priceCtrl;
  String unit;

  _IngredientForm({
    String name = '',
    String weight = '',
    String price = '',
    this.unit = 'г',
  })  : nameCtrl = TextEditingController(text: name),
        weightCtrl = TextEditingController(text: weight),
        priceCtrl = TextEditingController(text: price);

  factory _IngredientForm.fromIngredient(Ingredient ing) {
    final v = ing.weight;
    final weightStr =
        v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
    return _IngredientForm(
      name: ing.name,
      weight: weightStr,
      price: ing.price != null ? ing.price!.toString() : '',
      unit: ing.unit,
    );
  }

  // Получить введённое количество (в выбранной единице — без перевода)
  double? get parsedAmount {
    final text = weightCtrl.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  void dispose() {
    nameCtrl.dispose();
    weightCtrl.dispose();
    priceCtrl.dispose();
  }
}

