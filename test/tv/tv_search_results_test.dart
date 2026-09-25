import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/tv/widgets/tv_search_results.dart';
import 'package:PiliPlus/tv/widgets/tv_video_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('large search result sets build only nearby video cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final results = List.generate(
      80,
      (index) => SearchVideoItemModel.fromJson({
        'title': '视频 $index',
        'bvid': 'BV$index',
        'author': 'UP',
        'duration': '01:00',
        'play': index,
      }),
    );
    final firstResultFocus = FocusNode();
    addTearDown(firstResultFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSearchResults(
            results: results,
            total: results.length,
            loading: false,
            onLoadMore: () {},
            firstResultFocus: firstResultFocus,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TvVideoCard).evaluate().length, lessThan(12));
  });
}
