import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/hanzi_entry.dart';
import '../models/textbook.dart';
import 'stroke_codec.dart';

/// One item of a lookup: the character the user asked for, plus what the
/// library has for it. [entry] is null when the character is not covered.
class LookupHit {
  const LookupHit(this.char, this.entry);

  final String char;
  final HanziEntry? entry;

  bool get found => entry != null;
}

/// The whole learning library, loaded once from bundled assets.
class Library {
  const Library({
    required this.entries,
    required this.byChar,
    required this.textbooks,
    required this.packedStrokes,
  });

  final List<HanziEntry> entries;
  final Map<String, HanziEntry> byChar;
  final List<Textbook> textbooks;
  final Map<String, String> packedStrokes;

  HanziEntry? find(String char) => byChar[char];

  /// The most characters one lookup may carry.
  static const int lookupLimit = 8;

  /// Resolves what the user typed into a list of hits, in the order typed.
  ///
  /// Whitespace is dropped and repeats are collapsed, so a pasted phrase still
  /// yields one chip per distinct character. Capped at [limit]; characters the
  /// library does not cover come back with a null entry rather than being
  /// silently dropped, so the UI can say so.
  List<LookupHit> lookup(String input, {int limit = lookupLimit}) {
    final hits = <LookupHit>[];
    final seen = <String>{};
    for (final rune in input.runes) {
      if (hits.length >= limit) break;
      final char = String.fromCharCode(rune);
      if (char.trim().isEmpty) continue;
      if (!seen.add(char)) continue;
      hits.add(LookupHit(char, byChar[char]));
    }
    return hits;
  }

  /// Stroke data is decoded on demand and cached; decoding all 3500 glyphs up
  /// front would waste memory.
  StrokeGlyph? glyph(String char) {
    final packed = packedStrokes[char];
    if (packed == null) return null;
    return _cache.putIfAbsent(char, () => StrokeCodec.decode(packed));
  }

  static final Map<String, StrokeGlyph> _cache = {};

  static Future<Library> load() async {
    final catalogRaw = await rootBundle.loadString('assets/data/catalog.json');
    final namesRaw = await rootBundle.loadString('assets/data/stroke_names.json');
    final codesRaw = await rootBundle.loadString('assets/data/stroke_codes.json');
    final strokesRaw = await rootBundle.loadString('assets/data/strokes.json');
    final booksRaw = await rootBundle.loadString('assets/data/curriculum.json');

    final names = (json.decode(namesRaw) as List).cast<String>();
    final alphabet = json.decode(codesRaw) as String;
    final entries = (json.decode(catalogRaw) as List)
        .map((e) => HanziEntry.fromJson(e as Map<String, dynamic>, names, alphabet))
        .toList();
    final textbooks = (json.decode(booksRaw) as List)
        .map((e) => Textbook.fromJson(e as Map<String, dynamic>))
        .toList();
    final packed = (json.decode(strokesRaw) as Map).cast<String, String>();

    return Library(
      entries: entries,
      byChar: {for (final e in entries) e.char: e},
      textbooks: textbooks,
      packedStrokes: packed,
    );
  }
}
