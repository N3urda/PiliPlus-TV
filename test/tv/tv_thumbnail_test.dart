import 'dart:async';
import 'dart:ui' as ui;

import 'package:PiliPlus/tv/tv_thumbnail.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unusually tall covers decode inside the thumbnail pixel budget',
    () async {
      final picture = ui.PictureRecorder();
      ui.Canvas(picture).drawColor(const Color(0xffabcdef), ui.BlendMode.src);
      final drawing = picture.endRecording();
      final source = await drawing.toImage(40, 2000);
      drawing.dispose();
      final bytes = await source.toByteData(format: ui.ImageByteFormat.png);
      source.dispose();

      final provider = tvThumbnailProvider(
        MemoryImage(bytes!.buffer.asUint8List()),
        maxWidth: 360,
      );
      final completer = Completer<ImageInfo>();
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (image, _) => completer.complete(image),
      );
      stream.addListener(listener);
      final image = await completer.future;
      expect(image.image.width, lessThanOrEqualTo(360));
      expect(image.image.height, lessThanOrEqualTo(203));
      expect(image.image.width / image.image.height, closeTo(40 / 2000, 0.005));
      stream.removeListener(listener);
      image.dispose();
      await provider.evict();
    },
  );
}
