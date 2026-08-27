import 'package:flutter/material.dart';
import 'package:noty/auth/services/auth_service.dart';
import 'package:noty/home/screens/home_screen.dart';
import 'package:noty/home/widgets/app_bottom_nav.dart';
import 'package:noty/profile/screens/profile_screen.dart';

/// Marco con sesión: footer de la app. Cambia entre home y perfil.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.authService});

  final AuthService? authService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _selectedIndex = AppBottomNav.homeIndex;

  void _onTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(authService: widget.authService),
          ProfileScreen(authService: widget.authService),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onTap: _onTap,
      ),
    );
  }
}
