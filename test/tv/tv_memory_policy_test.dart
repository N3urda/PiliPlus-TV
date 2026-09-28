import 'package:PiliPlus/tv/tv_memory_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _ImageCache extends ImageCache {
  int clearCalls = 0;
  int clearLiveCalls = 0;

  @override
  void clear() {
    clearCalls++;
    super.clear();
  }

  @override
  void clearLiveImages() {
    clearLiveCalls++;
    super.clearLiveImages();
  }
}

void main() {
  testWidgets('TV cache starts with a 32 MiB and 96 image budget', (
    tester,
  ) async {
    final cache = _ImageCache();
    final policy = TvMemoryPolicy(imageCache: cache)..install();
    addTearDown(policy.dispose);

    expect(cache.maximumSizeBytes, 32 << 20);
    expect(cache.maximumSize, 96);
  });

  testWidgets(
    'backgrounding clears reusable images but preserves live images',
    (
      tester,
    ) async {
      final cache = _ImageCache();
      final policy = TvMemoryPolicy(imageCache: cache)..install();
      addTearDown(policy.dispose);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(cache.clearCalls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(cache.clearCalls, 1);
      expect(cache.clearLiveCalls, 0);
      expect(cache.maximumSizeBytes, 32 << 20);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets(
    'memory pressure budget stays reduced after resume and repeated install',
    (
      tester,
    ) async {
      final cache = _ImageCache();
      final policy = TvMemoryPolicy(imageCache: cache)..install();
      addTearDown(policy.dispose);

      tester.binding.handleMemoryPressure();
      expect(cache.maximumSizeBytes, 16 << 20);
      expect(cache.maximumSize, 48);
      expect(cache.clearCalls, 1);
      expect(cache.clearLiveCalls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      policy.install();
      expect(cache.maximumSizeBytes, 16 << 20);
      expect(cache.maximumSize, 48);
      expect(cache.clearCalls, 2);
      expect(cache.clearLiveCalls, 0);
    },
  );

  testWidgets('dispose unregisters the memory and lifecycle observer', (
    tester,
  ) async {
    final cache = _ImageCache();
    TvMemoryPolicy(imageCache: cache)
      ..install()
      ..dispose()
      ..dispose();

    tester.binding.handleMemoryPressure();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(cache.clearCalls, 0);
    expect(cache.clearLiveCalls, 0);
    expect(cache.maximumSizeBytes, 32 << 20);
    expect(cache.maximumSize, 96);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
