import 'package:flutter/material.dart';
import 'package:noty/core/theme/app_colors.dart';

/// Tarjeta de un recordatorio: qué, a qué hora, cuándo y para quién.
class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.name,
    required this.timeLabel,
    required this.nextDayLabel,
    required this.deviceLabel,
    this.description,
  });

  final String name;
  final String? description;
  final String timeLabel;
  final String nextDayLabel;
  final String deviceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: '$name. $timeLabel. $nextDayLabel. $deviceLabel',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.blanco,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grisClaro),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.grisClaro,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.notifications_rounded,
                    color: AppColors.azulNoty,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleLarge),
                    if (description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        description!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.grisMedio,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      timeLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.grisOscuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Próximo aviso: $nextDayLabel',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.grisMedio,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deviceLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.grisMedio,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
