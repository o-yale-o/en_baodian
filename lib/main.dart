import 'package:flutter/material.dart';
import 'data/seed_data.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await seedDatabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '英语宝典',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(fontWeight: FontWeight.w500),
          titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontWeight: FontWeight.w500),
          headlineLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      home: const HomePage(),
    );
  }
}
