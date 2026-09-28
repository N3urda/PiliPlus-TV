import 'dart:async';

import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/services/shutdown_timer_service.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/tv_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

typedef TvPlayerAction = ({String label, VoidCallback onPressed});

class TvPlayerControls extends StatefulWidget {
  const TvPlayerControls({
    super.key,
    required this.child,
    required this.player,
    this.intro,
    this.canPlay,
    this.actions = const [],
    this.onRefresh,
  });
  final Widget child;
  final PlPlayerController player;
  final CommonIntroController? intro;
  final ValueGetter<bool>? canPlay;
  final List<TvPlayerAction> actions;
  final VoidCallback? onRefresh;

  @override
  State<TvPlayerControls> createState() => _TvPlayerControlsState();
}

class _TvPlayerControlsState extends State<TvPlayerControls> {
  final _surface = FocusNode(debugLabel: 'TV player');
  final _playButton = FocusNode(debugLabel: 'TV play/pause');
  late final StreamSubscription<bool> _visibility;
  late final StreamSubscription<bool> _fullScreen;
  final _seekClock = Stopwatch()..start();
  int _lastSeek = -200;
  PlPlayerController get player => widget.player;

  @override
  void initState() {
    super.initState();
    _visibility = player.tvControlsVisible.listen((visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (visible) {
          _playButton.requestFocus();
        } else {
          _surface.requestFocus();
        }
      });
    });
    _fullScreen = player.isFullScreen.listen((fullScreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || player.tvControlsVisible.value) return;
        if (fullScreen) {
          _surface.requestFocus();
        } else {
          _surface.nextFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _visibility.cancel();
    _fullScreen.cancel();
    _surface.dispose();
    _playButton.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!(widget.canPlay?.call() ?? true)) return;
    if (player.videoPlayerController != null) player.onDoubleTapCenter();
  }

  void _seek(bool forward) {
    if (player.isLive || player.videoPlayerController == null) return;
    final now = _seekClock.elapsedMilliseconds;
    if (now - _lastSeek < 200) return;
    _lastSeek = now;
    if (forward) {
      player.onForward(player.fastForBackwardDuration);
    } else {
      player.onBackward(player.fastForBackwardDuration);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final command = TvInput.playerCommand(
      event.logicalKey,
      menuVisible: player.tvControlsVisible.value,
    );
    if (command == TvPlayerCommand.none) return KeyEventResult.ignored;
    // Details and dialogs must keep their own navigation when not full-screen.
    if (!player.isFullScreen.value && !player.tvControlsVisible.value) {
      if (!_surface.hasPrimaryFocus ||
          command == TvPlayerCommand.forward ||
          command == TvPlayerCommand.backward ||
          (command == TvPlayerCommand.menu &&
              event.logicalKey != LogicalKeyboardKey.contextMenu)) {
        return KeyEventResult.ignored;
      }
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent &&
        command != TvPlayerCommand.forward &&
        command != TvPlayerCommand.backward) {
      return KeyEventResult.handled;
    }
    switch (command) {
      case TvPlayerCommand.toggle:
        _toggle();
      case TvPlayerCommand.play:
        if (widget.canPlay?.call() ?? true) player.play();
      case TvPlayerCommand.pause:
        player.pause();
      case TvPlayerCommand.backward:
        _seek(false);
      case TvPlayerCommand.forward:
        _seek(true);
      case TvPlayerCommand.menu:
        player.controls = false;
        player.tvControlsVisible.value = true;
      case TvPlayerCommand.dismiss:
        player.tvControlsVisible.value = false;
      case TvPlayerCommand.none:
        break;
    }
    return KeyEventResult.handled;
  }

  void _changeEpisode(bool next) {
    final changed = next ? widget.intro?.nextPlay() : widget.intro?.prevPlay();
    if (changed != true) SmartDialog.showToast(next ? '已经是最后一集了' : '已经是第一集了');
  }

  Future<void> _speed() async {
    final speed = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('播放速度'),
        children: [
          for (final value in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(
                '${value}x${player.playbackSpeed == value ? '  ✓' : ''}',
              ),
            ),
        ],
      ),
    );
    if (mounted && speed != null) player.setPlaybackSpeed(speed);
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _surface,
    autofocus: true,
    onKeyEvent: _onKey,
    child: Obx(() {
      final visible = player.tvControlsVisible.value;
      return Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: player.isFullScreen.value || visible,
            child: widget.child,
          ),
          if (visible)
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: const Color(0xF0202228),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.isLive
                              ? '直播'
                              : '${DurationUtils.formatDuration(player.position.value)} / ${DurationUtils.formatDuration(player.duration.value)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            spacing: 12,
                            children: [
                              FilledButton(
                                focusNode: _playButton,
                                onPressed: _toggle,
                                child: const Text('播放 / 暂停'),
                              ),
                              if (!player.isLive) ...[
                                OutlinedButton(
                                  onPressed: () => _changeEpisode(false),
                                  child: const Text('上一集'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _changeEpisode(true),
                                  child: const Text('下一集'),
                                ),
                              ],
                              for (final action in widget.actions)
                                OutlinedButton(
                                  onPressed: action.onPressed,
                                  child: Text(action.label),
                                ),
                              OutlinedButton(
                                onPressed: () {
                                  final value =
                                      !player.enableShowDanmakuAdaptive.value;
                                  player.enableShowDanmakuAdaptive.value =
                                      value;
                                  if (!player.tempPlayerConf) {
                                    GStorage.setting.put(
                                      player.isLive
                                          ? SettingBoxKey.enableShowLiveDanmaku
                                          : SettingBoxKey.enableShowDanmaku,
                                      value,
                                    );
                                  }
                                },
                                child: Text(
                                  player.enableShowDanmakuAdaptive.value
                                      ? '关闭弹幕'
                                      : '打开弹幕',
                                ),
                              ),
                              if (!player.isLive)
                                OutlinedButton(
                                  onPressed: _speed,
                                  child: const Text('倍速'),
                                ),
                              if (widget.intro != null)
                                OutlinedButton(
                                  onPressed: () => widget.intro!.actionFavVideo(
                                    isQuick: true,
                                  ),
                                  child: const Text('收藏'),
                                ),
                              OutlinedButton(
                                onPressed: () =>
                                    shutdownTimerService.showScheduleExitDialog(
                                      context,
                                      isFullScreen: player.isFullScreen.value,
                                      isLive: player.isLive,
                                    ),
                                child: const Text('定时关闭'),
                              ),
                              if (widget.onRefresh != null)
                                OutlinedButton(
                                  onPressed: widget.onRefresh,
                                  child: const Text('重试播放'),
                                ),
                              OutlinedButton(
                                onPressed: () {
                                  player.tvControlsVisible.value = false;
                                  player.triggerFullScreen(
                                    status: !player.isFullScreen.value,
                                  );
                                },
                                child: Text(
                                  player.isFullScreen.value ? '查看详情' : '全屏',
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    player.tvControlsVisible.value = false,
                                child: const Text('收起'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '方向键选择 · 确认键执行 · 返回键收起｜播放画面：左右快进，上下打开菜单',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }),
  );
}
