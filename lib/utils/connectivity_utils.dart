import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

abstract final class ConnectivityUtils {
  static bool usesBroadbandPreferences(List<ConnectivityResult> connections) =>
      connections.contains(ConnectivityResult.wifi) ||
      connections.contains(ConnectivityResult.ethernet);

  /// Wi-Fi and Ethernet share the broadband video/audio quality preferences.
  static Future<bool> get isBroadband async {
    if (PlatformUtils.isDesktop) return true;
    try {
      return usesBroadbandPreferences(await Connectivity().checkConnectivity());
    } catch (_) {
      return true;
    }
  }

  static Future<bool> get isWiFi async {
    try {
      return PlatformUtils.isMobile &&
          (await Connectivity().checkConnectivity()).contains(
            ConnectivityResult.wifi,
          );
    } catch (_) {
      return true;
    }
  }
}
