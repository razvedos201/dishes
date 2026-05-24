import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
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
