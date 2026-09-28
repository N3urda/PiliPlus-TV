import 'package:PiliPlus/common/widgets/tv/tv_navigation.dart';
import 'package:PiliPlus/pages/search/widgets/tv_search_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('D-pad can pass the keyboard entry to reach phone input', (
    tester,
  ) async {
    final controller = TextEditingController();
    final phone = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(phone.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [TvNavigationObserver()],
        builder: (context, child) => TvNavigation(child: child!),
        home: Scaffold(
          body: Row(
            children: [
              TvSearchField(
                controller: controller,
                onChanged: (_) {},
                onSubmit: () {},
              ),
              TextButton(
                focusNode: phone,
                onPressed: () {},
                child: const Text('Phone'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(phone.hasPrimaryFocus, isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
