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
    this.responseLabel,
  });

  final String name;
  final String? description;
  final String timeLabel;
  final String nextDayLabel;
  final String deviceLabel;
  final bool isActive;
  final VoidCallback? onTap;
  final String? responseLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      button: onTap != null,
      label:
          '$name. ${isActive ? 'Activa' : 'Inactiva'}. $timeLabel. $nextDayLabel. $deviceLabel'
          '${responseLabel == null ? '' : '. $responseLabel'}',
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.grisClaro,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.notifications_rounded,
                        color: AppColors.azulNoty,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(active: isActive),
                          ],
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.grisMedio,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          timeLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.grisOscuro,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nextDayLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.grisMedio,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deviceLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.grisMedio,
                          ),
                        ),
                        if (responseLabel != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            responseLabel!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.grisOscuro,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
