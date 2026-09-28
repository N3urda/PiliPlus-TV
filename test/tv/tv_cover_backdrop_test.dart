import 'dart:async';
import 'dart:ui' as ui;

import 'package:PiliPlus/tv/widgets/tv_cover_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ui.Image makeImage(Color color) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(color, BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(16, 9);
  picture.dispose();
  return image;
}

class _CountingCanvas extends Fake implements Canvas {
  int images = 0;
  int fills = 0;
  int gradients = 0;

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) {
    images++;
  }

  @override
  void drawColor(Color color, BlendMode blendMode) {
    fills++;
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    if (paint.shader != null) {
      gradients++;
    } else {
      fills++;
    }
  }
}

void main() {
  testWidgets('rapid cover changes only load the settled cover', (
    tester,
  ) async {
    final requested = <String>[];
    final image = makeImage(Colors.blue);
    Future<ui.Image> loader(String url) async {
      requested.add(url);
      return image;
    }

    Widget backdrop(String? url) => MaterialApp(
      home: TvCoverBackdrop(coverUrl: url, imageLoader: loader),
    );

    await tester.pumpWidget(backdrop('https://cover.test/first.jpg'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(backdrop('https://cover.test/second.jpg'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(requested, isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(requested, ['https://cover.test/second.jpg']);
    expect(image.debugDisposed, isFalse);

    await tester.pumpWidget(const SizedBox());
    expect(image.debugDisposed, isTrue);
  });

  testWidgets('stale loads are discarded and work stays serial', (
    tester,
  ) async {
    final requested = <String>[];
    final first = Completer<ui.Image>();
    final second = Completer<ui.Image>();
    Future<ui.Image> loader(String url) {
      requested.add(url);
      return requested.length == 1 ? first.future : second.future;
    }

    Widget backdrop(String url) => MaterialApp(
      home: TvCoverBackdrop(coverUrl: url, imageLoader: loader),
    );

    await tester.pumpWidget(backdrop('https://cover.test/first.jpg'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(backdrop('https://cover.test/second.jpg'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(requested, ['https://cover.test/first.jpg']);

    final stale = makeImage(Colors.red);
    first.complete(stale);
    await tester.pump();
    expect(stale.debugDisposed, isTrue);
    expect(requested, [
      'https://cover.test/first.jpg',
      'https://cover.test/second.jpg',
    ]);

    await tester.pumpWidget(const SizedBox());
    final late = makeImage(Colors.blue);
    second.complete(late);
    await tester.pump();
    expect(late.debugDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fading retains only two covers and releases the old cover', (
    tester,
  ) async {
    final images = <ui.Image>[];
    Future<ui.Image> loader(String url) async {
      final image = makeImage(images.isEmpty ? Colors.red : Colors.blue);
      images.add(image);
      return image;
    }

    Widget backdrop(String? url) => MaterialApp(
      home: TvCoverBackdrop(coverUrl: url, imageLoader: loader),
    );

    await tester.pumpWidget(backdrop('https://cover.test/first.jpg'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pumpWidget(backdrop('https://cover.test/second.jpg'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(images, hasLength(2));
    expect(images.every((image) => !image.debugDisposed), isTrue);
    await tester.pumpAndSettle();
    expect(images.first.debugDisposed, isTrue);
    expect(images.last.debugDisposed, isFalse);

    await tester.pumpWidget(backdrop(null));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(images.last.debugDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed covers fade to the neutral background', (tester) async {
    final image = makeImage(Colors.green);
    var requests = 0;
    Future<ui.Image> loader(String url) async {
      requests++;
      if (requests == 1) return image;
      throw StateError('Unavailable cover');
    }

    Widget backdrop(String? url) => MaterialApp(
      home: TvCoverBackdrop(coverUrl: url, imageLoader: loader),
    );

    await tester.pumpWidget(backdrop(null));
    await tester.pump(const Duration(milliseconds: 200));
    expect(requests, 0);
    await tester.pumpWidget(backdrop('//cover.test/valid.jpg'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(image.debugDisposed, isFalse);

    await tester.pumpWidget(backdrop('https://cover.test/broken.jpg'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(image.debugDisposed, isTrue);
    expect(requests, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('steady and fading frames only draw precomposed images', (
    tester,
  ) async {
    Future<ui.Image> loader(String url) async => makeImage(Colors.blue);
    Widget backdrop(String url) => MaterialApp(
      home: TvCoverBackdrop(coverUrl: url, imageLoader: loader),
    );
    _CountingCanvas paintBackdrop() {
      final widget = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(TvCoverBackdrop),
          matching: find.byType(CustomPaint),
        ),
      );
      final canvas = _CountingCanvas();
      widget.painter!.paint(canvas, const Size(1920, 1080));
      return canvas;
    }

    await tester.pumpWidget(backdrop('https://cover.test/first.jpg'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final steady = paintBackdrop();
    expect(steady.images, 1);
    expect(steady.fills, 0);
    expect(steady.gradients, 0);

    await tester.pumpWidget(backdrop('https://cover.test/second.jpg'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));
    final fading = paintBackdrop();
    expect(fading.images, 2);
    expect(fading.fills, 0);
    expect(fading.gradients, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('backgrounding frees covers and resumes with the latest cover', (
    tester,
  ) async {
    final images = <ui.Image>[];
    final requested = <String>[];
    Future<ui.Image> loader(String url) async {
      requested.add(url);
      final image = makeImage(Colors.blue);
      images.add(image);
      return image;
    }

    Widget backdrop(String url) => MaterialApp(
      home: TvCoverBackdrop(coverUrl: url, imageLoader: loader),
    );

    await tester.pumpWidget(backdrop('https://cover.test/first.jpg'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(images.single.debugDisposed, isTrue);
    await tester.pumpWidget(backdrop('https://cover.test/second.jpg'));
    await tester.pump(const Duration(seconds: 1));
    expect(requested, ['https://cover.test/first.jpg']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(requested.last, 'https://cover.test/second.jpg');
    expect(images.last.debugDisposed, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('memory pressure discards late image work without reloading', (
    tester,
  ) async {
    final pending = Completer<ui.Image>();
    var requests = 0;
    Future<ui.Image> loader(String url) {
      requests++;
      return pending.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: TvCoverBackdrop(
          coverUrl: 'https://cover.test/pending.jpg',
          imageLoader: loader,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    tester.binding.handleMemoryPressure();
    final image = makeImage(Colors.blue);
    pending.complete(image);
    await tester.pump(const Duration(seconds: 1));
    expect(image.debugDisposed, isTrue);
    expect(requests, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
