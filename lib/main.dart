import 'package:flutter/material.dart';
import 'package:noty/home/screens/home_screen.dart';
import 'package:noty/core/theme/app_theme.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
