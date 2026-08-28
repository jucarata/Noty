/// Teléfono de un familiar acompañado, bajo el cuidado del host.
class LinkedDevice {
  const LinkedDevice({
    required this.id,
    required this.lastSeenAt,
    this.customName,
    this.brand,
    this.model,
  });

  final String id;
  final String? customName;
  final String? brand;
  final String? model;
  final DateTime lastSeenAt;

  factory LinkedDevice.fromMap(Map<String, dynamic> map) {
    return LinkedDevice(
      id: map['id'] as String,
      customName: _nullIfEmpty(map['custom_name'] as String?),
      brand: _nullIfEmpty(map['brand'] as String?),
      model: _nullIfEmpty(map['model'] as String?),
      lastSeenAt: _parseTimestamp(map['last_seen_at']),
    );
  }

  /// Nombre del familiar o de su teléfono.
  String get displayName {
    final name = customName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Familiar';
  }

  /// Marca y modelo del teléfono, listos para mostrar.
  String get brandModel {
    final brandName = brand?.trim();
    final modelName = model?.trim();
    final hasBrand = brandName != null && brandName.isNotEmpty;
    final hasModel = modelName != null && modelName.isNotEmpty;

    if (!hasBrand && !hasModel) {
      return 'Marca y modelo no disponibles';
    }
    if (!hasBrand) {
      return modelName!;
    }
    if (!hasModel) {
      return brandName;
    }
    if (modelName.toLowerCase().startsWith(brandName.toLowerCase())) {
      return modelName;
    }
    return '$brandName $modelName';
  }

  /// Descripción del teléfono del familiar.
  String get phoneDescription {
    final details = brandModel;
    if (details == 'Marca y modelo no disponibles') {
      return 'Teléfono sin datos de marca o modelo';
    }
    return 'Teléfono: $details';
  }

  /// Última vez que ese teléfono abrió Noty.
  String get lastSeenLabel {
    final local = lastSeenAt.toLocal();
    final now = DateTime.now();
    final time = _formatTime(local);
    final seenDay = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    final dayDiff = today.difference(seenDay).inDays;

    if (dayDiff == 0) {
      return 'Última conexión: hoy a las $time';
    }
    if (dayDiff == 1) {
      return 'Última conexión: ayer a las $time';
    }
    return 'Última conexión: ${_formatDate(local)} a las $time';
  }

  static String? _nullIfEmpty(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }

  static String _formatTime(DateTime local) {
    var hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'a. m.' : 'p. m.';
    hour = hour % 12;
    if (hour == 0) {
      hour = 12;
    }
    return '$hour:$minute $period';
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

  static String _formatDate(DateTime local) {
    final month = _months[local.month - 1];
    final now = DateTime.now();
    if (local.year == now.year) {
      return '${local.day} de $month';
    }
    return '${local.day} de $month de ${local.year}';
  }
}
