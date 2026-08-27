import 'package:flutter/foundation.dart';
import 'package:noty/care/data/local/device_identity_store.dart';
import 'package:noty/care/models/device_share_code.dart';
import 'package:noty/core/network/backend_client.dart';

/// Fachada de vínculo entre dispositivos.
///
/// Las pantallas hablan solo con esta clase. No importan Supabase ni
/// [BackendClient].
class CareService {
  CareService({BackendClient? client, DeviceIdentityStore? identityStore})
    : _client = client ?? BackendClient.instance,
      _identityStore = identityStore ?? DeviceIdentityStore();

  final BackendClient _client;
  final DeviceIdentityStore _identityStore;

  /// Prepara el código de este teléfono: guarda el install_id, registra el
  /// dispositivo y devuelve lo que va en el QR.
  Future<DeviceShareCode> shareThisDevice() async {
    try {
      final installId = await _identityStore.getOrCreateInstallId();
      await _client.upsertOwnDevice(
        installId: installId,
        platform: _platform,
        deviceKind: 'phone',
      );
      return DeviceShareCode(installId: installId);
    } on BackendAuthException catch (error) {
      throw CareFailure(_copyFor(error));
    } catch (_) {
      throw const CareFailure(
        'No pudimos preparar el código. Intentémoslo de nuevo.',
      );
    }
  }

  String get _platform {
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  String _copyFor(BackendAuthException error) {
    if (error.code == 'missing_session') {
      return 'Para compartir este dispositivo, entra a la app.';
    }
    return 'No pudimos preparar el código. Intentémoslo de nuevo.';
  }
}
