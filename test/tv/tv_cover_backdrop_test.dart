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
}
