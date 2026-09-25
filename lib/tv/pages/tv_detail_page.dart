import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/tv/widgets/tv_action.dart';
import 'package:PiliPlus/tv/widgets/tv_video_row.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class TvDetailPage extends StatefulWidget {
  const TvDetailPage({super.key});

  @override
  State<TvDetailPage> createState() => _TvDetailPageState();
}

class _TvDetailPageState extends State<TvDetailPage> {
  late final String bvid = Get.arguments as String;
  VideoDetailData? detail;
  List<HotVideoItemModel> related = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
    loadRelated();
  }

  Future<void> loadRelated() async {
    try {
      final result = await VideoHttp.relatedVideoList(bvid: bvid);
      if (!mounted) return;
      setState(() => related = result.dataOrNull ?? []);
    } catch (_) {
      // Related videos are optional; the detail and playback remain usable.
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await VideoHttp.videoIntro(bvid: bvid);
      if (!mounted) return;
      setState(() {
        detail = result.dataOrNull;
        error = result is Error ? result.toString() : null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '$e';
        loading = false;
      });
    }
  }

  void play([Part? part]) {
    final video = detail;
    final cid = part?.cid ?? video?.cid;
    if (video == null || cid == null) return;
    PageUtils.toVideoPage(
      bvid: bvid,
      cid: cid,
      cover: video.pic,
      title: video.title,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF10181C),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(54, 28, 54, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvAction(
              onPressed: Get.back,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back),
                  SizedBox(width: 8),
                  Text('返回'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (detail == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '视频信息加载失败：${error ?? '未知错误'}',
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 16),
                      TvAction(
                        onPressed: load,
                        child: const Text('重试', style: TextStyle(fontSize: 20)),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildContent(detail!)),
          ],
        ),
      ),
    ),
  );

  Widget _buildContent(VideoDetailData video) {
    final parts = video.pages ?? [];
    final cover = video.pic;
    final published = video.pubdate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(video.pubdate! * 1000);
    final facts = [
      if (video.stat?.view case final views? when views > 0)
        '${NumUtils.numFormat(views)}播放',
      if (video.stat?.danmaku case final danmaku? when danmaku > 0)
        '${NumUtils.numFormat(danmaku)}弹幕',
      if (video.duration case final duration? when duration > 0)
        '时长 ${DurationUtils.formatDuration(duration)}',
      if (published != null)
        '${published.year}-${published.month.toString().padLeft(2, '0')}-${published.day.toString().padLeft(2, '0')}',
    ];
    return ListView(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 390,
              height: 220,
              child: cover == null
                  ? const Icon(Icons.movie_outlined, size: 80)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        cover,
                        fit: BoxFit.cover,
                        cacheWidth: 900,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.movie_outlined, size: 80),
                      ),
                    ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title ?? bvid,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    video.owner?.name ?? '',
                    style: const TextStyle(fontSize: 19),
                  ),
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      facts.join('   ·   '),
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (video.desc?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    Text(
                      video.desc!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  TvAction(
                    autofocus: true,
                    onPressed: play,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 28),
                        SizedBox(width: 8),
                        Text('立即播放', style: TextStyle(fontSize: 23)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (parts.length > 1) ...[
          const SizedBox(height: 34),
          const Text(
            '选集',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final part in parts)
                TvAction(
                  onPressed: () => play(part),
                  child: SizedBox(
                    width: 220,
                    child: Text(
                      '${part.page ?? parts.indexOf(part) + 1}. ${part.part ?? '视频'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (related.isNotEmpty) ...[
          const SizedBox(height: 30),
          TvVideoRow(title: '相关视频', videos: related),
        ],
      ],
    );
  }
}
