import 'package:flutter/material.dart';
import 'package:noty/core/theme/app_colors.dart';

/// Tarjeta de un familiar acompañado: su teléfono y su última conexión.
class FamilyMemberCard extends StatelessWidget {
  const FamilyMemberCard({
    super.key,
    required this.name,
    required this.phoneDescription,
    required this.lastSeenLabel,
  });

  final String name;
  final String phoneDescription;
  final String lastSeenLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: '$name, a tu cargo. $phoneDescription. $lastSeenLabel',
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
                    Icons.person_rounded,
                    color: AppColors.azulNoty,
                    size: 28,
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
                          child: Text(name, style: theme.textTheme.titleLarge),
                        ),
                        const SizedBox(width: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5F1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              'A tu cargo',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.verde,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phoneDescription,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.grisMedio,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lastSeenLabel,
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
