/// Recordatorio listo para mostrar. La UI no habla de tablas.
class Reminder {
  const Reminder({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    required this.timezone,
    required this.startDate,
    required this.createdAt,
    required this.devices,
    required this.everyDay,
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    required this.singleUse,
    required this.isActive,
    this.description,
    this.runDays,
  });

  final String id;
  final String name;
  final String? description;
  final int hour;
  final int minute;
  final String timezone;
  final DateTime startDate;
  final DateTime createdAt;
  final bool everyDay;
  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;
  final int? runDays;
  final bool singleUse;
  final bool isActive;
  final List<ReminderDevice> devices;

  factory Reminder.fromMap(Map<String, dynamic> map) {
    final time = _parseTime(map['time_local']);
    return Reminder(
      id: map['id'] as String,
      name: (map['name'] as String?)?.trim() ?? 'Recordatorio',
      description: _nullIfEmpty(map['description'] as String?),
      hour: time.$1,
      minute: time.$2,
      timezone: (map['timezone'] as String?)?.trim() ?? 'America/Bogota',
      startDate: _parseDate(map['start_date']),
      createdAt: _parseTimestamp(map['created_at']),
      everyDay: map['every_day'] == true,
      monday: map['monday'] == true,
      tuesday: map['tuesday'] == true,
      wednesday: map['wednesday'] == true,
      thursday: map['thursday'] == true,
      friday: map['friday'] == true,
      saturday: map['saturday'] == true,
      sunday: map['sunday'] == true,
      runDays: _parseInt(map['run_days']),
      singleUse: map['single_use'] == true,
      isActive: map['is_active'] != false,
      devices: _parseDevices(map['reminder_devices']),
    );
  }

  /// Hora visible. Ej. A las 8:00 a. m.
  String get timeLabel => 'A las ${_formatTime(hour, minute)}';

  /// Día del próximo aviso: Hoy, Mañana o la fecha.
  String get nextDayLabel {
    final next = nextAt;
    if (next == null) {
      return 'Ya no hay más avisos';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(next.year, next.month, next.day);
    final month = _months[day.month - 1];

    if (day == today) {
      return 'Hoy';
    }
    if (day == today.add(const Duration(days: 1))) {
      return 'Mañana';
    }
    if (day.year == now.year) {
      return '${day.day} de $month';
    }
    return '${day.day} de $month de ${day.year}';
  }

  /// Familiares / teléfonos donde suena.
  String get deviceLabel {
    final names = [for (final device in devices) device.displayName];
    if (names.isEmpty) {
      return 'Sin familiar asignado';
    }
    if (names.length == 1) {
      return 'Para ${names.first}';
    }
    if (names.length == 2) {
      return 'Para ${names[0]} y ${names[1]}';
    }
    final head = names.sublist(0, names.length - 1).join(', ');
    return 'Para $head y ${names.last}';
  }

  /// Próximo instante de alarma en la hora local del teléfono, o null.
  DateTime? get nextAt {
    if (!isActive) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    var cursor = today.isBefore(start) ? start : today;

    for (var i = 0; i < 800; i++) {
      if (_hasAlarmOn(cursor)) {
        if (cursor == today) {
          final ring = DateTime(
            cursor.year,
            cursor.month,
            cursor.day,
            hour,
            minute,
          );
          if (!ring.isAfter(now)) {
            cursor = cursor.add(const Duration(days: 1));
            continue;
          }
        }
        return DateTime(cursor.year, cursor.month, cursor.day, hour, minute);
      }
      if (runDays != null && _alarmCountThrough(cursor) >= runDays!) {
        break;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
  }

  bool _hasAlarmOn(DateTime day) {
    if (!_isAlarmDay(day)) {
      return false;
    }
    if (runDays == null) {
      return true;
    }
    return _alarmCountThrough(day) <= runDays!;
  }

  bool _isAlarmDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (d.isBefore(start)) {
      return false;
    }
    if (singleUse) {
      return d == start;
    }
    if (everyDay) {
      return true;
    }
    return switch (d.weekday) {
      DateTime.monday => monday,
      DateTime.tuesday => tuesday,
      DateTime.wednesday => wednesday,
      DateTime.thursday => thursday,
      DateTime.friday => friday,
      DateTime.saturday => saturday,
      DateTime.sunday => sunday,
      _ => false,
    };
  }

  int _alarmCountThrough(DateTime inclusive) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(inclusive.year, inclusive.month, inclusive.day);
    if (end.isBefore(start)) {
      return 0;
    }
    var count = 0;
    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (_isAlarmDay(cursor)) {
        count++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  static String _formatTime(int hour, int minute) {
    var displayHour = hour % 12;
    if (displayHour == 0) {
      displayHour = 12;
    }
    final padded = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'a. m.' : 'p. m.';
    return '$displayHour:$padded $period';
  }

  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static (int, int) _parseTime(dynamic value) {
    if (value is String) {
      final parts = value.split(':');
      if (parts.length >= 2) {
        return (int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
      }
    }
    return (0, 0);
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) {
      final parts = value.split('-');
      if (parts.length >= 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }

  static String? _nullIfEmpty(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static List<ReminderDevice> _parseDevices(dynamic value) {
    if (value is! List) {
      return const [];
    }
    final devices = <ReminderDevice>[];
    for (final row in value) {
      if (row is! Map) {
        continue;
      }
      final nested = row['devices'];
      final map = nested is Map ? Map<String, dynamic>.from(nested) : null;
      final id = map?['id'] as String? ?? row['device_id'] as String?;
      if (id == null || id.isEmpty) {
        continue;
      }
      devices.add(
        ReminderDevice(
          id: id,
          customName: _nullIfEmpty(map?['custom_name'] as String?),
        ),
      );
    }
    return devices;
  }
}

/// Teléfono / familiar al que se asignó el recordatorio.
class ReminderDevice {
  const ReminderDevice({required this.id, this.customName});

  final String id;
  final String? customName;

  String get displayName {
    final name = customName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Familiar';
  }
}
