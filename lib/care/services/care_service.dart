import 'package:flutter/foundation.dart';
import 'package:noty/care/data/local/device_hardware_reader.dart';
import 'package:noty/care/data/local/device_identity_store.dart';
import 'package:noty/care/models/device_share_code.dart';
import 'package:noty/care/models/linked_device.dart';
import 'package:noty/core/network/backend_client.dart';

/// Fachada de vínculo entre dispositivos.
///
/// Las pantallas hablan solo con esta clase. No importan Supabase ni
/// [BackendClient].
class CareService {
  CareService({
    BackendClient? client,
    DeviceIdentityStore? identityStore,
    DeviceHardwareReader? hardwareReader,
  }) : _client = client ?? BackendClient.instance,
       _identityStore = identityStore ?? DeviceIdentityStore(),
       _hardwareReader = hardwareReader ?? DeviceHardwareReader();

  final BackendClient _client;
  final DeviceIdentityStore _identityStore;
  final DeviceHardwareReader _hardwareReader;

  /// Prepara el código de este teléfono: guarda el install_id, registra el
  /// dispositivo y devuelve lo que va en el QR.
  Future<DeviceShareCode> shareThisDevice() async {
    final registered = await registerThisDevice();
    return DeviceShareCode(installId: registered.installId);
  }

  /// Registra este install en la nube.
  ///
  /// Si el install ya pertenece a otra cuenta, genera uno nuevo y reintenta.
  Future<({String installId, String deviceId})> registerThisDevice() async {
    try {
      return await _register(allowRotate: true);
    } on CareFailure {
      rethrow;
    } on BackendAuthException catch (error) {
      debugPrint(
        'Noty register device: code=${error.code} message=${error.message}',
      );
      throw CareFailure(_copyFor(error));
    } catch (error, stack) {
      debugPrint('Noty register device: $error\n$stack');
      throw const CareFailure(
        'No pudimos preparar el código. Intentémoslo de nuevo.',
      );
    }
  }

  Future<({String installId, String deviceId})> _register({
    required bool allowRotate,
  }) async {
    final installId = await _identityStore.getOrCreateInstallId();
    final hardware = await _hardwareReader.read();
    try {
      final deviceId = await _client.upsertOwnDevice(
        installId: installId,
        platform: hardware.platform,
        deviceKind: hardware.deviceKind,
        brand: hardware.brand,
        model: hardware.model,
        osVersion: hardware.osVersion,
        customName: hardware.defaultCustomName,
      );
      return (installId: installId, deviceId: deviceId);
    } on BackendAuthException catch (error) {
      if (allowRotate && error.code == 'device_taken') {
        debugPrint('Noty register device: install_id ocupado, se genera otro');
        await _identityStore.rotateInstallId();
        return _register(allowRotate: false);
      }
      rethrow;
    }
  }

  /// Lee el QR de otro teléfono y lo une a la familia de quien escanea.
  Future<void> addDeviceFromSharePayload(String payload) async {
    final code = DeviceShareCode.tryParse(payload);
    if (code == null) {
      throw const CareFailure(
        'Ese código no es de Noty. Pide que vuelva a mostrarlo.',
      );
    }

    try {
      final ownId = await _identityStore.getOrCreateInstallId();
      if (code.installId.toLowerCase() == ownId.toLowerCase()) {
        throw const CareFailure(
          'Ese es este mismo teléfono. Pide el código del otro dispositivo.',
        );
      }

      await _client.linkDeviceToFamily(installId: code.installId);
    } on CareFailure {
      rethrow;
    } on BackendAuthException catch (error) {
      throw CareFailure(_copyForAdd(error));
    } catch (_) {
      throw const CareFailure(
        'No pudimos vincular el dispositivo. Intentémoslo de nuevo.',
      );
    }
  }

  /// Familiares acompañados de los grupos donde esta cuenta es host.
  Future<List<LinkedDevice>> listFamilyMembers() async {
    try {
      final rows = await _client.fetchFamilyMembers();
      return [
        for (final row in rows)
          if (row['id'] is String) LinkedDevice.fromMap(row),
      ];
    } on BackendAuthException catch (error) {
      throw CareFailure(_copyForList(error));
    } catch (_) {
      throw const CareFailure(
        'No pudimos cargar tu familia. Intentémoslo de nuevo.',
      );
    }
  }

  String _copyFor(BackendAuthException error) {
    if (error.code == 'missing_session') {
      return 'Para compartir el código de vinculación, entra a la app.';
    }
    return 'No pudimos preparar el código. Intentémoslo de nuevo.';
  }

  String _copyForAdd(BackendAuthException error) {
    if (error.code == 'missing_session' ||
        error.code == 'anonymous_not_allowed') {
      return 'Para añadir un miembro familiar, entra o crea una cuenta.';
    }

    final message = error.message.trim();
    if (message.contains('No encontramos ese dispositivo')) {
      return 'No encontramos ese dispositivo. Pide que vuelva a mostrar el código.';
    }
    if (message.contains('Inicia sesión') || message.contains('Debes entrar')) {
      return 'Para añadir un miembro familiar, entra o crea una cuenta.';
    }
    if (message.contains('No puedes vincular')) {
      return 'No pudimos vincular este dispositivo a tu grupo familiar.';
    }
    if (message.contains('invalid input syntax')) {
      return 'Ese código no es de Noty. Pide que vuelva a mostrarlo.';
    }

    return 'No pudimos vincular el dispositivo. Intentémoslo de nuevo.';
  }

  String _copyForList(BackendAuthException error) {
    if (error.code == 'missing_session' ||
        error.code == 'anonymous_not_allowed') {
      return 'Para ver tu familia, entra o crea una cuenta.';
    }
    return 'No pudimos cargar tu familia. Intentémoslo de nuevo.';
  }
}
