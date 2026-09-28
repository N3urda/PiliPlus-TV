import 'package:flutter/widgets.dart';

/// Keeps TV thumbnail retention modest and releases reusable images when the
/// app is backgrounded or Android reports memory pressure.
class TvMemoryPolicy with WidgetsBindingObserver {
  TvMemoryPolicy({ImageCache? imageCache, WidgetsBinding? binding})
    : _binding = binding ?? WidgetsBinding.instance,
      _imageCache = imageCache ?? PaintingBinding.instance.imageCache;

  final WidgetsBinding _binding;
  final ImageCache _imageCache;
  bool _installed = false;

  void install() {
    if (_installed) return;
    _installed = true;
    _imageCache
      ..maximumSizeBytes = 32 << 20
      ..maximumSize = 96;
    _binding.addObserver(this);
  }

  @override
  void didHaveMemoryPressure() {
    if (!_installed) return;
    _imageCache
      ..maximumSizeBytes = 16 << 20
      ..maximumSize = 48
      ..clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_installed && state == AppLifecycleState.paused) {
      // Keep live image tracking: clearing it could decode visible covers twice.
      _imageCache.clear();
    }
  }

  void dispose() {
    if (!_installed) return;
    _binding.removeObserver(this);
    _installed = false;
  }
}
