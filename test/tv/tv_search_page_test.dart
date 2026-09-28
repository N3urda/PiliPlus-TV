import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/tv/pages/tv_search_page.dart';
import 'package:PiliPlus/tv/tv_video_entry.dart';
import 'package:PiliPlus/tv/widgets/tv_search_results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'search keeps compact unique results and stops on an empty page',
    (
      tester,
    ) async {
      final requestedPages = <int>[];
      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData.dark(),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: TvSearchPage(
            searchLoader: (keyword, page) async {
              requestedPages.add(page);
              return Success(
                SearchVideoData(
                  numResults: 1000,
                  list: page == 3
                      ? []
                      : [
                          SearchVideoItemModel.fromJson({
                            'title': '搜索视频 $page',
                            'bvid': 'BV$page',
                            'author': 'UP',
                            'duration': '01:00',
                            'description': 'unneeded description ' * 1000,
                          }),
                          SearchVideoItemModel.fromJson({
                            'title': '搜索视频 1',
                            'bvid': 'BV1',
                            'author': 'UP',
                            'duration': '01:00',
                          }),
                        ],
                ),
              );
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '测试');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      var results = tester.widget<TvSearchResults>(
        find.byType(TvSearchResults),
      );
      expect(results.results, everyElement(isA<TvVideoEntry>()));
      expect(results.results, hasLength(1));
      results.onLoadMore();
      await tester.pumpAndSettle();
      results = tester.widget<TvSearchResults>(find.byType(TvSearchResults));
      expect(results.results.map((video) => video.bvid), ['BV1', 'BV2']);
      results.onLoadMore();
      await tester.pumpAndSettle();
      results = tester.widget<TvSearchResults>(find.byType(TvSearchResults));
      expect(results.hasMore, isFalse);
      results.onLoadMore();
      await tester.pumpAndSettle();
      expect(requestedPages, [1, 2, 3]);
      expect(results.results.map((video) => video.bvid), ['BV1', 'BV2']);
    },
  );

  testWidgets(
    'TV search screen renders a usable text field with app localizations',
    (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData.dark(),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const TvSearchPage(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('搜索视频'), findsOneWidget);
    },
  );
}
