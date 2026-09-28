import 'dart:io';

import 'package:flutter/services.dart';

/// Native capabilities shared by the TV screens. The define also enables TV
/// layout/input testing on desktop without changing saved phone preferences.
abstract final class TvPlatform {
  static const channel = MethodChannel('piliplus/tv');
  static bool isTv = const bool.fromEnvironment('PILIPLUS_TV');

  static Future<void> initialize() async {
    if (!Platform.isAndroid || isTv) return;
    try {
      isTv = await channel.invokeMethod<bool>('isTelevision') ?? false;
    } on PlatformException {
      // Older hosts can still use the regular mobile UI.
    } on MissingPluginException {
      // Desktop tests and engines without the Android activity.
    }
  }

  static Future<String?> recognizeSpeech() =>
      channel.invokeMethod<String>('recognizeSpeech');

  /// False means the user must grant installation access and retry.
  static Future<bool> installUpdate(String path) async =>
      await channel.invokeMethod<bool>('installUpdate', {'path': path}) ??
      false;
}
