import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/tv/tv_feed_loader.dart';
import 'package:PiliPlus/tv/pages/tv_home_page.dart';
import 'package:PiliPlus/tv/widgets/tv_cover_backdrop.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

class _Video extends BaseVideoItemModel {
  _Video({String id = 'BV1', String name = '加载后的视频', String? image}) {
    bvid = id;
    title = name;
    cover = image;
    owner = _Owner();
    stat = _Stat();
  }
}

class _Owner extends BaseOwner {}

class _Stat extends BaseStat {}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('piliplus-tv-sidebar-');
    Hive.init(tempDir.path);
    GStorage.localCache = await Hive.openBox('localCache');
    GStorage.setting = await Hive.openBox('setting');
    GStorage.video = await Hive.openBox('video');
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  testWidgets('TV destinations form a left rail beside video content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      GetMaterialApp(
        home: TvHomePage(
          feedLoader: () async => (
            recommended: <BaseVideoItemModel>[],
            popular: <BaseVideoItemModel>[],
            error: null,
          ),
        ),
      ),
    );
    await tester.pump();

    final home = tester.getTopLeft(find.text('首页'));
    final search = tester.getTopLeft(find.text('搜索'));
    final following = tester.getTopLeft(find.text('动态'));
    final popular = tester.getTopLeft(find.text('热门'));
    final content = tester.getTopLeft(find.text('为你推荐'));

    expect(home.dx, lessThan(content.dx));
    expect(search.dy, greaterThan(home.dy));
    expect(following.dy, greaterThan(search.dy));
    expect(popular.dy, greaterThan(following.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('remote changes sections in rail and moves right into content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      GetMaterialApp(
        home: TvHomePage(
          feedLoader: () async => (
            recommended: <BaseVideoItemModel>[],
            popular: <BaseVideoItemModel>[],
            error: null,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.text('关注动态'), findsOneWidget);
    expect(Focus.of(tester.element(find.text('动态'))).hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('扫码登录').last)).hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('动态'))).hasFocus, isTrue);
  });

  testWidgets('cover background follows video focus without moving the focus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      GetMaterialApp(
        home: TvHomePage(
          feedLoader: () async => (
            recommended: <BaseVideoItemModel>[
              _Video(name: '第一个视频', image: 'https://example.com/first.jpg'),
              _Video(
                id: 'BV2',
                name: '第二个视频',
                image: 'https://example.com/second.jpg',
              ),
            ],
            popular: <BaseVideoItemModel>[],
            error: null,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<TvCoverBackdrop>(find.byType(TvCoverBackdrop)).coverUrl,
      'https://example.com/first.jpg',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.idle();
    expect(Focus.of(tester.element(find.text('第一个视频'))).hasFocus, isTrue);
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      tester.widget<TvCoverBackdrop>(find.byType(TvCoverBackdrop)).coverUrl,
      'https://example.com/second.jpg',
    );
    expect(Focus.of(tester.element(find.text('第二个视频'))).hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('right during loading enters the grid when videos arrive', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pendingFeed = Completer<TvFeeds>();
    await tester.pumpWidget(
      GetMaterialApp(home: TvHomePage(feedLoader: () => pendingFeed.future)),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('加载中'))).hasFocus, isTrue);

    pendingFeed.complete((
      recommended: <BaseVideoItemModel>[_Video()],
      popular: <BaseVideoItemModel>[],
      error: null,
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('加载后的视频'), findsOneWidget);
    expect(Focus.of(tester.element(find.text('加载后的视频'))).hasFocus, isTrue);
  });

  testWidgets('leaving content cancels pending focus while videos load', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pendingFeed = Completer<TvFeeds>();
    await tester.pumpWidget(
      GetMaterialApp(home: TvHomePage(feedLoader: () => pendingFeed.future)),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('首页'))).hasFocus, isTrue);

    pendingFeed.complete((
      recommended: <BaseVideoItemModel>[_Video()],
      popular: <BaseVideoItemModel>[],
      error: null,
    ));
    await tester.pump();
    await tester.pump();

    expect(Focus.of(tester.element(find.text('首页'))).hasFocus, isTrue);
  });

  testWidgets('held down stays in the navigation rail at its last item', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      GetMaterialApp(
        home: TvHomePage(
          feedLoader: () async => (
            recommended: <BaseVideoItemModel>[],
            popular: <BaseVideoItemModel>[],
            error: null,
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.pump();
    final lastItem = find.text('扫码登录').first;
    expect(Focus.of(tester.element(lastItem)).hasFocus, isTrue);

    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(Focus.of(tester.element(lastItem)).hasFocus, isTrue);
  });
}
