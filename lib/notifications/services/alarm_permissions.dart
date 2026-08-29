import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:noty/notifications/services/android_alarm_bridge.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permisos necesarios para que suenen las alarmas (Android).
class AlarmPermissions {
  AlarmPermissions({
    AndroidAlarmBridge? androidBridge,
    FlutterLocalNotificationsPlugin? notifications,
  }) : _androidBridge = androidBridge ?? AndroidAlarmBridge(),
       _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static final AlarmPermissions instance = AlarmPermissions();

  final AndroidAlarmBridge _androidBridge;
  final FlutterLocalNotificationsPlugin _notifications;

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin {
    return _notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();
  }

  /// Pasos que faltan, en el orden en que conviene pedirlos.
  Future<List<AlarmPermissionStep>> missingSteps() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const [];
    }
    final missing = <AlarmPermissionStep>[];
    if (!await Permission.notification.isGranted) {
      missing.add(AlarmPermissionStep.notifications);
    }
    if (!await Permission.scheduleExactAlarm.isGranted) {
      missing.add(AlarmPermissionStep.exactAlarms);
    }
    if (!await _fullScreenGranted()) {
      missing.add(AlarmPermissionStep.fullScreen);
    }
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      missing.add(AlarmPermissionStep.battery);
    }
    return missing;
  }

  Future<bool> get allGranted async => (await missingSteps()).isEmpty;

  Future<bool> _fullScreenGranted() async {
    return _androidBridge.canUseFullScreenIntent();
  }

  /// Pide el permiso del paso indicado. Devuelve si quedó concedido.
  Future<bool> requestStep(AlarmPermissionStep step) async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    switch (step) {
      case AlarmPermissionStep.notifications:
        return (await Permission.notification.request()).isGranted;
      case AlarmPermissionStep.exactAlarms:
        return (await Permission.scheduleExactAlarm.request()).isGranted;
      case AlarmPermissionStep.fullScreen:
        await _androidPlugin?.requestFullScreenIntentPermission();
        if (await _fullScreenGranted()) {
          return true;
        }
        await _androidBridge.openFullScreenIntentSettings();
        return false;
      case AlarmPermissionStep.battery:
        return (await Permission.ignoreBatteryOptimizations.request()).isGranted;
    }
  }
}

enum AlarmPermissionStep {
  notifications,
  exactAlarms,
  fullScreen,
  battery,
}

extension AlarmPermissionStepCopy on AlarmPermissionStep {
  String get title {
    return switch (this) {
      AlarmPermissionStep.notifications => 'Avisos en pantalla',
      AlarmPermissionStep.exactAlarms => 'Alarmas a la hora exacta',
      AlarmPermissionStep.fullScreen => 'Mostrar el recordatorio encima',
      AlarmPermissionStep.battery => 'Que suene siempre',
    };
  }

  String get body {
    return switch (this) {
      AlarmPermissionStep.notifications =>
        'Noty necesita enviarte avisos para recordarte tus tareas.',
      AlarmPermissionStep.exactAlarms =>
        'Así el recordatorio suena justo a la hora que elegiste.',
      AlarmPermissionStep.fullScreen =>
        'Para que puedas confirmar aunque estés viendo otra app, como YouTube.',
      AlarmPermissionStep.battery =>
        'Para que suene aunque no hayas abierto Noty en un rato.',
    };
  }

  String get actionLabel {
    return switch (this) {
      AlarmPermissionStep.fullScreen => 'Continuar',
      _ => 'Permitir',
    };
  }

  String? get hintAfterAction {
    return switch (this) {
      AlarmPermissionStep.fullScreen =>
        'Si aparece un interruptor, actívalo y vuelve con la flecha atrás.',
      _ => 'Cuando aparezca la ventana del teléfono, toca Permitir.',
    };
  }
}
