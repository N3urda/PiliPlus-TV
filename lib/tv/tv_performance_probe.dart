import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// Opt-in evidence collection. The shipped APK leaves this disabled.
abstract final class TvPerformanceProbe {
  static const enabled = bool.fromEnvironment('TV_PERF_PROBE');
  static bool _installed = false;

  static void install() {
    if (!enabled || _installed) return;
    _installed = true;
    final timings = <FrameTiming>[];
    SchedulerBinding.instance.addTimingsCallback((batch) {
      timings.addAll(batch);
      if (timings.length > 600) {
        timings.removeRange(0, timings.length - 600);
      }
    });
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (timings.isEmpty) return;
      final frames = List<FrameTiming>.of(timings);
      timings.clear();
      final cache = PaintingBinding.instance.imageCache;
      debugPrint(
        'TV_PERF ${jsonEncode({
          'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
          'frames': frames.length,
          'build': _summary(frames.map((f) => f.buildDuration.inMicroseconds)),
          'raster': _summary(frames.map((f) => f.rasterDuration.inMicroseconds)),
          'over_16ms': frames.where((f) => f.buildDuration.inMicroseconds > 16667 || f.rasterDuration.inMicroseconds > 16667).length,
          'over_33ms': frames.where((f) => f.buildDuration.inMicroseconds > 33333 || f.rasterDuration.inMicroseconds > 33333).length,
          'image_bytes': cache.currentSizeBytes,
          'image_budget_bytes': cache.maximumSizeBytes,
          'image_live': cache.liveImageCount,
          'image_pending': cache.pendingImageCount,
          'rss_bytes': ProcessInfo.currentRss,
        })}',
      );
    });
  }

  static Map<String, Object> _summary(Iterable<int> values) {
    final sorted = values.toList()..sort();
    return {
      'p95_us': sorted[(sorted.length * .95).ceil() - 1],
      'max_us': sorted.last,
      'sum_us': sorted.fold<int>(0, (sum, value) => sum + value),
    };
  }
}
