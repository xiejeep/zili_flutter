import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zili_flutter/data/stroke_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes a known glyph with the expected stroke count', () async {
    final raw = await rootBundle.loadString('assets/data/strokes.json');
    final packed = (json.decode(raw) as Map).cast<String, String>();

    final ni = StrokeCodec.decode(packed['你']!);
    expect(ni.strokeCount, 7);
    expect(ni.medians.length, 7);

    final hao = StrokeCodec.decode(packed['好']!);
    expect(hao.strokeCount, 6);
    expect(hao.medians.length, 6);
  });

  test('every packed glyph decodes without error', () async {
    final strokesRaw = await rootBundle.loadString('assets/data/strokes.json');
    final packed = (json.decode(strokesRaw) as Map).cast<String, String>();

    // The stroke table must cover every catalog entry — that pairing is the
    // thing worth asserting, not a literal count that goes stale on expansion.
    final catalogRaw = await rootBundle.loadString('assets/data/catalog.json');
    final catalog = json.decode(catalogRaw) as List;
    expect(packed.length, catalog.length);
    expect(packed.length, greaterThan(1000));

    for (final entry in packed.entries) {
      final glyph = StrokeCodec.decode(entry.value);
      expect(glyph.strokeCount, greaterThan(0), reason: entry.key);
      expect(glyph.medians.length, glyph.strokeCount, reason: entry.key);
    }
  });
}
