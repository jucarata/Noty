import 'dart:convert';

/// Código que este dispositivo muestra para que otra persona lo escanee.
class DeviceShareCode {
  const DeviceShareCode({required this.installId});

  final String installId;

  /// Payload del QR. El padre usará [installId] en `link_device_to_family`.
  String get qrPayload => jsonEncode({
    'v': 1,
    'kind': 'share_device',
    'install_id': installId,
  });
}

/// Fallo de cuidado/vínculo con copy listo para mostrar.
class CareFailure implements Exception {
  const CareFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
