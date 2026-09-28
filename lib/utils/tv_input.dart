import 'package:flutter/services.dart';

enum TvPlayerCommand {
  toggle,
  play,
  pause,
  backward,
  forward,
  menu,
  dismiss,
  none,
}

abstract final class TvInput {
  static TvPlayerCommand playerCommand(
    LogicalKeyboardKey key, {
    required bool menuVisible,
  }) {
    if (key == LogicalKeyboardKey.mediaPlayPause) return TvPlayerCommand.toggle;
    if (key == LogicalKeyboardKey.mediaPlay) return TvPlayerCommand.play;
    if (key == LogicalKeyboardKey.mediaPause) return TvPlayerCommand.pause;
    // Android dispatches Back to the navigator after the key event. Let the
    // page PopScope handle it once, otherwise one press also exits fullscreen.
    if (key == LogicalKeyboardKey.goBack) return TvPlayerCommand.none;
    if (key == LogicalKeyboardKey.escape) {
      return menuVisible ? TvPlayerCommand.dismiss : TvPlayerCommand.none;
    }
    if (key == LogicalKeyboardKey.contextMenu) {
      return menuVisible ? TvPlayerCommand.dismiss : TvPlayerCommand.menu;
    }
    // Visible controls own arrows and activation; do not steal their events.
    if (menuVisible) return TvPlayerCommand.none;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      return TvPlayerCommand.toggle;
    }
    if (key == LogicalKeyboardKey.arrowLeft) return TvPlayerCommand.backward;
    if (key == LogicalKeyboardKey.arrowRight) return TvPlayerCommand.forward;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      return TvPlayerCommand.menu;
    }
    return TvPlayerCommand.none;
  }
}
