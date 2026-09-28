import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A cover-colored backdrop precomposed once at thumbnail size.
class TvCoverBackdrop extends StatefulWidget {
  const TvCoverBackdrop({
    super.key,
    required this.coverUrl,
    this.imageLoader,
  });

  final String? coverUrl;

  @visibleForTesting
  final Future<ui.Image> Function(String url)? imageLoader;

  @override
  State<TvCoverBackdrop> createState() => _TvCoverBackdropState();
}

class _TvCoverBackdropState extends State<TvCoverBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..addStatusListener(_onFadeStatus);

  Timer? _debounce;
  ui.Image? _current;
  ui.Image? _previous;
  String? _desiredUrl;
  String? _shownUrl;
  int _generation = 0;
  bool _ready = false;
  bool _loading = false;
  bool _backgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _backgrounded =
        lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.detached;
    _scheduleCover();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _backgrounded = true;
      _releaseCovers();
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      _scheduleCover();
    }
  }

  @override
  void didHaveMemoryPressure() => _releaseCovers();

  void _releaseCovers() {
    _generation++;
    _debounce?.cancel();
    _ready = false;
    _fade.stop();
    setState(() {
      _previous?.dispose();
      _current?.dispose();
      _previous = null;
      _current = null;
      _shownUrl = null;
    });
  }

  @override
  void didUpdateWidget(TvCoverBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.coverUrl != oldWidget.coverUrl) _scheduleCover();
  }

  void _scheduleCover() {
    _generation++;
    _debounce?.cancel();
    final url = widget.coverUrl?.trim();
    _desiredUrl = url == null || url.isEmpty
        ? null
        : url.startsWith('//')
        ? 'https:$url'
        : url;
    _ready = false;
    if (_backgrounded) return;
    _debounce = Timer(const Duration(milliseconds: 180), () {
      _ready = true;
      unawaited(_loadNext());
    });
  }

  Future<void> _loadNext() async {
    // Serial loading and finishing the current fade bound image ownership and
    // avoid repeated blur work while a remote button is held down.
    if (!mounted || _backgrounded || !_ready || _loading || _fade.isAnimating) {
      return;
    }
    _ready = false;
    final url = _desiredUrl;
    if (url == _shownUrl) return;
    if (url == null) {
      _showCover(null, null);
      return;
    }
    final generation = _generation;
    _loading = true;
    try {
      final image = await (widget.imageLoader ?? _loadBlurredCover)(url);
      if (!mounted || generation != _generation) {
        image.dispose();
      } else {
        _showCover(image, url);
      }
    } catch (_) {
      // Cover loading never blocks the foreground or produces an error screen.
      if (mounted && generation == _generation) _showCover(null, url);
    } finally {
      _loading = false;
      if (mounted) unawaited(_loadNext());
    }
  }

  void _showCover(ui.Image? image, String? url) {
    setState(() {
      _previous?.dispose();
      _previous = _current;
      _current = image;
      _shownUrl = url;
    });
    _fade.forward(from: 0);
  }

  void _onFadeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() {
      _previous?.dispose();
      _previous = null;
    });
    unawaited(_loadNext());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _generation++;
    _fade.dispose();
    _previous?.dispose();
    _current?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CoverBackdropPainter(
            current: _current,
            previous: _previous,
            fade: _fade,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

Future<ui.Image> _loadBlurredCover(String url) async {
  const width = 256;
  const height = 144;
  final provider = ResizeImage(
    NetworkImage(url),
    width: width,
    height: height,
    policy: ResizeImagePolicy.fit,
  );
  final stream = provider.resolve(ImageConfiguration.empty);
  final completer = Completer<ImageInfo>();
  var accepting = true;
  final listener = ImageStreamListener(
    (image, _) {
      if (!accepting || completer.isCompleted) {
        image.dispose();
      } else {
        completer.complete(image);
      }
    },
    onError: (Object error, StackTrace? stack) {
      if (accepting && !completer.isCompleted) {
        completer.completeError(error, stack);
      }
    },
  );
  stream.addListener(listener);
  ImageInfo? info;
  try {
    info = await completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        accepting = false;
        throw TimeoutException('Cover loading timed out');
      },
    );
    final source = info.image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final fitted = applyBoxFit(
      BoxFit.cover,
      Size(source.width.toDouble(), source.height.toDouble()),
      const Size(256, 144),
    );
    canvas
      ..drawColor(const Color(0xFF090B10), BlendMode.src)
      ..drawImageRect(
        source,
        Alignment.center.inscribe(
          fitted.source,
          Rect.fromLTWH(
            0,
            0,
            source.width.toDouble(),
            source.height.toDouble(),
          ),
        ),
        const Rect.fromLTWH(0, 0, 256, 144),
        Paint()
          ..filterQuality = FilterQuality.low
          ..color = const Color.fromRGBO(255, 255, 255, 0.82)
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
            tileMode: TileMode.clamp,
          ),
      );
    _drawReadabilityGradients(canvas, const Size(256, 144));
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  } finally {
    accepting = false;
    stream.removeListener(listener);
    info?.dispose();
    // These one-use decode variants must not accumulate in the global cache.
    await provider.evict();
  }
}

class _CoverBackdropPainter extends CustomPainter {
  _CoverBackdropPainter({
    required this.current,
    required this.previous,
    required this.fade,
  }) : super(repaint: fade);

  final ui.Image? current;
  final ui.Image? previous;
  final Animation<double> fade;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final progress = Curves.easeInOut.transform(fade.value);
    void drawCover(ui.Image? image, double opacity) {
      if (image == null || opacity <= 0) return;
      paintImage(
        canvas: canvas,
        rect: bounds,
        image: image,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        opacity: opacity,
      );
    }

    if (current != null && progress >= 1) {
      drawCover(current, 1);
    } else if (previous != null && current != null) {
      // Both precomposed images are opaque: one image establishes the base,
      // then the incoming image blends over it without full-screen gradients.
      drawCover(previous, 1);
      drawCover(current, progress);
    } else {
      canvas.drawColor(const Color(0xFF090B10), BlendMode.src);
      drawCover(previous, 1 - progress);
      drawCover(current, progress);
    }
  }

  @override
  bool shouldRepaint(_CoverBackdropPainter oldDelegate) =>
      oldDelegate.current != current || oldDelegate.previous != previous;
}

void _drawReadabilityGradients(Canvas canvas, Size size) {
  final bounds = Offset.zero & size;
  canvas
    ..drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          [
            const Color(0x90060910),
            const Color(0x18060910),
            const Color(0x34060910),
          ],
          [0, 0.44, 1],
        ),
    )
    ..drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [
            const Color(0x29060910),
            const Color(0x10060910),
            const Color(0xBC060910),
          ],
          [0, 0.38, 1],
        ),
    );
}
