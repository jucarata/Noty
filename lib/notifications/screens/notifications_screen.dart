import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noty/auth/models/auth_session.dart';
import 'package:noty/auth/services/auth_service.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/notifications/models/new_reminder.dart';
import 'package:noty/notifications/models/reminder.dart';
import 'package:noty/notifications/screens/add_notification_screen.dart';
import 'package:noty/notifications/services/notificator.dart';
import 'package:noty/notifications/widgets/reminder_card.dart';

/// Lista de recordatorios. Quien cuida puede crear y editar; quien recibe
/// (sesión anónima) solo ve las alarmas que le asignaron.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.authService,
    this.notificator,
    this.isSelected = true,
  });

  final AuthService? authService;
  final Notificator? notificator;
  final bool isSelected;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final AuthService _auth;
  late final Notificator _notificator;
  StreamSubscription<void>? _localSubscription;

  var _loading = true;
  List<Reminder> _reminders = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _notificator = widget.notificator ?? Notificator.instance;
    _localSubscription = _notificator.localChanges.listen((_) {
      if (mounted) {
        unawaited(_loadFromCache());
      }
    });
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _notificator.ensureReady();
    if (!mounted) {
      return;
    }
    await _load(syncFromNetwork: true);
  }

  @override
  void dispose() {
    unawaited(_localSubscription?.cancel());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      unawaited(_load(syncFromNetwork: true));
    }
  }

  /// Solo repinta desde caché (el sync ya lo hizo quien disparó el cambio).
  Future<void> _loadFromCache() async {
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

  Future<void> _load({bool showSpinner = true, bool syncFromNetwork = false}) async {
    final shouldShowSpinner = showSpinner && _reminders.isEmpty && _error == null;
    if (shouldShowSpinner) {
      setState(() => _loading = true);
    }

    try {
      if (syncFromNetwork) {
        await _notificator.refresh();
      }
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
    if (!_notificator.canManageReminders) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddNotificationScreen(notificator: _notificator),
      ),
    );
    if (mounted) {
      await _load(syncFromNetwork: true);
    }
  }

  Future<void> _openEdit(Reminder reminder) async {
    if (!_notificator.canManageReminders) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddNotificationScreen(
          notificator: _notificator,
          reminder: reminder,
        ),
      ),
    );
    if (mounted) {
      await _load(syncFromNetwork: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      initialData: _auth.currentSession,
      stream: _auth.sessions,
      builder: (context, snapshot) {
        final canManage = snapshot.data?.isAnonymous == false;
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
                      if (canManage)
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
                    canManage
                        ? 'Los recordatorios que acompañan el día a día.'
                        : 'Estos avisos te van a acompañar. Solo tu familia puede cambiarlos.',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: AppColors.grisMedio),
                  ),
                  const SizedBox(height: 24),
                  Expanded(child: _body(context, canManage: canManage)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, {required bool canManage}) {
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
        text: canManage
            ? 'Todavía no hay recordatorios. Pulsa + para añadir el primero.'
            : 'Todavía no hay recordatorios. Cuando tu familia te asigne uno, aparecerá aquí.',
        actionLabel: canManage ? 'Añadir notificación' : null,
        onAction: canManage ? _openAdd : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(syncFromNetwork: true),
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
            isActive: reminder.isActive,
            onTap: canManage ? () => unawaited(_openEdit(reminder)) : null,
          );
        },
      ),
    );
  }

  Widget _message(
    BuildContext context, {
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
