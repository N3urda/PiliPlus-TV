import 'package:PiliPlus/tv/pages/tv_search_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
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
