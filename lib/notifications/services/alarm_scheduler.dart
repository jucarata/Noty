import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:noty/notifications/models/reminder.dart';
import 'package:noty/notifications/services/alarm_sound_player.dart';
import 'package:noty/notifications/services/android_alarm_bridge.dart';
import 'package:noty/notifications/services/timezone_config.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

typedef AlarmTapHandler = void Function(AlarmPayload payload);

/// Resultado de reprogramar alarmas (útil para depurar).
class AlarmScheduleReport {
  const AlarmScheduleReport({
    this.scheduled = 0,
    this.skipped = 0,
    this.failed = 0,
    this.lastError,
  });

  final int scheduled;
  final int skipped;
  final int failed;
  final String? lastError;

  bool get hasScheduled => scheduled > 0;
}

/// Programa y cancela alarmas del sistema operativo.
class AlarmScheduler {
  AlarmScheduler({
    FlutterLocalNotificationsPlugin? notifications,
    AndroidAlarmBridge? androidBridge,
    SharedPreferences? preferences,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _androidBridge = androidBridge ?? AndroidAlarmBridge(),
       _preferencesFuture = preferences != null
           ? Future.value(preferences)
           : SharedPreferences.getInstance();

  static const _channelId = 'noty_alarms_v2';
  static const _channelName = 'Recordatorios Noty';
  static const _channelDescription =
      'Alarmas de recordatorios que requieren confirmación';
  static const _scheduledIdsKey = 'noty.alarms.scheduled_ids';

  final FlutterLocalNotificationsPlugin _notifications;
  final AndroidAlarmBridge _androidBridge;
  final Future<SharedPreferences> _preferencesFuture;
  var _initialized = false;
  AlarmTapHandler? _onAlarmTap;

  Future<void> initialize({required AlarmTapHandler onAlarmTap}) async {
    if (_initialized) {
      _onAlarmTap = onAlarmTap;
      return;
    }

    _onAlarmTap = onAlarmTap;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _backgroundNotificationResponse,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    _initialized = true;

    if (!kIsWeb && Platform.isAndroid) {
      // Android usa AlarmManager nativo; evitar doble apertura con flutter_local_notifications.
      _androidBridge.bindLaunchHandler((payload) {
        _onAlarmTap?.call(payload);
      });
      return;
    }

    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (response != null) {
      _handleNotificationResponse(response);
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = AlarmPayload.decode(response.payload);
    if (payload != null) {
      _onAlarmTap?.call(payload);
    }
  }

  Future<AlarmScheduleReport> rescheduleAll({
    required List<Reminder> reminders,
    required String deviceId,
  }) async {
    if (!_initialized) {
      debugPrint('Noty alarmas: scheduler no inicializado');
      return const AlarmScheduleReport(skipped: 1, lastError: 'no_init');
    }

    var scheduled = 0;
    var skipped = 0;
    var failed = 0;
    String? lastError;
    final activeIds = <int>{};

    for (final reminder in reminders) {
      if (!reminder.isActive || !reminder.ringsOnDevice(deviceId)) {
        skipped++;
        continue;
      }
      final next = reminder.nextAt;
      if (next == null) {
        skipped++;
        continue;
      }
      final notificationId = _notificationIdFor(reminder.id);
      activeIds.add(notificationId);
      try {
        await _scheduleReminder(
          reminder: reminder,
          dueAt: next,
          notificationId: notificationId,
        );
        scheduled++;
        debugPrint(
          'Noty alarma programada: ${reminder.name} a las $next (id=${reminder.id})',
        );
      } catch (error) {
        failed++;
        lastError = error.toString();
        debugPrint(
          'Noty alarma falló: ${reminder.name} a las $next → $error',
        );
      }
    }

    await _cancelStaleNotifications(activeIds);

    if (kDebugMode && (scheduled > 0 || failed > 0)) {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint(
        'Noty alarmas: programadas=$scheduled omitidas=$skipped '
        'fallidas=$failed pendientes=${pending.length}',
      );
    }

    return AlarmScheduleReport(
      scheduled: scheduled,
      skipped: skipped,
      failed: failed,
      lastError: lastError,
    );
  }

  Future<void> cancelReminder(String reminderId) async {
    final notificationId = _notificationIdFor(reminderId);
    await _notifications.cancel(notificationId);
    await _androidBridge.cancel(notificationId: notificationId);
    final ids = await _readScheduledIds();
    if (ids.remove(notificationId)) {
      await _writeScheduledIds(ids);
    }
  }

  Future<void> cancelAll() async {
    final ids = await _readScheduledIds();
    if (!kIsWeb && Platform.isAndroid) {
      await _androidBridge.cancelAll(notificationIds: ids.toList());
    } else {
      for (final id in ids) {
        await _notifications.cancel(id);
      }
    }
    await _notifications.cancelAll();
    await _writeScheduledIds({});
  }

  Future<void> dismissActiveNotification(String reminderId) async {
    await _notifications.cancel(_notificationIdFor(reminderId));
  }

  Future<int> pendingCount() async {
    if (!kIsWeb && Platform.isAndroid) {
      return 0;
    }
    final pending = await _notifications.pendingNotificationRequests();
    return pending.length;
  }

  Future<void> _scheduleReminder({
    required Reminder reminder,
    required DateTime dueAt,
    required int notificationId,
  }) async {
    final wall = ReminderTime.fromDateTime(dueAt, reminder.timezone);
    final scheduled = reminderWallClockToZoned(wall);
    final now = tz.TZDateTime.now(scheduled.location);

    if (!scheduled.isAfter(now)) {
      throw StateError(
        'La hora ya pasó ($scheduled). Crea el recordatorio con más anticipación.',
      );
    }

    final alarmPayload = AlarmPayload(
      reminderId: reminder.id,
      dueAt: dueAt.toUtc(),
    );
    final payload = alarmPayload.encode();
    final body = reminder.description ?? 'Es hora de tu recordatorio';

    if (!kIsWeb && Platform.isAndroid) {
      await _androidBridge.schedule(
        notificationId: notificationId,
        triggerAt: dueAt.toLocal(),
        title: reminder.name,
        body: body,
        payload: alarmPayload,
      );
      return;
    }

    final canExact = defaultTargetPlatform != TargetPlatform.android ||
        await Permission.scheduleExactAlarm.isGranted;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
        autoCancel: true,
        ticker: reminder.name,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    await _notifications.zonedSchedule(
      notificationId,
      reminder.name,
      body,
      scheduled,
      details,
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: null,
    );
  }

  Future<void> _cancelStaleNotifications(Set<int> activeIds) async {
    final previous = await _readScheduledIds();
    for (final id in previous) {
      if (!activeIds.contains(id)) {
        await _notifications.cancel(id);
        await _androidBridge.cancel(notificationId: id);
      }
    }
    if (kIsWeb || Platform.isAndroid) {
      await _writeScheduledIds(activeIds);
      return;
    }
    final pending = await _notifications.pendingNotificationRequests();
    for (final request in pending) {
      if (!activeIds.contains(request.id)) {
        await _notifications.cancel(request.id);
      }
    }
    await _writeScheduledIds(activeIds);
  }

  Future<Set<int>> _readScheduledIds() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getStringList(_scheduledIdsKey) ?? const [];
    return {
      for (final value in raw)
        if (int.tryParse(value) != null) int.parse(value),
    };
  }

  Future<void> _writeScheduledIds(Set<int> ids) async {
    final prefs = await _preferencesFuture;
    await prefs.setStringList(_scheduledIdsKey, [
      for (final id in ids) id.toString(),
    ]);
  }

  /// Alarma lanzada por el receptor nativo antes de que Flutter esté listo.
  Future<AlarmPayload?> consumeNativeLaunchPayload() {
    return _androidBridge.consumeLaunchPayload();
  }

  int _notificationIdFor(String reminderId) {
    return reminderId.hashCode & 0x7fffffff;
  }
}

@pragma('vm:entry-point')
void _backgroundNotificationResponse(NotificationResponse response) {
  // La UI viva se abre al volver al foreground; el payload se lee en init.
}
