import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists the favourites list as a small JSON file in the app documents
/// directory.
///
/// Storage failures are swallowed on purpose: a read-only or missing directory
/// should degrade to an in-memory list rather than break the study screen.
class FavoritesStore {
  static const String _fileName = 'zili_favorites.json';

  File? _cached;

  Future<File> _file() async {
    final cached = _cached;
    if (cached != null) return cached;
    final dir = await getApplicationDocumentsDirectory();
    return _cached = File('${dir.path}/$_fileName');
  }

  Future<List<String>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const [];
      final decoded = json.decode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<String> chars) async {
    try {
      final file = await _file();
      await file.writeAsString(json.encode(chars));
    } catch (_) {
      // Keep the in-memory state, persistence is best effort.
    }
  }
}
