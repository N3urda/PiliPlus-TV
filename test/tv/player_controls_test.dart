import 'package:PiliPlus/common/widgets/tv/tv_navigation.dart';
import 'package:PiliPlus/pages/video/widgets/tv_player_controls.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

class _LoadingPlayer extends Fake implements PlPlayerController {
  @override
  final tvControlsVisible = false.obs;
  @override
  final isFullScreen = true.obs;
  @override
  bool isLive = false;
  @override
  final position = 0.obs;
  @override
  final duration = 0.obs;
  @override
  final enableShowDanmakuAdaptive = true.obs;
  @override
  Player? get videoPlayerController => null;
  @override
  set controls(bool value) {}
}

void main() {
  testWidgets(
    'loading player tolerates seek and TV menu preserves button activation',
    (tester) async {
      final player = _LoadingPlayer();
      var qualitySelections = 0;
      final details = FocusNode();
      addTearDown(details.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => TvNavigation(child: child!),
          home: Scaffold(
            body: TvPlayerControls(
              player: player,
              actions: [
                (label: 'Quality', onPressed: () => qualitySelections++),
              ],
              child: Center(
                child: TextButton(
                  focusNode: details,
                  onPressed: () {},
                  child: const Text('Details'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(player.tvControlsVisible.value, isTrue);
      expect(details.canRequestFocus, isFalse);
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(qualitySelections, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(player.tvControlsVisible.value, isFalse);
      player.isFullScreen.value = false;
      await tester.pumpAndSettle();
      expect(details.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
