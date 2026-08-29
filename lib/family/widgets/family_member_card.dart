import 'package:flutter/material.dart';
import 'package:noty/core/theme/app_colors.dart';

/// Tarjeta de un familiar acompañado y el teléfono con el que lo acompañas.
class FamilyMemberCard extends StatelessWidget {
  const FamilyMemberCard({
    super.key,
    required this.name,
    required this.phoneModel,
    this.onUnlink,
    this.unlinking = false,
  });

  final String name;
  final String phoneModel;
  final VoidCallback? onUnlink;
  final bool unlinking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: '$name, a tu cargo. $phoneModel',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.blanco,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grisClaro),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 48, 20),
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
                              child: Text(
                                name,
                                style: theme.textTheme.titleLarge,
                              ),
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
                          phoneModel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.grisMedio,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: _UnlinkButton(
                name: name,
                onUnlink: onUnlink,
                unlinking: unlinking,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlinkButton extends StatelessWidget {
  const _UnlinkButton({
    required this.name,
    required this.onUnlink,
    required this.unlinking,
  });

  final String name;
  final VoidCallback? onUnlink;
  final bool unlinking;

  @override
  Widget build(BuildContext context) {
    if (unlinking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      tooltip: 'Desvincular a $name',
      onPressed: onUnlink,
      icon: const Icon(Icons.close_rounded),
      color: AppColors.grisMedio,
      iconSize: 22,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}
