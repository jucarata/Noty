import 'package:flutter/material.dart';
import 'package:noty/auth/models/auth_session.dart';
import 'package:noty/auth/services/auth_service.dart';
import 'package:noty/devices/screens/devices_screen.dart';
import 'package:noty/home/screens/home_screen.dart';
import 'package:noty/home/widgets/app_bottom_nav.dart';
import 'package:noty/profile/screens/profile_screen.dart';

/// Marco con sesión: footer de la app. Cambia entre inicio, dispositivos y perfil.
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
        final showDevices = snapshot.data?.isAnonymous == false;
        final destinations = AppBottomNav.destinationsFor(
          showDevices: showDevices,
        );
        final selected = destinations.contains(_selected)
            ? _selected
            : AppDestination.home;

        return Scaffold(
          body: IndexedStack(
            index: switch (selected) {
              AppDestination.home => 0,
              AppDestination.devices => 1,
              AppDestination.profile => 2,
            },
            children: [
              HomeScreen(authService: _auth),
              if (showDevices)
                DevicesScreen(isSelected: selected == AppDestination.devices)
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
