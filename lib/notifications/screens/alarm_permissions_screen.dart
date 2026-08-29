import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noty/core/constants/app_assets.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/notifications/services/alarm_permissions.dart';

/// Pantalla inicial para pedir permisos de alarma con pasos simples.
class AlarmPermissionsScreen extends StatefulWidget {
  const AlarmPermissionsScreen({
    super.key,
    required this.onComplete,
    this.permissions,
  });

  final VoidCallback onComplete;
  final AlarmPermissions? permissions;

  @override
  State<AlarmPermissionsScreen> createState() => _AlarmPermissionsScreenState();
}

class _AlarmPermissionsScreenState extends State<AlarmPermissionsScreen>
    with WidgetsBindingObserver {
  late final AlarmPermissions _permissions;
  var _loading = true;
  var _requesting = false;
  List<AlarmPermissionStep> _steps = const [];
  var _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _permissions = widget.permissions ?? AlarmPermissions.instance;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reload());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reload(afterExternalSettings: true));
    }
  }

  Future<void> _reload({bool afterExternalSettings = false}) async {
    final steps = await _permissions.missingSteps();
    if (!mounted) {
      return;
    }
    if (steps.isEmpty) {
      widget.onComplete();
      return;
    }
    setState(() {
      _steps = steps;
      _stepIndex = 0;
      _loading = false;
      _requesting = false;
    });
  }

  AlarmPermissionStep? get _currentStep {
    if (_stepIndex >= _steps.length) {
      return null;
    }
    return _steps[_stepIndex];
  }

  Future<void> _onPrimaryAction() async {
    final step = _currentStep;
    if (step == null || _requesting) {
      return;
    }
    setState(() => _requesting = true);
    final granted = await _permissions.requestStep(step);
    if (!mounted) {
      return;
    }
    if (granted) {
      await _reload();
      return;
    }
    setState(() => _requesting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.blanco,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final step = _currentStep;
    if (step == null) {
      return const Scaffold(
        backgroundColor: AppColors.blanco,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final total = _steps.length;
    final current = _stepIndex + 1;

    return Scaffold(
      backgroundColor: AppColors.blanco,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              Image.asset(
                AppAssets.notyIsotype,
                height: 72,
                width: 72,
              ),
              const SizedBox(height: 28),
              Text(
                'Activa los avisos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.azulNoty,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Paso $current de $total',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.grisMedio,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                step.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.grisOscuro,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                step.body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.grisMedio,
                  height: 1.45,
                ),
              ),
              if (step.hintAfterAction case final hint?) ...[
                const SizedBox(height: 20),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.azulNoty,
                    height: 1.4,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _requesting ? null : _onPrimaryAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.azulMedio,
                    disabledBackgroundColor: AppColors.grisClaro,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _requesting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.blanco,
                          ),
                        )
                      : Text(
                          step.actionLabel,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.blanco,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
