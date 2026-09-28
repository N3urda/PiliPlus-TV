import 'package:PiliPlus/tv/tv_playback.dart';
import 'package:PiliPlus/tv/tv_video_entry.dart';
import 'package:PiliPlus/tv/tv_thumbnail.dart';
import 'package:PiliPlus/tv/widgets/tv_action.dart';
import 'package:material_ui/material_ui.dart';

class TvVideoCard extends StatelessWidget {
  const TvVideoCard({
    super.key,
    required this.video,
    this.autofocus = false,
    this.focusNode,
    this.width = 285,
    this.compact = false,
  });

  final TvVideoEntry video;
  final bool autofocus;
  final FocusNode? focusNode;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bvid = video.bvid;
    final cover = video.cover;
    final url = cover == null
        ? null
        : cover.startsWith('//')
        ? 'https:$cover'
        : cover;
    return SizedBox(
      width: width,
      child: TvAction(
        autofocus: autofocus,
        focusNode: focusNode,
        onPressed: () {
          if (bvid.isNotEmpty) {
            TvPlayback.open(video);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: compact ? width * 9 / 16 : 145,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    url == null
                        ? const Icon(Icons.movie_outlined, size: 64)
                        : Image(
                            image: tvThumbnailProvider(
                              NetworkImage(url),
                              maxWidth: 560,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.movie_outlined, size: 64),
                          ),
                    if (video.durationLabel case final duration?)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            child: Text(
                              duration,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 15 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                video.owner,
                video.viewsLabel,
              ].where((value) => value != null && value.isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
