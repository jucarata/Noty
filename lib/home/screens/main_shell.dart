import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noty/auth/models/auth_session.dart';
import 'package:noty/auth/services/auth_service.dart';
import 'package:noty/core/navigation/app_navigator.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/family/screens/family_screen.dart';
import 'package:noty/home/screens/home_screen.dart';
import 'package:noty/home/widgets/app_bottom_nav.dart';
import 'package:noty/notifications/screens/notifications_screen.dart';
import 'package:noty/notifications/screens/alarm_permissions_screen.dart';
import 'package:noty/notifications/services/alarm_permissions.dart';
import 'package:noty/notifications/services/notificator.dart';
import 'package:noty/profile/screens/profile_screen.dart';

/// Marco con sesión: footer de la app. Cambia entre inicio, notificaciones, familia y perfil.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.authService});

  final AuthService? authService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final AuthService _auth;
  late final Future<void> _notificatorReady;
  var _selected = AppDestination.home;
  var _permissionsGranted = false;
  var _checkingPermissions = true;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    WidgetsBinding.instance.addObserver(this);
    _notificatorReady = Notificator.instance.initialize(
      navigatorKey: notyNavigatorKey,
    );
    unawaited(_checkPermissions());
  }

  Future<void> _checkPermissions() async {
    final granted = await AlarmPermissions.instance.allGranted;
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionsGranted = granted;
      _checkingPermissions = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(Notificator.instance.refresh());
      unawaited(_checkPermissions());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _notificatorReady,
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (initSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No pudimos preparar los recordatorios. Cierra y abre la app.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.grisMedio,
                  ),
                ),
              ),
            ),
          );
        }

        if (_checkingPermissions) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!_permissionsGranted) {
          return AlarmPermissionsScreen(
            onComplete: () {
              setState(() => _permissionsGranted = true);
            },
          );
        }

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
                    authService: _auth,
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
      },
    );
  }
}
