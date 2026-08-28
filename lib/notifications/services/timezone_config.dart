import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Configura la zona horaria local del dispositivo para programar alarmas.
Future<void> configureDeviceTimezone() async {
  tz_data.initializeTimeZones();
  try {
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
    debugPrint('Noty timezone: $name');
  } catch (error) {
    debugPrint('Noty timezone fallback UTC: $error');
    tz.setLocalLocation(tz.UTC);
  }
}

/// Convierte la hora de pared del recordatorio a [TZDateTime] en su zona IANA.
tz.TZDateTime reminderWallClockToZoned(ReminderTime time) {
  try {
    final location = tz.getLocation(time.timezone);
    return tz.TZDateTime(
      location,
      time.year,
      time.month,
      time.day,
      time.hour,
      time.minute,
    );
  } catch (_) {
    return tz.TZDateTime(
      tz.local,
      time.year,
      time.month,
      time.day,
      time.hour,
      time.minute,
    );
  }
}

/// Hora de pared de una ocurrencia (sin offset del SO).
class ReminderTime {
  const ReminderTime({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.timezone,
  });

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final String timezone;

  factory ReminderTime.fromDateTime(DateTime dueAt, String timezone) {
    return ReminderTime(
      year: dueAt.year,
      month: dueAt.month,
      day: dueAt.day,
      hour: dueAt.hour,
      minute: dueAt.minute,
      timezone: timezone,
    );
  }
}
