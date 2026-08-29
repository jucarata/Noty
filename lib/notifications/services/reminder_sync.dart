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
      final deviceId = await ensureOwnDeviceId();
      var reminders = [
        for (final reminder in await _remote.fetchReminders())
          reminder.isEffectivelyActive
              ? reminder
              : reminder.copyWith(isActive: false),
      ];
      reminders = _mergePendingResponses(
        reminders,
        await _cache.readPendingResponses(),
      );
      reminders = await _ignoreOverdueOccurrences(
        reminders: reminders,
        deviceId: deviceId,
      );
      final changed = !_sameReminders(previous, reminders);
      await _cache.writeReminders(reminders);

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
    final deviceId = await _registry.readDeviceId();
    final reminders = await _cache.readReminders();
    Reminder? current;
    for (final reminder in reminders) {
      if (reminder.id == reminderId) {
        current = reminder;
        break;
      }
    }
    if (current?.responseAt(dueAt, deviceId: deviceId) != null) {
      await _scheduler.dismissActiveNotification(reminderId);
      return;
    }

    final dueUtc = dueAt.toUtc();
    final respondedAt = DateTime.now().toUtc();
    await _cache.enqueueResponse(
      PendingReminderResponse(
        reminderId: reminderId,
        dueAt: dueUtc,
        response: response,
        respondedAt: respondedAt,
      ),
    );

    final local = ReminderResponse(
      dueAt: dueUtc,
      response: response,
      respondedAt: respondedAt,
      deviceId: deviceId,
    );
    final updated = [
      for (final reminder in reminders)
        if (reminder.id == reminderId)
          reminder.copyWith(
            isActive: reminder.nextAtAfter(dueAt) == null ? false : null,
            responses: _upsertResponse(reminder.responses, local),
          )
        else
          reminder,
    ];
    await _cache.writeReminders(updated);

    await _scheduler.dismissActiveNotification(reminderId);
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

  List<Reminder> _mergePendingResponses(
    List<Reminder> reminders,
    List<PendingReminderResponse> pending,
  ) {
    if (pending.isEmpty) {
      return reminders;
    }

    return [
      for (final reminder in reminders)
        reminder.copyWith(
          responses: _applyPendingToResponses(reminder, pending),
        ),
    ];
  }

  List<ReminderResponse> _applyPendingToResponses(
    Reminder reminder,
    List<PendingReminderResponse> pending,
  ) {
    var responses = reminder.responses;
    for (final row in pending) {
      if (row.reminderId != reminder.id) {
        continue;
      }
      responses = _upsertResponse(
        responses,
        ReminderResponse(
          dueAt: row.dueAt,
          response: row.response,
          respondedAt: row.respondedAt,
        ),
      );
    }
    return responses;
  }

  Future<List<Reminder>> _ignoreOverdueOccurrences({
    required List<Reminder> reminders,
    required String? deviceId,
  }) async {
    if (deviceId == null) {
      return reminders;
    }

    var updated = reminders;
    var didIgnore = false;
    final now = DateTime.now();
    for (final reminder in reminders) {
      if (!reminder.shouldIgnoreLastDue(deviceId: deviceId, now: now)) {
        continue;
      }
      final due = reminder.lastDueAt(now);
      if (due == null) {
        continue;
      }
      didIgnore = true;
      final respondedAt = DateTime.now().toUtc();
      final local = ReminderResponse(
        dueAt: due.toUtc(),
        response: 'ignored',
        respondedAt: respondedAt,
        deviceId: deviceId,
      );
      await _cache.enqueueResponse(
        PendingReminderResponse(
          reminderId: reminder.id,
          dueAt: due.toUtc(),
          response: 'ignored',
          respondedAt: respondedAt,
        ),
      );
      updated = [
        for (final row in updated)
          if (row.id == reminder.id)
            row.copyWith(
              isActive: row.nextAtAfter(due) == null ? false : null,
              responses: _upsertResponse(row.responses, local),
            )
          else
            row,
      ];
    }

    if (didIgnore) {
      await _flushPendingResponses();
    }
    return updated;
  }

  List<ReminderResponse> _upsertResponse(
    List<ReminderResponse> current,
    ReminderResponse incoming,
  ) {
    for (final row in current) {
      final sameDevice = incoming.deviceId == null ||
          row.deviceId == null ||
          row.deviceId == incoming.deviceId;
      if (row.sameDue(incoming.dueAt) && sameDevice) {
        return current;
      }
    }
    return [...current, incoming];
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
