import 'package:flutter/material.dart';
import 'package:noty/auth/screens/login_screen.dart';
import 'package:noty/auth/widgets/auth_gate.dart';
import 'package:noty/core/network/backend_client.dart';
import 'package:noty/core/theme/app_theme.dart';
import 'package:noty/home/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackendClient.initialize();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: const AuthGate(signedIn: HomeScreen(), signedOut: LoginScreen()),
    );
  }
}
