import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zili_flutter/data/library_repository.dart';
import 'package:zili_flutter/painters/stroke_thumbnail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Note: widget tests that pump a tree hang in this environment, so the
  // painting entry point is exercised directly instead.

  test('paints every stroke of a glyph without error', () async {
    final library = await Library.load();
    final glyph = library.glyph('你')!;
    expect(glyph.strokeCount, 7);

    for (var i = 0; i < glyph.strokeCount; i++) {
      final recorder = ui.PictureRecorder();
      paintStrokeThumbnail(Canvas(recorder), const Size(38, 38), glyph, i);
      expect(recorder.endRecording(), isNotNull, reason: '第 ${i + 1} 笔');
    }
  });

  test('paints every stroke of every glyph', () async {
    final library = await Library.load();
    for (final entry in library.entries) {
      final glyph = library.glyph(entry.char);
      if (glyph == null) continue;
      for (var i = 0; i < glyph.strokeCount; i++) {
        final recorder = ui.PictureRecorder();
        paintStrokeThumbnail(Canvas(recorder), const Size(38, 38), glyph, i);
        recorder.endRecording();
      }
    }
  });

  test('ignores an out of range index', () async {
    final library = await Library.load();
    final glyph = library.glyph('你')!;
    final recorder = ui.PictureRecorder();
    paintStrokeThumbnail(Canvas(recorder), const Size(38, 38), glyph, 99);
    expect(recorder.endRecording(), isNotNull);
  });
}
