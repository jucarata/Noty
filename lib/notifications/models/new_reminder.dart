/// Datos de producto para crear un recordatorio. La UI no habla de tablas.
class NewReminder {
  const NewReminder({
    required this.name,
    required this.hour,
    required this.minute,
    required this.timezone,
    required this.startDate,
    required this.deviceIds,
    this.description,
    this.singleUse = false,
    this.everyDay = false,
    this.monday = false,
    this.tuesday = false,
    this.wednesday = false,
    this.thursday = false,
    this.friday = false,
    this.saturday = false,
    this.sunday = false,
    this.runDays,
  });

  final String name;
  final String? description;
  final int hour;
  final int minute;
  final String timezone;
  final DateTime startDate;
  final bool singleUse;
  final bool everyDay;
  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;
  final int? runDays;
  final List<String> deviceIds;
}

/// Fallo del módulo de recordatorios, con copy listo para mostrar.
class NotificatorFailure implements Exception {
  const NotificatorFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
