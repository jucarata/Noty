import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noty/core/network/backend_client.dart';
import 'package:noty/notifications/models/new_reminder.dart';
import 'package:noty/notifications/models/reminder.dart';
import 'package:noty/notifications/screens/alarm_ring_screen.dart';
import 'package:noty/notifications/services/alarm_scheduler.dart';
import 'package:noty/notifications/services/alarm_sound_player.dart';
import 'package:noty/notifications/services/reminder_sync.dart';
import 'package:noty/notifications/services/timezone_config.dart';

/// Fachada de la feature notifications.
///
/// Las pantallas hablan solo con esta clase. Lee la caché local, sincroniza
/// con la nube y programa las alarmas del sistema operativo.
class Notificator {
  Notificator._({
    required AlarmScheduler scheduler,
    BackendClient? client,
    ReminderSync? sync,
  }) : _scheduler = scheduler,
       _client = client ?? BackendClient.instance,
       _sync = sync ?? ReminderSync(scheduler: scheduler);

  static final Notificator instance = () {
    final scheduler = AlarmScheduler();
    return Notificator._(
      scheduler: scheduler,
      sync: ReminderSync(scheduler: scheduler),
    );
  }();

  factory Notificator({
    BackendClient? client,
    ReminderSync? sync,
    AlarmScheduler? scheduler,
  }) {
    if (client != null || sync != null || scheduler != null) {
      final sharedScheduler = scheduler ?? AlarmScheduler();
      return Notificator._(
        scheduler: sharedScheduler,
        client: client,
        sync: sync ?? ReminderSync(scheduler: sharedScheduler),
      );
    }
    return instance;
  }

  final BackendClient _client;
  final ReminderSync _sync;
  final AlarmScheduler _scheduler;

  GlobalKey<NavigatorState>? _navigatorKey;
  var _initialized = false;
  Completer<void>? _initCompleter;
  final _localChanges = StreamController<void>.broadcast();
  var _openingAlarm = false;
  AlarmPayload? _queuedAlarmPayload;
  String? _activeAlarmKey;

  Stream<void> get localChanges => _localChanges.stream;

  bool get isInitialized => _initialized;

  /// Crear, editar y eliminar es de quien cuida (cuenta real). La persona
  /// acompañada con sesión anónima solo ve y confirma.
  bool get canManageReminders {
    final session = _client.currentSession;
    return session != null && !session.isAnonymous;
  }

  /// Espera a que [initialize] termine (alarmas listas para programarse).
  Future<void> ensureReady() async {
    if (_initialized) {
      return;
    }
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    throw StateError(
      'Notificator aún no arrancó. MainShell debe llamar initialize() primero.',
    );
  }

