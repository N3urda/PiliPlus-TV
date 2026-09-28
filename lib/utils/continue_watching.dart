import 'package:PiliPlus/models_new/history/list.dart';

abstract final class ContinueWatching {
  static String key(HistoryItemModel item) {
    final history = item.history;
    return history.business == 'pgc'
        ? 'pgc:${history.epid}'
        : 'archive:${history.oid ?? history.bvid}:${history.cid ?? history.page}';
  }

  static List<HistoryItemModel> select(Iterable<HistoryItemModel> history) {
    final seen = <String>{};
    return history
        .where((item) {
          final progress = item.progress ?? 0;
          final duration = item.duration ?? 0;
          final playable = switch (item.history.business) {
            'archive' => item.history.oid != null || item.history.bvid != null,
            'pgc' => item.history.epid != null,
            _ => false,
          };
          return playable &&
              progress > 0 &&
              (duration == 0 || progress < duration) &&
              seen.add(key(item));
        })
        .take(10)
        .toList();
  }
}
