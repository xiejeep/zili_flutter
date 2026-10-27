import 'package:flutter_test/flutter_test.dart';
import 'package:zili_flutter/data/library_repository.dart';
import 'package:zili_flutter/models/hanzi_entry.dart';
import 'package:zili_flutter/services/sheet_layout.dart';

/// The layout is pure geometry, so it can be asserted without rendering. That
/// matters here: rasterising hangs in this environment (see docs/PROGRESS.md),
/// so this is the only way to check the sheet actually holds what it should.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Library library;

  setUpAll(() async => library = await Library.load());

  List<HanziEntry> take(int n) => library.entries.take(n).toList();

  SheetLayout page(int count, {int index = 0}) {
    final entries = take(count);
    return SheetLayoutBuilder.build(
      entries: entries,
      library: library,
      pageIndex: index,
      totalPages: SheetLayoutBuilder.pageCount(entries.length),
    );
  }

  test('packs five characters per page', () {
    expect(SheetLayoutBuilder.pageCount(0), 0);
    expect(SheetLayoutBuilder.pageCount(1), 1);
    expect(SheetLayoutBuilder.pageCount(5), 1);
    expect(SheetLayoutBuilder.pageCount(6), 2);
    expect(SheetLayoutBuilder.pageCount(250), 50);
  });

  test('a full page carries every cell and glyph', () {
    final layout = page(5);

    // Two rows of ten cells for each of the five characters.
    expect(layout.ops.whereType<SheetRect>().length, 5 * 2 * 10);
    expect(layout.ops.whereType<SheetDashedRule>().length, 5 * 2 * 10 * 2);
    // One label glyph plus three traced cells per character.
    expect(layout.ops.whereType<SheetGlyph>().length, 5 * 4);
  });

  test('a short page only draws the characters it has', () {
    final layout = page(2);
    expect(layout.ops.whereType<SheetRect>().length, 2 * 2 * 10);
    expect(layout.ops.whereType<SheetGlyph>().length, 2 * 4);
  });

  test('header and footer carry the expected wording', () {
    final texts = page(1).texts;
    expect(texts, contains('字里 · 汉字练习'));
    expect(texts, contains('姓名：'));
    expect(texts, contains('日期：'));
    expect(texts, contains('先描红，再独立书写。一笔一画，每天进步一点点。'));
    expect(texts, contains('1 / 1'));
  });

  test('the page number follows the page index', () {
    final entries = take(12); // three pages
    final layout = SheetLayoutBuilder.build(
      entries: entries,
      library: library,
      pageIndex: 2,
      totalPages: 3,
    );
    expect(layout.texts, contains('3 / 3'));
    // The last page holds the remaining two characters.
    expect(layout.ops.whereType<SheetGlyph>().length, 2 * 4);
  });

  test('the pinyin label mixes faces so both renderers can split it', () {
    final entries = take(1);
    final label = page(1)
        .ops
        .whereType<SheetText>()
        .firstWhere((op) => op.spans.any((s) => s.text == '笔'));

    expect(label.spans.first.role, SheetFontRole.latin);
    expect(label.spans.last.role, SheetFontRole.cjk);
    expect(label.spans.first.text, contains(entries.first.pinyin));
    expect(label.spans.first.text, contains('${entries.first.strokeCount}'));
  });

  test('nothing is drawn outside the page', () {
    final layout = page(5);
    // A4 in points, with a small tolerance for the cell borders.
    const w = SheetLayoutBuilder.pageWidth;
    const h = SheetLayoutBuilder.pageHeight;

    for (final op in layout.ops) {
      switch (op) {
        case SheetText():
          expect(op.x, inInclusiveRange(0, w));
          expect(op.y, inInclusiveRange(0, h));
        case SheetRect():
          expect(op.rect.x, greaterThanOrEqualTo(0));
          expect(op.rect.y, greaterThanOrEqualTo(0));
          expect(op.rect.x + op.rect.width, lessThanOrEqualTo(w + 0.5));
          expect(op.rect.y + op.rect.height, lessThanOrEqualTo(h + 0.5));
        case SheetGlyph():
          expect(op.origin.x, greaterThanOrEqualTo(0));
          expect(op.origin.y, greaterThanOrEqualTo(0));
        case SheetRule():
          expect(op.from.y, inInclusiveRange(0, h));
          expect(op.to.y, inInclusiveRange(0, h));
        case SheetDashedRule():
          expect(op.from.y, inInclusiveRange(0, h));
          expect(op.to.y, inInclusiveRange(0, h));
      }
    }
  });
}
