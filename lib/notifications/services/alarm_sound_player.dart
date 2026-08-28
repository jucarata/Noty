import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reproduce el sonido de alarma del sistema en loop hasta [stop].
class AlarmSoundPlayer {
  AlarmSoundPlayer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.noty.noty/alarm_sound');

  final MethodChannel _channel;
  var _playing = false;

  Future<void> start() async {
    if (_playing) {
      return;
    }
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    _playing = true;

    try {
      await _channel.invokeMethod<void>('playAlarm');
    } catch (error) {
      _playing = false;
      debugPrint('Noty sonido alarma falló: $error');
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_playing) {
      return;
    }
    _playing = false;
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('stopAlarm');
    } catch (error) {
      debugPrint('Noty detener alarma: $error');
    }
  }

  Future<void> dispose() async {
    await stop();
  }
}

/// Payload que viaja en la notificación de alarma.
class AlarmPayload {
  const AlarmPayload({
    required this.reminderId,
    required this.dueAt,
  });

  final String reminderId;
  final DateTime dueAt;

  String encode() => jsonEncode({
    'reminder_id': reminderId,
    'due_at': dueAt.toUtc().toIso8601String(),
  });

  static AlarmPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) {
        return null;
      }
      final reminderId = map['reminder_id'];
      final dueAt = map['due_at'];
      if (reminderId is! String || dueAt is! String) {
        return null;
      }
      final parsed = DateTime.tryParse(dueAt);
      if (parsed == null) {
        return null;
      }
      return AlarmPayload(reminderId: reminderId, dueAt: parsed.toUtc());
    } catch (_) {
      return null;
    }
  }
}
