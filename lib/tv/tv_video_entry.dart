import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';

/// The fields shared by recommendation, search, and following-video cards.
class TvVideoEntry {
  const TvVideoEntry({
    required this.bvid,
    required this.title,
    required this.owner,
    this.cover,
    this.cid,
    this.durationLabel,
    this.viewsLabel,
    this.publishedAt,
  });

  final String bvid;
  final String title;
  final String owner;
  final String? cover;
  final int? cid;
  final String? durationLabel;
  final String? viewsLabel;
  final int? publishedAt;

  factory TvVideoEntry.fromVideo(BaseVideoItemModel video) => TvVideoEntry(
    bvid: video.bvid!,
    title: video.title,
    owner: video.owner.name ?? '',
    cover: video.cover,
    cid: video.cid,
    durationLabel: video.duration > 0
        ? DurationUtils.formatDuration(video.duration)
        : null,
    viewsLabel: video.stat.view != null && video.stat.view! >= 0
        ? '${NumUtils.numFormat(video.stat.view!)}播放'
        : null,
    publishedAt: video.pubdate,
  );

  String? publishedLabel(DateTime now) {
    final timestamp = publishedAt;
    if (timestamp == null || timestamp <= 0) return null;
    final age = now.difference(
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    );
    if (age.isNegative || age.inMinutes < 1) return '刚刚';
    if (age.inHours < 1) return '${age.inMinutes}分钟前';
    if (age.inDays < 1) return '${age.inHours}小时前';
    if (age.inDays < 7) return '${age.inDays}天前';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.month}月${date.day}日';
  }
}

/// Video-only TV scope: an original archive posted by a followed creator.
List<TvVideoEntry> tvFollowingVideos(List<DynamicItemModel> items) {
  final seen = <String>{};
  final videos = <TvVideoEntry>[];
  for (final item in items) {
    if (item.type != 'DYNAMIC_TYPE_AV' || item.orig != null) continue;
    final archive = item.modules.moduleDynamic?.major?.archive;
    final bvid = archive?.bvid;
    if (bvid == null || !bvid.startsWith('BV') || !seen.add(bvid)) continue;
    final play = archive?.stat?.play;
    videos.add(
      TvVideoEntry(
        bvid: bvid,
        title: archive?.title ?? bvid,
        owner: item.modules.moduleAuthor?.name ?? '',
        cover: archive?.cover,
        durationLabel: archive?.durationText,
        viewsLabel: play == null || play.isEmpty ? null : '$play播放',
        publishedAt: item.modules.moduleAuthor?.pubTs,
      ),
    );
  }
  return videos;
}
