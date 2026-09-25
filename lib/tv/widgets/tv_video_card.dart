import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/tv/widgets/tv_action.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TvVideoCard extends StatelessWidget {
  const TvVideoCard({super.key, required this.video, this.autofocus = false});

  final BaseVideoItemModel video;
  final bool autofocus;

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
      width: 285,
      child: TvAction(
        autofocus: autofocus,
        onPressed: () {
          if (bvid != null && bvid.isNotEmpty) {
            Get.toNamed('/tv/detail', arguments: bvid);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 145,
                width: double.infinity,
                child: url == null
                    ? const Icon(Icons.movie_outlined, size: 64)
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.movie_outlined, size: 64),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              video.owner.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
            ),
          ],
        ),
      ),
    );
  }
}
