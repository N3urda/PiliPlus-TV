import 'package:PiliPlus/utils/connectivity_utils.dart';
import 'package:PiliPlus/utils/tv_input.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wired and wireless broadband use the same quality profile', () {
    expect(
      ConnectivityUtils.usesBroadbandPreferences([ConnectivityResult.ethernet]),
      isTrue,
    );
    expect(
      ConnectivityUtils.usesBroadbandPreferences([ConnectivityResult.wifi]),
      isTrue,
    );
    expect(
      ConnectivityUtils.usesBroadbandPreferences([ConnectivityResult.mobile]),
      isFalse,
    );
    expect(
      ConnectivityUtils.usesBroadbandPreferences([ConnectivityResult.none]),
      isFalse,
    );
    expect(
      ConnectivityUtils.usesBroadbandPreferences([
        ConnectivityResult.vpn,
        ConnectivityResult.ethernet,
      ]),
      isTrue,
    );
  });
  test('remote OK pauses instead of sending a comment', () {
    for (final key in [
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.gameButtonA,
    ]) {
      expect(
        TvInput.playerCommand(key, menuVisible: false),
        TvPlayerCommand.toggle,
      );
      expect(
        TvInput.playerCommand(key, menuVisible: true),
        TvPlayerCommand.none,
      );
    }
  });
  test('arrows navigate visible controls instead of changing playback', () {
    for (final key in [
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ]) {
      expect(
        TvInput.playerCommand(key, menuVisible: true),
        TvPlayerCommand.none,
      );
    }
    expect(
      TvInput.playerCommand(LogicalKeyboardKey.arrowUp, menuVisible: false),
      TvPlayerCommand.menu,
    );
    expect(
      TvInput.playerCommand(LogicalKeyboardKey.arrowLeft, menuVisible: false),
      TvPlayerCommand.backward,
    );
    expect(
      TvInput.playerCommand(LogicalKeyboardKey.arrowRight, menuVisible: false),
      TvPlayerCommand.forward,
    );
  });
  test(
    'Android back uses navigation, escape closes controls, media keys work',
    () {
      expect(
        TvInput.playerCommand(LogicalKeyboardKey.goBack, menuVisible: true),
        TvPlayerCommand.none,
      );
      expect(
        TvInput.playerCommand(LogicalKeyboardKey.goBack, menuVisible: false),
        TvPlayerCommand.none,
      );
      expect(
        TvInput.playerCommand(LogicalKeyboardKey.escape, menuVisible: true),
        TvPlayerCommand.dismiss,
      );
      for (final visible in [true, false]) {
        expect(
          TvInput.playerCommand(
            LogicalKeyboardKey.mediaPlayPause,
            menuVisible: visible,
          ),
          TvPlayerCommand.toggle,
        );
      }
    },
  );
}
