import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:noty/care/models/device_share_code.dart';
import 'package:noty/care/services/care_service.dart';
import 'package:noty/notifications/data/local/device_registry.dart';
import 'package:noty/notifications/data/local/reminder_cache.dart';
import 'package:noty/notifications/data/remote/reminder_remote.dart';
import 'package:noty/notifications/models/reminder.dart';
import 'package:noty/notifications/services/alarm_scheduler.dart';

/// Sincroniza la caché local con la nube y reprograma alarmas.
class ReminderSync {
  ReminderSync({
    ReminderCache? cache,
    DeviceRegistry? registry,
    ReminderRemote? remote,
    AlarmScheduler? scheduler,
    CareService? careService,
    Connectivity? connectivity,
  }) : _cache = cache ?? ReminderCache(),
       _registry = registry ?? DeviceRegistry(),
       _remote = remote ?? ReminderRemote(),
       _scheduler = scheduler ?? AlarmScheduler(),
       _care = careService ?? CareService(),
       _connectivity = connectivity ?? Connectivity();

  final ReminderCache _cache;
  final DeviceRegistry _registry;
  final ReminderRemote _remote;
  final AlarmScheduler _scheduler;
  final CareService _care;
  final Connectivity _connectivity;

  RealtimeChannelHandle? _realtime;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _debounce;
  var _syncing = false;
  var _loggedScheduleSkip = false;

  Future<String?> ensureOwnDeviceId() async {
    try {
      final registered = await _care.registerThisDevice();
      await _registry.writeDeviceId(registered.deviceId);
      return registered.deviceId;
    } on CareFailure catch (error) {
      debugPrint('Noty register device: ${error.message}');
    }

    return _registry.readDeviceId();
  }

  Future<void> startListening(void Function() onLocalChange) async {
    await _realtime?.dispose();
    _realtime = _remote.subscribeToReminderChanges(() {
      _debouncedSync(onLocalChange);
    });

    await _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((result) => result != ConnectivityResult.none);
      if (online) {
        _debouncedSync(onLocalChange);
      }
    });
  }

  Future<void> stopListening() async {
    _debounce?.cancel();
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    await _realtime?.dispose();
    _realtime = null;
  }

  void _debouncedSync(void Function() onLocalChange) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(sync(onLocalChange: onLocalChange));
    });
  }

  Future<void> sync({void Function()? onLocalChange}) async {
    if (_syncing) {
      return;
    }
    _syncing = true;
    try {
      await _flushPendingResponses();
      final previous = await _cache.readReminders();
      final reminders = await _remote.fetchReminders();
      final changed = !_sameReminders(previous, reminders);
      await _cache.writeReminders(reminders);

      final deviceId = await ensureOwnDeviceId();
      if (deviceId == null) {
        debugPrint('Noty sync: sin devices.id local; no se programan alarmas');
      } else {
        final report = await _scheduler.rescheduleAll(
          reminders: reminders,
          deviceId: deviceId,
        );
        if (!report.hasScheduled) {
          final mine = reminders.where((r) => r.ringsOnDevice(deviceId));
          final pendingSchedule = mine.where((r) => r.isActive && r.nextAt != null);
          if (pendingSchedule.isNotEmpty && !_loggedScheduleSkip) {
            _loggedScheduleSkip = true;
            debugPrint(
              'Noty sync: ${pendingSchedule.length} recordatorio(s) con hora futura '
              'pero sin alarma programada (revisa permisos).',
            );
          }
        }
        if (report.hasScheduled) {
          _loggedScheduleSkip = false;
        }
      }

      if (changed) {
        onLocalChange?.call();
      }
    } catch (error, stack) {
      debugPrint('Noty sync error: $error\n$stack');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _flushPendingResponses() async {
    final pending = await _cache.readPendingResponses();
    if (pending.isEmpty) {
      return;
    }

    final remaining = <PendingReminderResponse>[];
    for (final row in pending) {
      try {
        await _remote.respondToReminder(
          reminderId: row.reminderId,
          dueAt: row.dueAt,
          response: row.response,
        );
      } catch (_) {
        remaining.add(row);
      }
    }
    await _cache.writePendingResponses(remaining);
  }

  Future<List<Reminder>> readLocalReminders() => _cache.readReminders();

  Future<Reminder?> findReminder(String id) async {
    final reminders = await _cache.readReminders();
    for (final reminder in reminders) {
      if (reminder.id == id) {
        return reminder;
      }
    }
    return null;
  }

  Future<void> applyLocalResponse({
    required String reminderId,
    required DateTime dueAt,
    required String response,
  }) async {
    await _cache.enqueueResponse(
      PendingReminderResponse(
        reminderId: reminderId,
        dueAt: dueAt.toUtc(),
        response: response,
        respondedAt: DateTime.now().toUtc(),
      ),
    );

    final reminders = await _cache.readReminders();
    final updated = [
      for (final reminder in reminders)
        if (reminder.id == reminderId && reminder.singleUse)
          Reminder(
            id: reminder.id,
            name: reminder.name,
            description: reminder.description,
            hour: reminder.hour,
            minute: reminder.minute,
            timezone: reminder.timezone,
            startDate: reminder.startDate,
            createdAt: reminder.createdAt,
            everyDay: reminder.everyDay,
            monday: reminder.monday,
            tuesday: reminder.tuesday,
            wednesday: reminder.wednesday,
            thursday: reminder.thursday,
            friday: reminder.friday,
            saturday: reminder.saturday,
            sunday: reminder.sunday,
            runDays: reminder.runDays,
            singleUse: reminder.singleUse,
            isActive: false,
            devices: reminder.devices,
          )
        else
          reminder,
    ];
    await _cache.writeReminders(updated);

    await _scheduler.dismissActiveNotification(reminderId);
    final deviceId = await _registry.readDeviceId();
    if (deviceId != null) {
      await _scheduler.rescheduleAll(reminders: updated, deviceId: deviceId);
    }

    unawaited(_flushPendingResponses());
  }

  /// Cancela alarmas del SO y vacía la caché de este teléfono.
  Future<void> clearLocalState() async {
    _debounce?.cancel();
    await stopListening();
    while (_syncing) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _syncing = true;
    try {
      final reminders = await _cache.readReminders();
      for (final reminder in reminders) {
        try {
          await _scheduler.cancelReminder(reminder.id);
        } catch (error) {
          debugPrint('Noty cancel alarma ${reminder.id}: $error');
        }
      }
      await _scheduler.cancelAll();
      await _cache.clear();
      await _registry.clear();
    } finally {
      _syncing = false;
    }
  }

  bool _sameReminders(List<Reminder> a, List<Reminder> b) {
    if (a.length != b.length) {
      return false;
    }
    final aIds = a.map((r) => r.id).toSet();
    final bIds = b.map((r) => r.id).toSet();
    if (aIds.length != bIds.length || !aIds.containsAll(bIds)) {
      return false;
    }
    for (final left in a) {
      final right = b.firstWhere((r) => r.id == left.id);
      if (left.toMap().toString() != right.toMap().toString()) {
        return false;
      }
    }
    return true;
  }
}
