import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/update.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class TvSettingsPage extends StatefulWidget {
  const TvSettingsPage({super.key});

  @override
  State<TvSettingsPage> createState() => _TvSettingsPageState();
}

class _TvSettingsPageState extends State<TvSettingsPage> {
  Widget _toggle(String title, String key, bool value) => SwitchListTile(
    title: Text(title),
    value: value,
    onChanged: (value) async {
      await GStorage.setting.put(key, value);
      if (mounted) setState(() {});
    },
  );

  @override
  Widget build(BuildContext context) => SimpleScaffold(
    appBar: AppBar(title: const Text('电视设置')),
    body: Center(
      child: SizedBox(
        width: 720,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              '遥控器操作',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '浏览：方向键选择，确认键打开，返回键回到上一个页面。\n'
              '全屏播放：确认键播放 / 暂停，左右快进，上下或菜单键打开播放菜单。\n'
              '返回：先收起播放菜单，再退出全屏，最后返回列表。',
            ),
            const SizedBox(height: 16),
            _toggle(
              '打开视频时播放',
              SettingBoxKey.autoPlayEnable,
              Pref.autoPlayEnable,
            ),
            _toggle(
              '播放时自动全屏',
              SettingBoxKey.enableAutoEnter,
              Pref.autoEnterFullScreen,
            ),
            _toggle(
              '播放结束后退出全屏',
              SettingBoxKey.enableAutoExit,
              Pref.autoExitFullscreen,
            ),
            _toggle(
              '默认显示弹幕',
              SettingBoxKey.enableShowDanmaku,
              Pref.enableShowDanmaku,
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('播放偏好在下次打开视频时生效。'),
            ),
            ListTile(
              title: const Text('检查电视版更新'),
              subtitle: const Text('下载与当前设备匹配的安装包'),
              leading: const Icon(Icons.system_update),
              onTap: () => Update.checkUpdate(false),
            ),
            ListTile(
              title: const Text('更多设置'),
              subtitle: const Text('画质、解码、字幕、账号、外观及其他功能'),
              leading: const Icon(Icons.settings),
              onTap: () => Get.toNamed('/setting'),
            ),
          ],
        ),
      ),
    ),
  );
}
