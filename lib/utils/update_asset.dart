abstract final class UpdateAsset {
  /// Release builds include the Android version code in the APK filename.
  /// Unlike publication time, it does not mark the installed release as newer
  /// just because GitHub published it a few minutes after the build finished.
  static int? versionCode(List<dynamic> assets) {
    for (final asset in assets.whereType<Map>()) {
      final name = asset['name'];
      if (name is! String || !name.endsWith('.apk')) continue;
      final match = RegExp(r'\+(\d+)(?:_|\.apk$)').firstMatch(name);
      if (match != null) return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static Map<String, dynamic>? selectApk(
    List<dynamic> assets,
    List<String> abis,
  ) {
    final apks = assets
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .where(
          (e) => e['name'] is String && (e['name'] as String).endsWith('.apk'),
        )
        .toList();
    for (final abi in abis) {
      for (final asset in apks) {
        if ((asset['name'] as String).contains(abi)) return asset;
      }
    }
    for (final asset in apks) {
      final name = asset['name'] as String;
      if (name.contains('universal') || name == 'app-release.apk') return asset;
    }
    return null;
  }
}
