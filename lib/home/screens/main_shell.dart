import 'package:flutter/material.dart';
import 'package:noty/auth/services/auth_service.dart';
import 'package:noty/home/screens/home_screen.dart';
import 'package:noty/home/widgets/app_bottom_nav.dart';

/// Marco con sesión: footer de la app. Inicio es el módulo home; Perfil llega después.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.authService});

  final AuthService? authService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _homeIndex = 0;

  var _selectedIndex = _homeIndex;

  void _onTap(int index) {
    if (index == _homeIndex) {
      setState(() => _selectedIndex = _homeIndex);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeScreen(authService: widget.authService),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onTap: _onTap,
      ),
    );
  }
}
