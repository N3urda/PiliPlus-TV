import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';

/// The TV fork launches into the ten-foot interface by default.
/// Set PILIPLUS_TV=false only when comparing upstream mobile behavior.
abstract final class TvMode {
  static const enabled = bool.fromEnvironment(
    'PILIPLUS_TV',
    defaultValue: true,
  );

  static final Future<bool> isEmulator = _detectEmulator();

  static Future<bool> _detectEmulator() async {
    if (!enabled || !Platform.isAndroid) return false;
    try {
      return !(await DeviceInfoPlugin().androidInfo).isPhysicalDevice;
    } catch (_) {
      return false;
    }
  }
}
