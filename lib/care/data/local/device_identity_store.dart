import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persiste el [install_id] de este teléfono. No es el id de hardware del SO.
class DeviceIdentityStore {
  DeviceIdentityStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _installIdKey = 'noty.install_id';

  final FlutterSecureStorage _storage;

  Future<String> getOrCreateInstallId() async {
    final existing = await _storage.read(key: _installIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = _newInstallId();
    await _storage.write(key: _installIdKey, value: created);
    return created;
  }

  String _newInstallId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
