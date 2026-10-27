import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zili_flutter/data/library_repository.dart';
import 'package:zili_flutter/providers/library.dart';
import 'package:zili_flutter/widgets/hanzi_search.dart';

/// Exercises the search box the way a parent would use it: type a few
/// characters, and the page follows the first one straight away.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Library library;

  setUpAll(() async => library = await Library.load());

  Future<void> pumpSearch(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: HanziSearch(library: library)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String selectedIn(WidgetTester tester) => ProviderScope.containerOf(
        tester.element(find.byType(HanziSearch)),
      ).read(selectedCharProvider);

  /// `find.text` also matches the text field's own contents, which would make
  /// a single character query ambiguous. Chips are plain [Text] widgets.
  Finder chip(String char) =>
      find.byWidgetPredicate((w) => w is Text && w.data == char);

  testWidgets('typing a character produces a chip for it', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '你好春天');
    await tester.pumpAndSettle();

    for (final char in ['你', '好', '春', '天']) {
      expect(chip(char), findsOneWidget, reason: '缺少「$char」的按钮');
    }
    expect(find.text('未收录'), findsNothing);
  });

  testWidgets('characters the library lacks are marked, not dropped',
      (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '你龘好');
    await tester.pumpAndSettle();

    expect(chip('龘'), findsOneWidget);
    expect(find.text('未收录'), findsOneWidget);
    expect(find.textContaining('「龘」暂未收录'), findsOneWidget);
  });

  testWidgets('typing jumps to the first covered character', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '春天');
    await tester.pumpAndSettle();

    expect(selectedIn(tester), '春');
  });

  testWidgets('an uncovered first character does not block the jump',
      (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '龘好');
    await tester.pumpAndSettle();

    expect(selectedIn(tester), '好');
  });

  testWidgets('tapping a chip switches the studied character', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '你好');
    await tester.pumpAndSettle();

    await tester.tap(chip('好'));
    await tester.pumpAndSettle();

    expect(selectedIn(tester), '好');
  });

  testWidgets('an unlisted character cannot be tapped', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '龘');
    await tester.pumpAndSettle();

    final before = selectedIn(tester);
    await tester.tap(chip('龘'));
    await tester.pumpAndSettle();

    expect(selectedIn(tester), before);
  });

  testWidgets('the field stops at eight characters', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '一二三四五六七八九十');
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.characters.length, Library.lookupLimit);
    expect(field.controller!.text, '一二三四五六七八');

    // Eight chips, one per character.
    for (final char in '一二三四五六七八'.split('')) {
      expect(chip(char), findsOneWidget);
    }
    expect(chip('十'), findsNothing);
  });

  testWidgets('clearing removes every chip', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '你好');
    await tester.pumpAndSettle();
    expect(chip('你'), findsOneWidget);

    await tester.tap(find.byTooltip('清空'));
    await tester.pumpAndSettle();

    expect(chip('你'), findsNothing);
    expect(chip('好'), findsNothing);
  });
}
