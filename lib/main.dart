import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'screens/home_screen.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // На первом запуске подгружаем встроенный каталог продуктов из assets.
  // Если пользователь уже создал свой каталог — не трогаем (см. флаг внутри).
  try {
    final defaultJson =
        await rootBundle.loadString('assets/default_products.json');
    await StorageService().initializeDefaultProductsIfNeeded(defaultJson);
  } catch (e) {
    // Не критично: если asset не загрузится, приложение просто стартует
    // с пустым каталогом и пользователь добавит продукты сам.
    // ignore: avoid_print
    print('Не удалось загрузить дефолтный каталог продуктов: $e');
  }
  runApp(const DishesApp());
}

class DishesApp extends StatelessWidget {
  const DishesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мои блюда',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
