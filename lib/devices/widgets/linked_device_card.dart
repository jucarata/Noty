import 'package:flutter/material.dart';
import 'package:noty/core/theme/app_colors.dart';

/// Agrupa nombre, marca/modelo y última conexión de un dispositivo vinculado.
class LinkedDeviceCard extends StatelessWidget {
  const LinkedDeviceCard({
    super.key,
    required this.customName,
    required this.brandModel,
    required this.lastSeenLabel,
  });

  final String customName;
  final String brandModel;
  final String lastSeenLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: '$customName. $brandModel. $lastSeenLabel',
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
                    Icons.smartphone_rounded,
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
                    Text(customName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      brandModel,
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
