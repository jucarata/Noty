import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:noty/notifications/services/alarm_sound_player.dart';

/// Puente a AlarmManager nativo (Android). Más fiable en Oppo/ColorOS.
class AndroidAlarmBridge {
  AndroidAlarmBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.noty.noty/alarm_sound');

  final MethodChannel _channel;

  Future<void> schedule({
    required int notificationId,
    required DateTime triggerAt,
    required String title,
    required String body,
    required AlarmPayload payload,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('scheduleNativeAlarm', {
      'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
      'notificationId': notificationId,
      'payload': payload.encode(),
      'title': title,
      'body': body,
    });
  }

  Future<void> cancel({required int notificationId}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('cancelNativeAlarm', {
      'notificationId': notificationId,
    });
  }

  Future<AlarmPayload?> consumeLaunchPayload() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }
    final raw = await _channel.invokeMethod<String>('getPendingAlarmPayload');
    return AlarmPayload.decode(raw);
  }

  Future<bool> canUseFullScreenIntent() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }
    final allowed = await _channel.invokeMethod<bool>('canUseFullScreenIntent');
    return allowed ?? true;
  }

  Future<void> openFullScreenIntentSettings() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('openFullScreenIntentSettings');
  }

  void bindLaunchHandler(void Function(AlarmPayload payload) handler) {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'alarmLaunched') {
        final payload = AlarmPayload.decode(call.arguments as String?);
        if (payload != null) {
          handler(payload);
        }
      }
    });
  }
}
