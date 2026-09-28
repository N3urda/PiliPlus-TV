import 'package:PiliPlus/common/widgets/tv/tv_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('new routes automatically focus an action without an extra key', (
    tester,
  ) async {
    final first = FocusNode();
    final destination = FocusNode();
    addTearDown(first.dispose);
    addTearDown(destination.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [TvNavigationObserver()],
        builder: (context, child) => TvNavigation(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              autofocus: true,
              focusNode: first,
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      focusNode: destination,
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Return'),
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(destination.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(first.hasPrimaryFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('D-pad scrolls a list in both directions without losing focus', (
    tester,
  ) async {
    final nodes = List.generate(30, (_) => FocusNode());
    final scroll = ScrollController();
    addTearDown(() {
      for (final node in nodes) {
        node.dispose();
      }
      scroll.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TvNavigation(child: child!),
        home: Scaffold(
          body: ListView(
            controller: scroll,
            itemExtent: 80,
            children: [
              for (var i = 0; i < nodes.length; i++)
                TextButton(
                  focusNode: nodes[i],
                  onPressed: () {},
                  child: Text('Item $i'),
                ),
            ],
          ),
        ),
      ),
    );
    nodes.first.requestFocus();
    await tester.pumpAndSettle();
    for (var i = 0; i < 15; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(nodes[15].hasFocus, isTrue);
    expect(scroll.offset, greaterThan(0));
    for (var i = 0; i < 15; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
    }
    expect(nodes.first.hasFocus, isTrue);
    expect(scroll.offset, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'D-pad selects buttons and returning from a dialog restores focus',
    (tester) async {
      final first = FocusNode();
      final second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      var activations = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [TvNavigationObserver()],
          builder: (context, child) => TvNavigation(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      focusNode: first,
                      onPressed: () => activations++,
                      child: const Text('Play'),
                    ),
                    ElevatedButton(
                      focusNode: second,
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          actions: [
                            TextButton(
                              autofocus: true,
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                      child: const Text('Settings'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      first.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(activations, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(second.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(second.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
