import 'package:flutter/services.dart';

enum TvPlaybackAction { toggle, seekBack, seekForward, showControls }

TvPlaybackAction? tvPlaybackAction(LogicalKeyboardKey key) => switch (key) {
  LogicalKeyboardKey.select ||
  LogicalKeyboardKey.enter ||
  LogicalKeyboardKey.space ||
  LogicalKeyboardKey.mediaPlayPause => TvPlaybackAction.toggle,
  LogicalKeyboardKey.arrowLeft => TvPlaybackAction.seekBack,
  LogicalKeyboardKey.arrowRight => TvPlaybackAction.seekForward,
  LogicalKeyboardKey.arrowUp ||
  LogicalKeyboardKey.arrowDown => TvPlaybackAction.showControls,
  _ => null,
};
