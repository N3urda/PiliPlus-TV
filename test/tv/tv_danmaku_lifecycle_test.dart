import 'dart:io';

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/pages/danmaku/controller.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/pages/danmaku/view.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_source.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

class _Player extends Fake implements PlPlayerController {
  @override
  final enableShowDanmaku = false.obs;
  @override
  final danmakuOpacity = 1.0.obs;
  @override
  final bool mergeDanmaku = false;
  @override
  double get playbackSpeed => 1;
  @override
  DanmakuController<DanmakuExtra>? danmakuController;
  @override
  late DataSource dataSource;

  final positionListeners = <ValueChanged<Duration>>{};
  final statusListeners = <ValueChanged<PlayerStatus>>{};

  @override
  void addPositionListener(ValueChanged<Duration> listener) =>
      positionListeners.add(listener);
  @override
  void removePositionListener(ValueChanged<Duration> listener) =>
      positionListeners.remove(listener);
  @override
  void addStatusLister(ValueChanged<PlayerStatus> listener) =>
      statusListeners.add(listener);
  @override
  void removeStatusLister(ValueChanged<PlayerStatus> listener) =>
      statusListeners.remove(listener);
}

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('tv-danmaku-');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
  });
  tearDownAll(() => directory.delete(recursive: true));

  test('late danmaku data is ignored after its layer is disposed', () {
    final controller = PlDanmakuController(1, _Player(), true)..dispose();
    expect(
      () => controller.handleDanmaku([DanmakuElem(content: 'late response')]),
      returnsNormally,
    );
  });

  testWidgets('disabled TV danmaku allocates no canvas or playback listeners', (
    tester,
  ) async {
    final player = _Player();
    await tester.pumpWidget(
      MaterialApp(
        home: PlDanmaku(
          cid: 1,
          playerController: player,
          isFullScreen: true,
          isFileSource: true,
          size: const Size(960, 540),
        ),
      ),
    );
    expect(find.byType(DanmakuScreen<DanmakuExtra>), findsNothing);
    expect(player.positionListeners, isEmpty);
    expect(player.statusListeners, isEmpty);
    expect(player.danmakuController, isNull);
  });

  testWidgets(
    'turning TV danmaku off releases its active layer and can reenable',
    (
      tester,
    ) async {
      final player = _Player()
        ..dataSource = FileSource(
          dir: directory.path,
          isMp4: true,
          hasDashAudio: false,
          typeTag: '',
        );
      await tester.pumpWidget(
        MaterialApp(
          home: PlDanmaku(
            cid: 1,
            playerController: player,
            isFullScreen: true,
            isFileSource: true,
            size: const Size(960, 540),
          ),
        ),
      );
      for (var iteration = 0; iteration < 2; iteration++) {
        player.enableShowDanmaku.value = true;
        await tester.pump();
        expect(find.byType(DanmakuScreen<DanmakuExtra>), findsOneWidget);
        expect(player.positionListeners, hasLength(1));
        expect(player.statusListeners, hasLength(1));
        expect(player.danmakuController, isNotNull);

        player.enableShowDanmaku.value = false;
        await tester.pump();
        expect(find.byType(DanmakuScreen<DanmakuExtra>), findsNothing);
        expect(player.positionListeners, isEmpty);
        expect(player.statusListeners, isEmpty);
        expect(player.danmakuController, isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
