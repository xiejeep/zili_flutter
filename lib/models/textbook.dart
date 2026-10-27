/// One textbook volume with its writing list grouped by lesson.
class Textbook {
  const Textbook({
    required this.id,
    required this.title,
    required this.source,
    required this.chars,
    required this.checked,
  });

  final String id;
  final String title;
  final String source;
  final List<String> chars;
  final bool checked;

  factory Textbook.fromJson(Map<String, dynamic> json) => Textbook(
        id: json['id'] as String,
        title: json['title'] as String,
        source: (json['source'] ?? '') as String,
        chars: (json['chars'] as List).cast<String>(),
        checked: (json['checked'] ?? false) as bool,
      );
}
