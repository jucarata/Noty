import 'package:shared_preferences/shared_preferences.dart';

/// Guarda el devices.id de este teléfono (resuelto desde install_id).
class DeviceRegistry {
  DeviceRegistry({SharedPreferences? preferences})
    : _preferencesFuture = preferences != null
          ? Future.value(preferences)
          : SharedPreferences.getInstance();

  static const _deviceIdKey = 'noty.device.server_id';

  final Future<SharedPreferences> _preferencesFuture;

  Future<String?> readDeviceId() async {
    final prefs = await _preferencesFuture;
    return prefs.getString(_deviceIdKey);
  }

  Future<void> writeDeviceId(String deviceId) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_deviceIdKey, deviceId);
  }

  Future<void> clear() async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_deviceIdKey);
  }
}
