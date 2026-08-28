import 'package:flutter/material.dart';
import 'package:noty/core/theme/app_colors.dart';

/// Teléfono vinculado que puede recibir este recordatorio.
class NotificationDeviceTile extends StatelessWidget {
  const NotificationDeviceTile({
    super.key,
    required this.name,
    required this.phoneDescription,
    required this.selected,
    required this.onChanged,
  });

  final String name;
  final String phoneDescription;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: Material(
        color: AppColors.blanco,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.azulMedio : AppColors.grisClaro,
                width: selected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              child: Row(
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
                        Text(name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          phoneDescription,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.grisMedio,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: selected,
                    onChanged: (value) => onChanged(value ?? false),
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
