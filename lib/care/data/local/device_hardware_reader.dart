import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Datos de hardware de este install.
class DeviceHardwareInfo {
  const DeviceHardwareInfo({
    required this.platform,
    required this.deviceKind,
    this.brand,
    this.model,
    this.osVersion,
  });

  /// `android` o `ios` (restricción de la tabla `devices`).
  final String platform;
  final String deviceKind;
  final String? brand;
  final String? model;
  final String? osVersion;

  /// Nombre visible provisional: marca + modelo.
  String? get defaultCustomName {
    final brandName = brand;
    final modelName = model;
    if (brandName == null || brandName.isEmpty) {
      return modelName;
    }
    if (modelName == null || modelName.isEmpty) {
      return brandName;
    }
    if (modelName.toLowerCase().startsWith(brandName.toLowerCase())) {
      return modelName;
    }
    return '$brandName $modelName';
  }
}

/// Lee marca, modelo, tipo y versión del SO para registrar el dispositivo.
class DeviceHardwareReader {
  DeviceHardwareReader({DeviceInfoPlugin? plugin})
    : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  Future<DeviceHardwareInfo> read() async {
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    final kindFromScreen = _kindFromScreen();

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _plugin.iosInfo;
        final isPad =
            _looksLikeIpad(info.model) ||
            _looksLikeIpad(info.modelName) ||
            _looksLikeIpad(info.localizedModel);
        return DeviceHardwareInfo(
          platform: 'ios',
          deviceKind: isPad ? 'tablet' : kindFromScreen,
          brand: 'Apple',
          model: _clean(info.modelName) ??
              _clean(info.localizedModel) ??
              _clean(info.model),
          osVersion: _clean(info.systemVersion),
        );
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await _plugin.androidInfo;
        return DeviceHardwareInfo(
          platform: 'android',
          deviceKind: kindFromScreen,
          brand: _prettyBrand(
            _clean(info.manufacturer) ?? _clean(info.brand),
          ),
          model: _clean(info.model),
          osVersion: _clean(info.version.release),
        );
      }

      return DeviceHardwareInfo(
        platform: platform,
        deviceKind: kindFromScreen,
      );
    } catch (_) {
      return DeviceHardwareInfo(
        platform: platform,
        deviceKind: kindFromScreen,
      );
    }
  }

  String _kindFromScreen() {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) {
      return 'phone';
    }
    final shortestSide = MediaQueryData.fromView(views.first).size.shortestSide;
    return shortestSide >= 600 ? 'tablet' : 'phone';
  }

  bool _looksLikeIpad(String value) {
    return value.toLowerCase().contains('ipad');
  }

  String? _clean(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    if (text.toLowerCase() == 'unknown') {
      return null;
    }
    return text;
  }

  String? _prettyBrand(String? value) {
    if (value == null) {
      return null;
    }
    if (value == value.toUpperCase() || value == value.toLowerCase()) {
      return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
    }
    return value;
  }
}
