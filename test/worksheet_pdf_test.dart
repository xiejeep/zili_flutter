import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zili_flutter/data/library_repository.dart';
import 'package:zili_flutter/services/worksheet_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a valid multi page worksheet', () async {
    final library = await Library.load();
    final entries = ['你', '好', '春', '江', '国', '思']
        .map((c) => library.find(c)!)
        .toList();

    final bytes = await WorksheetPdf.build(entries: entries, library: library);

    // PDF header and a sane size for six characters across two pages.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(2000));

    // Handy for eyeballing the layout during development.
    File('/tmp/zili_worksheet.pdf').writeAsBytesSync(bytes);
  });

  test('handles a full page without overflowing', () async {
    final library = await Library.load();
    final entries = library.entries.take(10).toList();

    final bytes = await WorksheetPdf.build(entries: entries, library: library);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
