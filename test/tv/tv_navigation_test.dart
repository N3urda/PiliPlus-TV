import 'package:PiliPlus/tv/tv_remote.dart';
import 'package:PiliPlus/tv/widgets/tv_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'TV remote uses select for playback and horizontal arrows for seeking',
    () {
      expect(
        tvPlaybackAction(LogicalKeyboardKey.select),
        TvPlaybackAction.toggle,
      );
      expect(
        tvPlaybackAction(LogicalKeyboardKey.enter),
        TvPlaybackAction.toggle,
      );
      expect(
        tvPlaybackAction(LogicalKeyboardKey.mediaPlayPause),
        TvPlaybackAction.toggle,
      );
      expect(
        tvPlaybackAction(LogicalKeyboardKey.arrowLeft),
        TvPlaybackAction.seekBack,
      );
      expect(
        tvPlaybackAction(LogicalKeyboardKey.arrowRight),
        TvPlaybackAction.seekForward,
      );
      expect(
        tvPlaybackAction(LogicalKeyboardKey.arrowUp),
        TvPlaybackAction.showControls,
      );
      expect(
        tvPlaybackAction(LogicalKeyboardKey.arrowDown),
        TvPlaybackAction.showControls,
      );
    },
  );

  testWidgets('a focused TV action activates with the remote select key', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvAction(
            autofocus: true,
            onPressed: () => taps++,
            child: const Text('播放'),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(taps, 1);
    expect(find.text('播放'), findsOneWidget);
  });

  testWidgets('right arrow moves focus to the next TV action', (tester) async {
    var selected = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              TvAction(
                autofocus: true,
                onPressed: () => selected = 'first',
                child: const Text('第一个'),
              ),
              TvAction(
                onPressed: () => selected = 'second',
                child: const Text('第二个'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(selected, 'second');
  });
}
