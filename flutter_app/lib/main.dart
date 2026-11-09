import 'package:flutter/material.dart';

import 'screens/restaurant_list_page.dart';

void main() {
  runApp(const NomondoApp());
}

class NomondoApp extends StatelessWidget {
  const NomondoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF245D50),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Nomondo · Restaurants',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: const Color(0xFFF6F5F0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      home: const RestaurantListPage(),
    );
  }
}
