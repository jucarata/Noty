import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/notifications/models/reminder.dart';
import 'package:noty/notifications/services/alarm_sound_player.dart';
import 'package:noty/notifications/services/notificator.dart';

/// Pantalla a pantalla completa cuando suena un recordatorio.
class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({
    super.key,
    required this.reminder,
    required this.dueAt,
    this.notificator,
    this.soundPlayer,
  });

  final Reminder reminder;
  final DateTime dueAt;
  final Notificator? notificator;
  final AlarmSoundPlayer? soundPlayer;

  static const autoDismissDuration = Duration(seconds: 90);

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  late final Notificator _notificator;
  late final AlarmSoundPlayer _soundPlayer;
  Timer? _autoDismissTimer;
  var _responding = false;

  @override
  void initState() {
    super.initState();
    _notificator = widget.notificator ?? Notificator.instance;
    _soundPlayer = widget.soundPlayer ?? AlarmSoundPlayer();
    unawaited(_startRinging());
    _autoDismissTimer = Timer(AlarmRingScreen.autoDismissDuration, () {
      unawaited(_dismissTimedOut());
    });
  }

  Future<void> _startRinging() async {
    try {
      await _soundPlayer.start();
    } catch (error) {
      debugPrint('Noty pantalla alarma sin sonido: $error');
    }
  }

  Future<void> _confirm() async {
    if (_responding) {
      return;
    }
    _responding = true;
    _autoDismissTimer?.cancel();
    await _soundPlayer.stop();
    await _notificator.confirmOccurrence(
      reminderId: widget.reminder.id,
      dueAt: widget.dueAt,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _dismissTimedOut() async {
    if (_responding || !mounted) {
      return;
    }
    _responding = true;
    await _soundPlayer.stop();
    await _notificator.ignoreOccurrence(
      reminderId: widget.reminder.id,
      dueAt: widget.dueAt,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    unawaited(_soundPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final description = widget.reminder.description?.trim();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.azulNoty,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(),
                Text(
                  widget.reminder.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.blanco,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.blanco.withValues(alpha: 0.92),
                      height: 1.4,
                    ),
                  ),
                ],
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'Confirmar que completaste esta tarea',
                  child: Material(
                    color: AppColors.verde,
                    shape: const CircleBorder(),
                    elevation: 6,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _confirm,
                      child: const SizedBox(
                        width: 112,
                        height: 112,
                        child: Icon(
                          Icons.check_rounded,
                          color: AppColors.blanco,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Toca para confirmar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.blanco.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
