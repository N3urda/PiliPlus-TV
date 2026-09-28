import 'dart:async';

import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/setting/pages/tv_settings.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/continue_watching.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class TvHomeHeader extends StatefulWidget {
  const TvHomeHeader({super.key});

  @override
  State<TvHomeHeader> createState() => _TvHomeHeaderState();
}

class _TvHomeHeaderState extends State<TvHomeHeader>
    with RouteAware, RouteAwareMixin, WidgetsBindingObserver {
  List<HistoryItemModel> _items = [];
  String? _error;
  bool _loading = true;
  int _generation = 0;
  Account? _displayedAccount;
  late final StreamSubscription<bool> _accountChanges;
  late final StreamSubscription<bool> _privacyChanges;

  bool get _canShowHistory =>
      Accounts.history.isLogin && !MineController.anonymity.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accountChanges = Get.find<AccountService>().isLogin.listen(
      (_) => _reload(),
    );
    _privacyChanges = MineController.anonymity.listen((_) => _reload());
    _reload();
  }

  @override
  void dispose() {
    _generation++;
    _accountChanges.cancel();
    _privacyChanges.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didPopNext() => _reload();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final account = Accounts.history;
    if (account != _displayedAccount) {
      _items = [];
      _displayedAccount = account;
    }
    if (!_canShowHistory) {
      setState(() {
        _items = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await UserHttp.historyList(
        type: 'all',
        account: account,
      ).timeout(const Duration(seconds: 15));
      if (!mounted ||
          generation != _generation ||
          account != Accounts.history) {
        return;
      }
      setState(() {
        _loading = false;
        if (result case Success(:final response)) {
          _items = ContinueWatching.select(response.list ?? []);
        } else {
          _error = '观看记录暂时无法加载';
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = '观看记录暂时无法加载';
      });
    }
  }

  Future<void> _resume(HistoryItemModel item) async {
    try {
      if (item.history.business == 'pgc') {
        await PageUtils.viewPgc(
          epId: item.history.epid,
          progress: item.playbackProgress,
        );
      } else {
        final cid =
            item.history.cid ??
            (await SearchHttp.ab2cWithDimension(
              aid: item.history.oid,
              bvid: item.history.bvid,
              part: item.history.page,
            ))?.cid;
        if (!mounted) return;
        if (cid == null) {
          SmartDialog.showToast('无法打开该视频，请稍后重试');
          return;
        }
        await PageUtils.toVideoPage(
          aid: item.history.oid,
          bvid: item.history.bvid,
          cid: cid,
          title: item.title,
          cover: item.cover,
          progress: item.playbackProgress,
        );
      }
    } catch (_) {
      SmartDialog.showToast('视频加载失败，请检查网络后重试');
    }
  }

  void _open(String route, {bool login = false}) {
    if (login && !Accounts.main.isLogin) {
      Get.toNamed('/loginPage');
    } else {
      Get.toNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _open('/search'),
                icon: const Icon(Icons.search),
                label: const Text('搜索'),
              ),
              OutlinedButton(
                onPressed: () => _open('/history', login: true),
                child: const Text('观看记录'),
              ),
              OutlinedButton(
                onPressed: () => _open('/fav', login: true),
                child: const Text('我的收藏'),
              ),
              OutlinedButton(
                onPressed: () => _open('/later', login: true),
                child: const Text('稍后再看'),
              ),
              OutlinedButton(
                onPressed: () => Accounts.main.isLogin
                    ? Get.toNamed('/fav', arguments: 1)
                    : Get.toNamed('/loginPage'),
                child: const Text('追番'),
              ),
              OutlinedButton(
                onPressed: () => _open('/subscription', login: true),
                child: const Text('订阅'),
              ),
              OutlinedButton(
                onPressed: () => Get.to(() => const TvSettingsPage()),
                child: const Text('设置'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('继续观看', style: theme.textTheme.titleLarge),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              TextButton(onPressed: _reload, child: const Text('刷新')),
            ],
          ),
          if (!_canShowHistory)
            TextButton(
              onPressed: MineController.anonymity.value
                  ? null
                  : () => _open('/loginPage'),
              child: Text(
                MineController.anonymity.value ? '无痕模式下不展示观看记录' : '扫码登录，同步观看进度',
              ),
            )
          else if (_error != null)
            TextButton(onPressed: _reload, child: Text('$_error，选择重试'))
          else if (!_loading && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('最近没有未看完的视频，看看下面的推荐吧'),
            )
          else if (_items.isNotEmpty)
            SizedBox(
              height: 220,
              child: ListView.separated(
                key: const PageStorageKey('tv-continue-watching'),
                scrollDirection: Axis.horizontal,
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return SizedBox(
                    key: ValueKey(ContinueWatching.key(item)),
                    width: 240,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _resume(item),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NetworkImgLayer(
                              src: item.cover,
                              width: 240,
                              height: 135,
                            ),
                            LinearProgressIndicator(
                              value: (item.duration ?? 0) > 0
                                  ? (item.progress! / item.duration!).clamp(
                                      0.0,
                                      1.0,
                                    )
                                  : 0,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title ?? '继续播放',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${item.showTitle?.isNotEmpty == true ? '${item.showTitle} · ' : ''}已看 ${DurationUtils.formatDuration(item.progress!)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          Text('为你推荐', style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}
