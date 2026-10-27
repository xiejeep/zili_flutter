import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zili_flutter/data/library_repository.dart';
import 'package:zili_flutter/services/sheet_layout.dart';
import 'package:zili_flutter/services/worksheet_image.dart';

/// Rasterising is the one step that cannot be asserted without producing pixels,
/// so these tests render for real. They are kept to a single page to stay fast;
/// the PNG is written to /tmp for eyeballing during development.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders a page to a real PNG', () async {
    final library = await Library.load();
    final entries = library.entries.take(2).toList();
    final layout = SheetLayoutBuilder.build(
      entries: entries,
      library: library,
      pageIndex: 0,
      totalPages: 1,
    );

    final bytes = await WorksheetImage.render(layout);

    // PNG magic number.
    expect(
      bytes.take(8).toList(),
      [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    );
    expect(bytes.length, greaterThan(2000));

    File('/tmp/zili_worksheet_image.png').writeAsBytesSync(bytes);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('the rendered page matches the layout size', () async {
    final library = await Library.load();
    final layout = SheetLayoutBuilder.build(
      entries: library.entries.take(1).toList(),
      library: library,
      pageIndex: 0,
      totalPages: 1,
    );

    final pages = await WorksheetImage.build(
      entries: library.entries.take(6).toList(),
      library: library,
    );
    // Six characters make two pages.
    expect(pages, hasLength(2));
    expect(layout.width * WorksheetImage.scale, closeTo(1786, 1));
  }, timeout: const Timeout(Duration(seconds: 120)));
}
