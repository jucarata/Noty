import 'package:flutter/material.dart';
import 'package:noty/core/theme/app_colors.dart';

enum AppDestination { home, devices, profile }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelected,
  });

  final List<AppDestination> destinations;
  final AppDestination selected;
  final ValueChanged<AppDestination> onSelected;

  static List<AppDestination> destinationsFor({required bool showDevices}) {
    return [
      AppDestination.home,
      if (showDevices) AppDestination.devices,
      AppDestination.profile,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = destinations
        .indexOf(selected)
        .clamp(0, destinations.length - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ColoredBox(
          color: AppColors.grisClaro,
          child: SizedBox(width: double.infinity, height: 1),
        ),
        BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) => onSelected(destinations[index]),
          elevation: 0,
          iconSize: 28,
          items: [for (final destination in destinations) _item(destination)],
        ),
      ],
    );
  }

  BottomNavigationBarItem _item(AppDestination destination) {
    return switch (destination) {
      AppDestination.home => const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home_rounded),
        label: 'Inicio',
      ),
      AppDestination.devices => const BottomNavigationBarItem(
        icon: Icon(Icons.devices_outlined),
        activeIcon: Icon(Icons.devices_rounded),
        label: 'Dispositivos',
      ),
      AppDestination.profile => const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person_rounded),
        label: 'Perfil',
      ),
    };
  }
}
