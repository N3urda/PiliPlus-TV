import 'package:PiliPlus/tv/tv_video_entry.dart';
import 'package:PiliPlus/tv/widgets/tv_video_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TV grid fits 18 videos in six columns and OK opens focus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final videos = List.generate(
      18,
      (index) => TvVideoEntry(
        bvid: 'BV$index',
        title: '视频 $index',
        owner: 'UP $index',
      ),
    );
    String? opened;
    final firstFocus = FocusNode();
    addTearDown(firstFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 425,
            child: TvVideoGrid(
              videos: videos,
              firstFocusNode: firstFocus,
              onOpen: (video) => opened = video.bvid,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(TvCinematicVideoCard), findsNWidgets(18));
    expect(
      tester.getTopLeft(find.byType(TvCinematicVideoCard).at(6)).dy,
      greaterThan(
        tester.getTopLeft(find.byType(TvCinematicVideoCard).first).dy,
      ),
    );

    firstFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opened, 'BV0');
  });

  testWidgets('left leaves the first grid column for the navigation rail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final videos = List.generate(
      12,
      (index) => TvVideoEntry(
        bvid: 'BV$index',
        title: '视频 $index',
        owner: 'UP $index',
      ),
    );
    final navigationFocus = FocusNode(debugLabel: 'navigation');
    final firstFocus = FocusNode(debugLabel: 'first video');
    addTearDown(navigationFocus.dispose);
    addTearDown(firstFocus.dispose);
    final exitedFrom = <FocusNode>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Focus(
                focusNode: navigationFocus,
                child: const SizedBox(width: 100, height: 425),
              ),
              SizedBox(
                width: 960,
                height: 425,
                child: TvVideoGrid(
                  videos: videos,
                  firstFocusNode: firstFocus,
                  onOpen: (_) {},
                  onLeftEdge: (current) {
                    exitedFrom.add(current);
                    navigationFocus.requestFocus();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    firstFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(exitedFrom, [same(firstFocus)]);
    expect(navigationFocus.hasFocus, isTrue);

    Focus.of(tester.element(find.text('视频 1'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(exitedFrom, hasLength(1));
    expect(firstFocus.hasFocus, isTrue);

    final nextRowFirstFocus = Focus.of(tester.element(find.text('视频 6')))
      ..requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(exitedFrom, [same(firstFocus), same(nextRowFirstFocus)]);
    expect(navigationFocus.hasFocus, isTrue);
  });
}
