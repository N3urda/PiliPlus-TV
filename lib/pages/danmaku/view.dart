import 'dart:convert';

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/pages/danmaku/controller.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/tv/tv_mode.dart';
import 'package:PiliPlus/utils/danmaku_utils.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 传入播放器控制器，监听播放进度，加载对应弹幕
class PlDanmaku extends StatelessWidget {
  final int cid;
  final PlPlayerController playerController;
  final bool isPipMode;
  final bool isFullScreen;
  final bool isFileSource;
  final Size size;

  const PlDanmaku({
    super.key,
    required this.cid,
    required this.playerController,
    this.isPipMode = false,
    required this.isFullScreen,
    required this.isFileSource,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (!TvMode.enabled) return _ActivePlDanmaku(configuration: this);
    return Obx(
      () => playerController.enableShowDanmaku.value
          ? _ActivePlDanmaku(configuration: this)
          : const SizedBox.shrink(),
    );
  }

  bool get notFullscreen => !isFullScreen || isPipMode;
}

class _ActivePlDanmaku extends StatefulWidget {
  const _ActivePlDanmaku({required this.configuration});

  final PlDanmaku configuration;

  @override
  State<_ActivePlDanmaku> createState() => _PlDanmakuState();
}

class _PlDanmakuState extends State<_ActivePlDanmaku> {
  PlDanmaku get configuration => widget.configuration;
  PlPlayerController get playerController => configuration.playerController;

  late final PlDanmakuController _plDanmakuController;
  DanmakuController<DanmakuExtra>? _controller;
  int latestAddedPosition = -1;

  @override
  void initState() {
    super.initState();
    _plDanmakuController = PlDanmakuController(
      configuration.cid,
      playerController,
      configuration.isFileSource,
    );
    if (playerController.enableShowDanmaku.value) {
      if (configuration.isFileSource) {
        _plDanmakuController.initFileDmIfNeeded();
      } else {
        _plDanmakuController.queryDanmaku(
          DmUtils.calcSegment(playerController.positionInMilliseconds),
        );
      }
    }
    playerController
      ..addStatusLister(playerListener)
      ..addPositionListener(videoPositionListen);
  }

  @override
  void didUpdateWidget(_ActivePlDanmaku oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuration.notFullscreen != configuration.notFullscreen &&
        !DanmakuOptions.sameFontScale) {
      _controller?.updateOption(
        DanmakuOptions.get(notFullscreen: configuration.notFullscreen),
      );
    }
  }

  // 播放器状态监听
  void playerListener(PlayerStatus status) {
    if (_controller case final controller?) {
      if (status.isPlaying) {
        controller.resume();
      } else {
        controller.pause();
      }
    }
  }

  @pragma('vm:notify-debugger-on-exception')
  void videoPositionListen(Duration position) {
    if (_controller == null || !playerController.enableShowDanmaku.value) {
      return;
    }

    if (!playerController.showDanmaku && !configuration.isPipMode) {
      return;
    }

    if (!playerController.playerStatus.isPlaying) {
      return;
    }

    int currentPosition = position.inMilliseconds;
    currentPosition -= currentPosition % 100; //取整百的毫秒数
    if (currentPosition == latestAddedPosition) {
      return;
    }
    latestAddedPosition = currentPosition;

    List<DanmakuElem>? currentDanmakuList = _plDanmakuController
        .getCurrentDanmaku(currentPosition);
    if (currentDanmakuList != null) {
      final blockColorful = DanmakuOptions.blockColorful;
      final danmakuWeight = DanmakuOptions.danmakuWeight;
      for (DanmakuElem e in currentDanmakuList) {
        if (e.weight < danmakuWeight) return;
        if (e.mode == 7) {
          try {
            _controller!.addDanmaku(
              SpecialDanmakuContentItem.fromList(
                DmUtils.decimalToColor(e.color),
                e.fontsize.toDouble(),
                jsonDecode(e.content.replaceAll('\n', '\\n')),
                extra: VideoDanmaku(
                  id: e.id.toInt(),
                  mid: e.midHash,
                  like: e.likeCount.toInt(),
                ),
              ),
            );
          } catch (_) {}
        } else {
          _controller!.addDanmaku(
            DanmakuContentItem(
              e.content,
              color: blockColorful
                  ? Colors.white
                  : DmUtils.decimalToColor(e.color),
              type: DmUtils.getPosition(e.mode),
              isColorful:
                  playerController.showVipDanmaku &&
                  e.colorful == DmColorfulType.VipGradualColor,
              count: e.count > 1 ? e.count : null,
              selfSend: e.isSelf,
              extra: VideoDanmaku(
                id: e.id.toInt(),
                mid: e.midHash,
                like: e.likeCount.toInt(),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    playerController
      ..removePositionListener(videoPositionListen)
      ..removeStatusLister(playerListener);
    _plDanmakuController.dispose();
    if (identical(playerController.danmakuController, _controller)) {
      playerController.danmakuController = null;
    }
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final option = DanmakuOptions.get(
      notFullscreen: configuration.notFullscreen,
      speed: playerController.playbackSpeed,
    );
    return Obx(
      () => AnimatedOpacity(
        opacity: playerController.enableShowDanmaku.value
            ? playerController.danmakuOpacity.value
            : 0,
        duration: const Duration(milliseconds: 100),
        child: DanmakuScreen<DanmakuExtra>(
          createdController: (e) {
            playerController.danmakuController = _controller = e;
          },
          option: option,
          size: configuration.size,
        ),
      ),
    );
  }
}
