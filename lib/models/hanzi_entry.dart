/// A single character entry in the learning library.
class HanziEntry {
  const HanziEntry({
    required this.char,
    required this.pinyin,
    required this.plain,
    required this.radical,
    required this.radicalName,
    required this.structure,
    required this.meaning,
    required this.words,
    required this.wordSyllables,
    required this.sentence,
    required this.initial,
    required this.finalSound,
    required this.tone,
    required this.syllable,
    required this.strokeNames,
    required this.strokeCount,
  });

  final String char;
  final String pinyin;

  /// Syllable without the tone mark, used to locate the audio clip.
  final String plain;
  final String radical;
  final String radicalName;
  final String structure;
  final String meaning;
  final List<String> words;

  /// Audio clip names per character of each word, for concatenated playback.
  final List<List<String>> wordSyllables;
  final String sentence;

  /// Initial and final shown in the pinyin breakdown, may be empty.
  final String initial;
  final String finalSound;
  final int tone;
  final String syllable;
  final List<String> strokeNames;
  final int strokeCount;

  bool get isLightTone => tone == 5;

  String get toneLabel => isLightTone ? '轻声' : '$tone 声';

  factory HanziEntry.fromJson(
    Map<String, dynamic> json,
    List<String> names,
    String alphabet,
  ) {
    final codes = json['strokeCodes'] as String;
    return HanziEntry(
      char: json['char'] as String,
      pinyin: json['pinyin'] as String,
      plain: json['plain'] as String,
      radical: json['radical'] as String,
      radicalName: json['radicalName'] as String,
      structure: json['structure'] as String,
      meaning: json['meaning'] as String,
      words: (json['words'] as List).cast<String>(),
      wordSyllables: (json['wordSyllables'] as List)
          .map((e) => (e as List).cast<String>())
          .toList(),
      sentence: json['sentence'] as String,
      initial: json['initial'] as String,
      finalSound: json['final'] as String,
      tone: json['tone'] as int,
      syllable: json['syllable'] as String,
      strokeNames: codes
          .split('')
          .map((code) => names[alphabet.indexOf(code)])
          .toList(),
      strokeCount: json['strokes'] as int,
    );
  }
}
