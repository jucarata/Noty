import 'package:flutter/material.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/notifications/screens/add_notification_screen.dart';

/// Lista de recordatorios. Por ahora solo la entrada visual al alta.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  void _openAdd(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AddNotificationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notificaciones',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () => _openAdd(context),
                    tooltip: 'Añadir notificación',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.azulNoty,
                      foregroundColor: AppColors.blanco,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Los recordatorios que acompañan el día a día.',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppColors.grisMedio),
              ),
              const SizedBox(height: 24),
              Expanded(child: _empty(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(
          'Todavía no hay recordatorios. Pulsa + para añadir el primero.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.grisMedio),
        ),
      ),
    );
  }
}