  Future<void> initialize({required GlobalKey<NavigatorState> navigatorKey}) async {
    _navigatorKey = navigatorKey;
    if (_initialized) {
      await _sync.startListening(_notifyLocalChange);
      await _sync.sync(onLocalChange: _notifyLocalChange);
      return;
    }
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();
    try {
      await configureDeviceTimezone();
      await _scheduler.initialize(onAlarmTap: _openAlarmFromPayload);
      await _sync.startListening(_notifyLocalChange);
      await _sync.sync(onLocalChange: _notifyLocalChange);
      _initialized = true;
      _initCompleter!.complete();
      debugPrint('Noty: inicializado; alarmas pendientes=${await _scheduler.pendingCount()}');
      final queued = _queuedAlarmPayload;
      if (queued != null) {
        _queuedAlarmPayload = null;
        unawaited(_openAlarmFromPayload(queued));
      }
    } catch (error, stack) {
      _initCompleter!.completeError(error, stack);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _sync.stopListening();
    await _localChanges.close();
    _initialized = false;
    _initCompleter = null;
  }

  void _notifyLocalChange() {
    if (!_localChanges.isClosed) {
      _localChanges.add(null);
    }
  }

  Future<void> refresh() async {
    await ensureReady();
    await _sync.startListening(_notifyLocalChange);
    await _sync.sync(onLocalChange: _notifyLocalChange);
  }

  /// Quita alarmas pendientes, sonido activo y caché local de recordatorios.
  Future<void> clearLocalAlarmsAndCache() async {
    await AlarmSoundPlayer().stop();
    await _sync.clearLocalState();
    _queuedAlarmPayload = null;
    _activeAlarmKey = null;
    _openingAlarm = false;
    _notifyLocalChange();
  }

  /// Crea el recordatorio y lo asigna a los teléfonos elegidos.
  Future<void> createReminder(NewReminder reminder) async {
    _requireCanManage();
    await ensureReady();
    await _upsert(reminder);
    await refresh();
  }

  /// Guarda cambios de un recordatorio existente y sus teléfonos.
  Future<void> updateReminder(String id, NewReminder reminder) async {
    _requireCanManage();
    await ensureReady();
    await _upsert(reminder, id: id);
    await refresh();
  }

  /// Elimina el recordatorio (soft delete) y lo desvincula de todos los devices.
  Future<void> deleteReminder(String id) async {
    _requireCanManage();
    try {
      await _client.deleteReminder(id: id);
      await _scheduler.cancelReminder(id);
      await refresh();
    } on BackendAuthException catch (error) {
      throw NotificatorFailure(_copyForDelete(error));
    } catch (_) {
      throw const NotificatorFailure(
        'No pudimos eliminar el recordatorio. Intentémoslo nuevamente.',
      );
    }
  }

  /// Recordatorios para pintar la lista. Siempre desde la caché local.
  Future<List<Reminder>> listReminders() async {
    if (!_initialized) {
      try {
        await ensureReady();
      } catch (_) {
        return _sync.readLocalReminders();
      }
    }

    final reminders = await _sync.readLocalReminders();
    reminders.sort(_byNextThenCreated);
    return reminders;
  }

  /// Confirma que se completó la tarea de esta ocurrencia.
  Future<void> confirmOccurrence({
    required String reminderId,
    required DateTime dueAt,
  }) {
    return _respond(
      reminderId: reminderId,
      dueAt: dueAt,
      response: 'confirmed',
    );
  }

  /// Marca la ocurrencia como ignorada (p. ej. tras 90 s sin confirmar).
  Future<void> ignoreOccurrence({
    required String reminderId,
    required DateTime dueAt,
  }) {
    return _respond(
      reminderId: reminderId,
      dueAt: dueAt,
      response: 'ignored',
    );
  }

  Future<void> _respond({
    required String reminderId,
    required DateTime dueAt,
    required String response,
  }) async {
    await _sync.applyLocalResponse(
      reminderId: reminderId,
      dueAt: dueAt.toUtc(),
      response: response,
    );
    _notifyLocalChange();
  }

  String _alarmKey(AlarmPayload payload) {
    return '${payload.reminderId}|${payload.dueAt.toUtc().toIso8601String()}';
  }

  Future<void> _openAlarmFromPayload(AlarmPayload payload, {int attempt = 0}) async {
    final key = _alarmKey(payload);
    if (_activeAlarmKey == key) {
      return;
    }

    if (_openingAlarm) {
      if (_queuedAlarmPayload != null && _alarmKey(_queuedAlarmPayload!) == key) {
        return;
      }
      _queuedAlarmPayload = payload;
      return;
    }

    if (!_initialized) {
      if (attempt < 40) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return _openAlarmFromPayload(payload, attempt: attempt + 1);
      }
      _queuedAlarmPayload = payload;
      return;
    }

    var reminder = await _sync.findReminder(payload.reminderId);
    if (reminder == null) {
      await refresh();
      reminder = await _sync.findReminder(payload.reminderId);
      if (reminder == null) {
        if (attempt < 5) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return _openAlarmFromPayload(payload, attempt: attempt + 1);
        }
        return;
      }
    }

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      if (attempt < 40) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return _openAlarmFromPayload(payload, attempt: attempt + 1);
      }
      _queuedAlarmPayload = payload;
      return;
    }

    _openingAlarm = true;
    _activeAlarmKey = key;
    try {
      final route = MaterialPageRoute<void>(
        builder: (_) => AlarmRingScreen(
          reminder: reminder!,
          dueAt: payload.dueAt.toLocal(),
        ),
        fullscreenDialog: true,
      );
      await navigator.push(route);
    } finally {
      _openingAlarm = false;
      if (_activeAlarmKey == key) {
        _activeAlarmKey = null;
      }
      final queued = _queuedAlarmPayload;
      _queuedAlarmPayload = null;
      if (queued != null && _alarmKey(queued) != key) {
        unawaited(_openAlarmFromPayload(queued));
      }
    }
  }

  void _requireCanManage() {
    if (canManageReminders) {
      return;
    }
    throw const NotificatorFailure(
      'Solo quien creó el recordatorio o el host de la familia puede cambiarlo.',
    );
  }

  Future<void> _upsert(NewReminder reminder, {String? id}) async {
    try {
      final timeLocal = _formatTime(reminder.hour, reminder.minute);
      final startDate = _formatDate(reminder.startDate);
      if (id == null) {
        await _client.createReminder(
          name: reminder.name,
          description: reminder.description,
          timeLocal: timeLocal,
          timezone: reminder.timezone,
          startDate: startDate,
          singleUse: reminder.singleUse,
          everyDay: reminder.everyDay,
          monday: reminder.monday,
          tuesday: reminder.tuesday,
          wednesday: reminder.wednesday,
          thursday: reminder.thursday,
          friday: reminder.friday,
          saturday: reminder.saturday,
          sunday: reminder.sunday,
          runDays: reminder.runDays,
          deviceIds: reminder.deviceIds,
        );
      } else {
        await _client.updateReminder(
          id: id,
          name: reminder.name,
          description: reminder.description,
          timeLocal: timeLocal,
          timezone: reminder.timezone,
          startDate: startDate,
          singleUse: reminder.singleUse,
          everyDay: reminder.everyDay,
          monday: reminder.monday,
          tuesday: reminder.tuesday,
          wednesday: reminder.wednesday,
          thursday: reminder.thursday,
          friday: reminder.friday,
          saturday: reminder.saturday,
          sunday: reminder.sunday,
          runDays: reminder.runDays,
          deviceIds: reminder.deviceIds,
        );
      }
    } on BackendAuthException catch (error) {
      throw NotificatorFailure(_copyFor(error));
    } catch (_) {
      throw const NotificatorFailure(
        'No pudimos guardar el recordatorio. Intentémoslo nuevamente.',
      );
    }
  }

  int _byNextThenCreated(Reminder a, Reminder b) {
    final nextA = a.nextAt;
    final nextB = b.nextAt;
    if (nextA == null && nextB == null) {
      return b.createdAt.compareTo(a.createdAt);
    }
    if (nextA == null) {
      return 1;
    }
    if (nextB == null) {
      return -1;
    }
    final byNext = nextA.compareTo(nextB);
    if (byNext != 0) {
      return byNext;
    }
    return b.createdAt.compareTo(a.createdAt);
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _copyFor(BackendAuthException error) {
    if (error.code == 'missing_session') {
      return 'Para guardar un recordatorio, entra a la app.';
    }
    if (error.code == 'anonymous_not_allowed') {
      return 'Para guardar un recordatorio, entra o crea una cuenta.';
    }

    final message = error.message.trim();
    if (message.contains('Debes entrar') ||
        message.contains('Inicia sesión') ||
        message.contains('Ponle un nombre') ||
        message.contains('Elige la hora') ||
        message.contains('Elige el día') ||
        message.contains('Elige al menos') ||
        message.contains('no está en tu familia') ||
        message.contains('días de ejecución') ||
        message.contains('No encontramos este recordatorio') ||
        message.contains('gestionar recordatorios')) {
      return message;
    }

    return 'No pudimos guardar el recordatorio. Intentémoslo nuevamente.';
  }

  String _copyForDelete(BackendAuthException error) {
    if (error.code == 'missing_session' ||
        error.code == 'anonymous_not_allowed') {
      return 'Para eliminar un recordatorio, entra o crea una cuenta.';
    }
    final message = error.message.trim();
    if (message.contains('No encontramos') ||
        message.contains('Inicia sesión') ||
        message.contains('Debes entrar')) {
      return message;
    }
    return 'No pudimos eliminar el recordatorio. Intentémoslo nuevamente.';
  }
}
