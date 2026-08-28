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
    required this.isActive,
    this.description,
    this.onTap,
  });

  final String name;
  final String? description;
  final String timeLabel;
  final String nextDayLabel;
  final String deviceLabel;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      button: onTap != null,
      label:
          '$name. ${isActive ? 'Activa' : 'Inactiva'}. $timeLabel. $nextDayLabel. $deviceLabel',
      child: Material(
        color: AppColors.blanco,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(active: isActive),
                          ],
                        ),
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
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F5F1) : AppColors.grisClaro,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          active ? 'Activa' : 'Inactiva',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: active ? AppColors.verde : AppColors.grisMedio,
          ),
        ),
      ),
    );
  }
}
