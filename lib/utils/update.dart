import 'dart:io' show Platform;

import 'package:PiliPlus/build_config.dart';
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:PiliPlus/utils/tv_platform.dart';
import 'package:PiliPlus/utils/update_asset.dart';
import 'package:PiliPlus/pages/setting/widgets/tv_update_dialog.dart';
import 'package:get/get.dart';

abstract final class Update {
  // 检查更新
  static Future<void> checkUpdate([bool isAuto = true]) async {
    if (kDebugMode) {
      if (!isAuto) SmartDialog.showToast('调试版本不支持覆盖更新，请使用正式安装包');
      return;
    }
    SmartDialog.dismiss();
    try {
      final res = await Request().get(
        Api.latestApp,
        options: Options(
          headers: {'user-agent': BrowserUa.mob},
          extra: {'account': const NoAccount()},
        ),
      );
      if (res.data is! List) {
        if (!isAuto) {
          SmartDialog.showToast('检查更新失败，GitHub接口未返回数据，请检查网络');
        }
        return;
      }
      final releases = (res.data as List).whereType<Map>().where(
        (release) => release['draft'] != true && release['prerelease'] != true,
      );
      if (releases.isEmpty) {
        if (!isAuto) SmartDialog.showToast('TV 更新渠道暂未发布正式版本');
        return;
      }
      final data = releases.first;
      final versionCode = UpdateAsset.versionCode(
        data['assets'] as List? ?? [],
      );
      final int latest =
          DateTime.parse(data['created_at']).millisecondsSinceEpoch ~/ 1000;
      final isCurrent = versionCode != null && BuildConfig.versionCode > 1
          ? BuildConfig.versionCode >= versionCode
          : BuildConfig.buildTime >= latest;
      if (isCurrent) {
        if (!isAuto) {
          SmartDialog.showToast('已是最新版本');
        }
      } else {
        Widget buildDialog(BuildContext context) {
          void dismiss() {
            if (TvPlatform.isTv) {
              Navigator.pop(context);
            } else {
              SmartDialog.dismiss();
            }
          }

          final colorScheme = ColorScheme.of(context);
          Widget downloadBtn(String text, {String? ext}) => TextButton(
            onPressed: () {
              if (TvPlatform.isTv) dismiss();
              onDownload(data, ext: ext);
            },
            child: Text(text),
          );
          return AlertDialog(
            title: const Text('🎉 发现新版本 '),
            content: SizedBox(
              height: 280,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data['tag_name']}',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Text('${data['body']}'),
                    TextButton(
                      onPressed: () => PageUtils.launchURL(
                        '${Constants.sourceCodeUrl}/commits/main',
                      ),
                      child: Text(
                        "点此查看完整更新(即commit)内容",
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (isAuto)
                TextButton(
                  onPressed: () {
                    dismiss();
                    GStorage.setting.put(SettingBoxKey.autoUpdate, false);
                  },
                  child: Text(
                    '不再提醒',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ),
              TextButton(
                onPressed: dismiss,
                child: Text(
                  '取消',
                  style: TextStyle(color: colorScheme.outline),
                ),
              ),
              if (Platform.isWindows) ...[
                downloadBtn('zip', ext: 'zip'),
                downloadBtn('exe', ext: 'exe'),
              ] else if (Platform.isLinux) ...[
                downloadBtn('rpm', ext: 'rpm'),
                downloadBtn('deb', ext: 'deb'),
                downloadBtn('targz', ext: 'tar.gz'),
              ] else
                downloadBtn(TvPlatform.isTv ? '下载更新' : 'Github'),
            ],
          );
        }

        if (TvPlatform.isTv) {
          await showDialog<void>(context: Get.context!, builder: buildDialog);
        } else {
          SmartDialog.show(
            animationType: SmartAnimationType.centerFade_otherSlide,
            builder: buildDialog,
          );
        }
      }
    } catch (e) {
      if (!isAuto) SmartDialog.showToast('检查更新失败，请检查网络后重试');
      if (kDebugMode) debugPrint('failed to check update: $e');
    }
  }

  // 下载适用于当前系统的安装包
  static Future<void> onDownload(Map data, {String? ext}) async {
    SmartDialog.dismiss();
    try {
      void download(String plat) {
        if (data['assets'].isNotEmpty) {
          for (Map<String, dynamic> i in data['assets']) {
            final String name = i['name'];
            if (name.contains(plat) &&
                (ext == null || ext.isEmpty ? true : name.endsWith(ext))) {
              PageUtils.launchURL(i['browser_download_url']);
              return;
            }
          }
          throw UnsupportedError('platform not found: $plat');
        }
      }

      if (Platform.isAndroid) {
        // 获取设备信息
        AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        if (TvPlatform.isTv) {
          final asset = UpdateAsset.selectApk(
            data['assets'] as List? ?? [],
            androidInfo.supportedAbis,
          );
          if (asset == null) {
            SmartDialog.showToast('此版本没有适合当前电视的安装包');
            return;
          }
          await showDialog<void>(
            context: Get.context!,
            builder: (_) => TvUpdateDialog(asset: asset),
          );
          return;
        }
        // [arm64-v8a]
        download(androidInfo.supportedAbis.first);
      } else {
        download(Platform.operatingSystem);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('download error: $e');
      if (TvPlatform.isTv) {
        SmartDialog.showToast('无法获取安装包，请稍后重试');
        return;
      }
      PageUtils.launchURL('${Constants.sourceCodeUrl}/releases/latest');
    }
  }
}
