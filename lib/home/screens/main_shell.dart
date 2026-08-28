import 'package:flutter/material.dart';
import 'package:noty/auth/models/auth_session.dart';
import 'package:noty/auth/services/auth_service.dart';
import 'package:noty/family/screens/family_screen.dart';
import 'package:noty/home/screens/home_screen.dart';
import 'package:noty/home/widgets/app_bottom_nav.dart';
import 'package:noty/notifications/screens/notifications_screen.dart';
import 'package:noty/profile/screens/profile_screen.dart';

/// Marco con sesión: footer de la app. Cambia entre inicio, notificaciones, familia y perfil.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.authService});

  final AuthService? authService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final AuthService _auth;
  var _selected = AppDestination.home;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      initialData: _auth.currentSession,
      stream: _auth.sessions,
      builder: (context, snapshot) {
        final showFamily = snapshot.data?.isAnonymous == false;
        final destinations = AppBottomNav.destinationsFor(
          showFamily: showFamily,
        );
        final selected = destinations.contains(_selected)
            ? _selected
            : AppDestination.home;

        return Scaffold(
          body: IndexedStack(
            index: switch (selected) {
              AppDestination.home => 0,
              AppDestination.notifications => 1,
              AppDestination.family => 2,
              AppDestination.profile => 3,
            },
            children: [
              HomeScreen(authService: _auth),
              NotificationsScreen(
                isSelected: selected == AppDestination.notifications,
              ),
              if (showFamily)
                FamilyScreen(isSelected: selected == AppDestination.family)
              else
                const SizedBox.shrink(),
              ProfileScreen(authService: _auth),
            ],
          ),
          bottomNavigationBar: AppBottomNav(
            destinations: destinations,
            selected: selected,
            onSelected: (destination) {
              setState(() => _selected = destination);
            },
          ),
        );
      },
    );
  }
}
