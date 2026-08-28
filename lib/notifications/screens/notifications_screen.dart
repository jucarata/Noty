import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/notifications/models/new_reminder.dart';
import 'package:noty/notifications/models/reminder.dart';
import 'package:noty/notifications/screens/add_notification_screen.dart';
import 'package:noty/notifications/services/notificator.dart';
import 'package:noty/notifications/widgets/reminder_card.dart';

/// Lista de recordatorios creados. Recarga al volver al tab y tras añadir.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.notificator,
    this.isSelected = true,
  });

  final Notificator? notificator;
  final bool isSelected;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Notificator _notificator;

  var _loading = true;
  List<Reminder> _reminders = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _notificator = widget.notificator ?? Notificator();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final showSpinner = _reminders.isEmpty && _error == null;
    if (showSpinner) {
      setState(() => _loading = true);
    }

    try {
      final reminders = await _notificator.listReminders();
      if (!mounted) {
        return;
      }
      setState(() {
        _reminders = reminders;
        _error = null;
        _loading = false;
      });
    } on NotificatorFailure catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('No pudimos cargar tus recordatorios. Intentémoslo de nuevo.');
    }
  }

  void _fail(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      if (_reminders.isEmpty) {
        _error = message;
      }
    });

    if (_reminders.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddNotificationScreen(notificator: _notificator),
      ),
    );
    if (mounted) {
      await _load();
    }
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
                    onPressed: _openAdd,
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
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _message(
        context,
        text: _error!,
        actionLabel: 'Intentar de nuevo',
        onAction: _load,
      );
    }

    if (_reminders.isEmpty) {
      return _message(
        context,
        text: 'Todavía no hay recordatorios. Pulsa + para añadir el primero.',
        actionLabel: 'Añadir notificación',
        onAction: _openAdd,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _reminders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final reminder = _reminders[index];
          return ReminderCard(
            key: ValueKey(reminder.id),
            name: reminder.name,
            description: reminder.description,
            timeLabel: reminder.timeLabel,
            nextDayLabel: reminder.nextDayLabel,
            deviceLabel: reminder.deviceLabel,
          );
        },
      ),
    );
  }

  Widget _message(
    BuildContext context, {
    required String text,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.grisMedio),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
