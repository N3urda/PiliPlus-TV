import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/tv/widgets/tv_action.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class TvFeatureBanner extends StatelessWidget {
  const TvFeatureBanner({
    super.key,
    required this.video,
    required this.focusNode,
    required this.label,
  });

  final BaseVideoItemModel video;
  final FocusNode focusNode;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cover = video.cover;
    final url = cover == null
        ? null
        : cover.startsWith('//')
        ? 'https:$cover'
        : cover;
    final description = video.desc?.trim();
    final metadata = [
      video.owner.name,
      if (video.stat.view case final views? when views > 0)
        '${NumUtils.numFormat(views)}播放',
      if (video.duration > 0) DurationUtils.formatDuration(video.duration),
    ].where((value) => value != null && value.isNotEmpty).join('   ·   ');

    return Semantics(
      label: '$label，${video.title}，$metadata',
      child: SizedBox(
        height: 195,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF273037)),
              if (url != null)
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  cacheWidth: 1200,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF11191D),
                      Color(0xFA11191D),
                      Color(0xB811191D),
                      Color(0x3011191D),
                    ],
                    stops: [0, 0.37, 0.63, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFF9EE6B5),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        TvAction(
                          focusNode: focusNode,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          onPressed: () {
                            final bvid = video.bvid;
                            if (bvid != null && bvid.isNotEmpty) {
                              Get.toNamed('/tv/detail', arguments: bvid);
                            }
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow, size: 23),
                              SizedBox(width: 5),
                              Text('查看视频', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
