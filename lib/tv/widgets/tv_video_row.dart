import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/tv/widgets/tv_video_card.dart';
import 'package:material_ui/material_ui.dart';

class TvVideoRow extends StatelessWidget {
  const TvVideoRow({super.key, required this.title, required this.videos});

  final String title;
  final List<BaseVideoItemModel> videos;

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 96;
    final cardWidth = ((availableWidth - 42) / 4).clamp(178.0, 245.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Text(
              '${videos.length} 条视频',
              style: const TextStyle(fontSize: 14, color: Colors.white60),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 207,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: videos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) => TvVideoCard(
              video: videos[index],
              width: cardWidth,
              compact: true,
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
