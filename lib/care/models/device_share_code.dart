import 'dart:convert';

/// Código que este dispositivo muestra para que otra persona lo escanee.
class DeviceShareCode {
  const DeviceShareCode({required this.installId});

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final String installId;

  /// Payload del QR. El padre usará [installId] en `link_device_to_family`.
  String get qrPayload =>
      jsonEncode({'v': 1, 'kind': 'share_device', 'install_id': installId});

  /// Lee el [installId] de un QR de Noty. Null si el contenido no es válido.
  static DeviceShareCode? tryParse(String payload) {
    final trimmed = payload.trim();
    if (_uuid.hasMatch(trimmed)) {
      return DeviceShareCode(installId: trimmed);
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return null;
      }
      if (decoded['kind'] != 'share_device') {
        return null;
      }
      final installId = decoded['install_id'];
      if (installId is! String || !_uuid.hasMatch(installId)) {
        return null;
      }
      return DeviceShareCode(installId: installId);
    } on FormatException {
      return null;
    }
  }
}

/// Fallo de cuidado/vínculo con copy listo para mostrar.
class CareFailure implements Exception {
  const CareFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
