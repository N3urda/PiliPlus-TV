import 'package:PiliPlus/tv/tv_video_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

class TvVideoGrid extends StatelessWidget {
  const TvVideoGrid({
    super.key,
    required this.videos,
    required this.onOpen,
    this.firstFocusNode,
    this.showPublished = false,
    this.onNearEnd,
    this.onLeftEdge,
  });

  final List<TvVideoEntry> videos;
  final ValueChanged<TvVideoEntry> onOpen;
  final FocusNode? firstFocusNode;
  final bool showPublished;
  final VoidCallback? onNearEnd;
  final ValueChanged<FocusNode>? onLeftEdge;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 850
          ? 6
          : constraints.maxWidth >= 690
          ? 5
          : 4;
      return GridView.builder(
        scrollCacheExtent: const ScrollCacheExtent.pixels(128),
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 14),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 126,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) => TvCinematicVideoCard(
          key: ValueKey(videos[index].bvid),
          video: videos[index],
          focusNode: index == 0 ? firstFocusNode : null,
          showPublished: showPublished,
          onOpen: () => onOpen(videos[index]),
          onLeftEdge: index % columns == 0 ? onLeftEdge : null,
          onFocused: onNearEnd != null && index >= videos.length - columns
              ? onNearEnd
              : null,
        ),
      );
    },
  );
}

class TvCinematicVideoCard extends StatefulWidget {
  const TvCinematicVideoCard({
    super.key,
    required this.video,
    required this.onOpen,
    this.focusNode,
    this.showPublished = false,
    this.onFocused,
    this.onLeftEdge,
  });

  final TvVideoEntry video;
  final VoidCallback onOpen;
  final FocusNode? focusNode;
  final bool showPublished;
  final VoidCallback? onFocused;
  final ValueChanged<FocusNode>? onLeftEdge;

  @override
  State<TvCinematicVideoCard> createState() => _TvCinematicVideoCardState();
}

class _TvCinematicVideoCardState extends State<TvCinematicVideoCard> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final cover = video.cover;
    final imageUrl = cover == null
        ? null
        : cover.startsWith('//')
        ? 'https:$cover'
        : cover;
    final age = widget.showPublished
        ? video.publishedLabel(DateTime.now())
        : null;
    final recent =
        widget.showPublished &&
        video.publishedAt != null &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(video.publishedAt! * 1000),
            ) <
            const Duration(hours: 24);
    final details = [
      ?age,
      ?video.viewsLabel,
    ].join('  ·  ');

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (value) {
        if (mounted) setState(() => focused = value);
        if (value) {
          widget.onFocused?.call();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 150),
                alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
              );
            }
          });
        }
      },
      onKeyEvent: (node, event) {
        if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            widget.onLeftEdge != null) {
          widget.onLeftEdge!(node);
          return KeyEventResult.handled;
        }
        if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          if (event is KeyDownEvent) widget.onOpen();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        button: true,
        label: [
          video.title,
          video.owner,
          details,
        ].where((s) => s.isNotEmpty).join('，'),
        child: GestureDetector(
          onTap: widget.onOpen,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: const Color(0xFF15171B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: focused ? Colors.white : Colors.transparent,
                width: 2,
              ),
              boxShadow: focused
                  ? const [BoxShadow(color: Color(0x88C51D2C), blurRadius: 11)]
                  : null,
            ),
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFF343941)),
                        if (imageUrl != null)
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 420,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.movie_outlined,
                              size: 35,
                              color: Colors.white54,
                            ),
                          ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xE8000000)],
                              stops: [0.4, 1],
                            ),
                          ),
                        ),
                        if (recent)
                          const Positioned(
                            top: 4,
                            left: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFC51D2C),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(3),
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                child: Text(
                                  '新',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (video.durationLabel case final duration?)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Color(0xD8000000),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(3),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                child: Text(
                                  duration,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 4,
                          child: Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.1,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 5),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  video.owner,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: Colors.white),
                ),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
