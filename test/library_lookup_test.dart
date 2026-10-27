import 'package:flutter_test/flutter_test.dart';
import 'package:zili_flutter/data/library_repository.dart';

/// The lookup behind the search box. Kept to pure data so it can be asserted
/// without a widget tree.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Library library;

  setUpAll(() async => library = await Library.load());

  test('resolves characters in the order typed', () {
    final hits = library.lookup('你好春');

    expect(hits.map((h) => h.char).toList(), ['你', '好', '春']);
    expect(hits.every((h) => h.found), isTrue);
    expect(hits.first.entry!.pinyin, 'nǐ');
  });

  test('stops at eight characters', () {
    // Ten distinct characters, only the first eight should come back.
    final hits = library.lookup('一二三四五六七八九十');

    expect(Library.lookupLimit, 8);
    expect(hits, hasLength(8));
    expect(hits.last.char, '八');
  });

  test('collapses repeats so each character gets one chip', () {
    final hits = library.lookup('你好你好你');

    expect(hits.map((h) => h.char).toList(), ['你', '好']);
  });

  test('ignores whitespace between characters', () {
    final hits = library.lookup(' 你 好\t春\n天 ');

    expect(hits.map((h) => h.char).toList(), ['你', '好', '春', '天']);
  });

  test('characters outside the six textbooks come back as not found', () {
    final hits = library.lookup('你龘好');

    expect(hits, hasLength(3));
    expect(hits[0].found, isTrue);
    expect(hits[1].char, '龘');
    expect(hits[1].found, isFalse);
    expect(hits[1].entry, isNull);
    expect(hits[2].found, isTrue);
  });

  test('a character the library does have is always resolvable', () {
    // Every entry must be findable through the search box.
    for (final entry in library.entries.take(200)) {
      final hits = library.lookup(entry.char);
      expect(hits.single.found, isTrue, reason: '「${entry.char}」查不到');
      expect(hits.single.entry!.char, entry.char);
    }
  });

  test('an empty query yields nothing', () {
    expect(library.lookup(''), isEmpty);
    expect(library.lookup('   '), isEmpty);
  });
}
