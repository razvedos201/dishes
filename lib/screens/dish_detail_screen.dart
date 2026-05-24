import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/dish.dart';

class DishDetailScreen extends StatelessWidget {
  final Dish dish;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DishDetailScreen({
    super.key,
    required this.dish,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _share() async {
    final text = dish.toShareText();
    if (dish.imagePath != null && File(dish.imagePath!).existsSync()) {
      await Share.shareXFiles(
        [XFile(dish.imagePath!)],
        text: text,
        subject: 'Блюдо: ${dish.name}',
      );
    } else {
      await Share.share(text, subject: 'Блюдо: ${dish.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        dish.imagePath != null && File(dish.imagePath!).existsSync();
    // Подсчёт общей стоимости
    double total = 0;
    bool hasAnyPrice = false;
    for (final i in dish.ingredients) {
      if (i.price != null) {
        total += i.price!;
        hasAnyPrice = true;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(dish.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Редактировать',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Удалить',
            onPressed: onDelete,
          ),
        ],
      ),
      body: ListView(
        children: [
          if (hasImage)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.file(File(dish.imagePath!), fit: BoxFit.cover),
            )
          else
            Container(
              height: 180,
              color: Colors.orange.shade100,
              child: Center(
                child: Icon(Icons.restaurant,
                    size: 80, color: Colors.orange.shade700),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ингредиентов: ${dish.ingredients.length}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Состав:',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...dish.ingredients.map((ing) {
                  return Card(
                    elevation: 0,
                    color: Colors.grey.shade100,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade200,
                        child: const Icon(Icons.eco, color: Colors.white),
                      ),
                      title: Text(
                        ing.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(ing.amountDisplay),
                      trailing: ing.price != null
                          ? Text(
                              '${ing.price!.toStringAsFixed(2)} ₽',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                  );
                }),
                if (hasAnyPrice) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Итого: ',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${total.toStringAsFixed(2)} ₽',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _share,
        icon: const Icon(Icons.share),
        label: const Text('Отправить'),
      ),
    );
  }
}
