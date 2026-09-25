import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/tv/widgets/tv_action.dart';
import 'package:PiliPlus/tv/widgets/tv_video_card.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:material_ui/material_ui.dart';

class TvSearchResults extends StatelessWidget {
  const TvSearchResults({
    super.key,
    required this.results,
    required this.total,
    required this.loading,
    required this.onLoadMore,
    required this.firstResultFocus,
  });

  final List<SearchVideoItemModel> results;
  final int total;
  final bool loading;
  final VoidCallback onLoadMore;
  final FocusNode firstResultFocus;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 780
          ? 3
          : constraints.maxWidth >= 520
          ? 2
          : 1;
      return CustomScrollView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(128),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '搜索结果 · 共 $total 条',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 20),
            sliver: SliverGrid.builder(
              itemCount: results.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 250,
                crossAxisSpacing: 16,
                mainAxisSpacing: 18,
              ),
              itemBuilder: (context, index) => TvVideoCard(
                video: results[index],
                width: double.infinity,
                focusNode: index == 0 ? firstResultFocus : null,
              ),
            ),
          ),
          if (results.length < total)
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TvAction(
                  onPressed: onLoadMore,
                  child: Text(
                    loading ? '加载中…' : '加载更多',
                    style: const TextStyle(fontSize: 21),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
