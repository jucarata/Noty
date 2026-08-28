import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste el [install_id] de este teléfono. No es el id de hardware del SO.
class DeviceIdentityStore {
  DeviceIdentityStore({
    FlutterSecureStorage? storage,
    SharedPreferences? preferences,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _preferencesFuture = preferences != null
           ? Future.value(preferences)
           : SharedPreferences.getInstance();

  static const _installIdKey = 'noty.install_id';
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final FlutterSecureStorage _storage;
  final Future<SharedPreferences> _preferencesFuture;

  Future<String> getOrCreateInstallId() async {
    final existing = await _readInstallId();
    if (existing != null) {
      return existing;
    }

    final created = _newInstallId();
    await _writeInstallId(created);
    return created;
  }

  /// Genera un install_id nuevo. El QR anterior deja de valer en este teléfono.
  Future<String> rotateInstallId() async {
    final created = _newInstallId();
    await _writeInstallId(created);
    return created;
  }

  Future<String?> _readInstallId() async {
    final prefs = await _preferencesFuture;
    final fromPrefs = prefs.getString(_installIdKey);
    if (_isUuid(fromPrefs)) {
      return fromPrefs;
    }

    try {
      final fromSecure = await _storage.read(key: _installIdKey);
      if (_isUuid(fromSecure)) {
        await prefs.setString(_installIdKey, fromSecure!);
        return fromSecure;
      }
    } catch (error) {
      debugPrint('Noty install_id secure read: $error');
    }

    return null;
  }

  Future<void> _writeInstallId(String value) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_installIdKey, value);
    try {
      await _storage.write(key: _installIdKey, value: value);
    } catch (error) {
      debugPrint('Noty install_id secure write: $error');
    }
  }

  bool _isUuid(String? value) {
    return value != null && _uuid.hasMatch(value);
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
