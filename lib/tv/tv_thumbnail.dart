import 'package:flutter/painting.dart';

/// Bound both decoded dimensions, including unusually tall source covers.
/// `fit` preserves the source aspect ratio and never enlarges a small image.
ResizeImage tvThumbnailProvider(
  ImageProvider source, {
  required int maxWidth,
}) => ResizeImage(
  source,
  width: maxWidth,
  height: (maxWidth * 9 / 16).ceil(),
  policy: ResizeImagePolicy.fit,
);
