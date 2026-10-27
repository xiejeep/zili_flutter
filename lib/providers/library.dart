import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/favorites_store.dart';
import '../data/library_repository.dart';
import '../services/syllable_player.dart';

/// The whole bundled library, loaded once.
final libraryProvider = FutureProvider<Library>((ref) => Library.load());

/// Character currently being studied.
final selectedCharProvider = StateProvider<String>((ref) => '你');

/// Shared pronunciation player, disposed with the container.
final syllablePlayerProvider = Provider<SyllablePlayer>((ref) {
  final player = SyllablePlayer();
  ref.onDispose(player.dispose);
  return player;
});

final favoritesStoreProvider = Provider<FavoritesStore>((ref) => FavoritesStore());

/// Favourites, restored from disk on first use and written back on every change.
class FavoritesNotifier extends StateNotifier<List<String>> {
  FavoritesNotifier(this._store) : super(const []) {
    _restore();
  }

  final FavoritesStore _store;
  bool _ready = false;

  bool get ready => _ready;

  Future<void> _restore() async {
    final saved = await _store.load();
    if (!mounted) return;
    _ready = true;
    state = saved;
  }

  bool contains(String char) => state.contains(char);

  void toggle(String char) {
    state = state.contains(char)
        ? (state.where((c) => c != char).toList())
        : [...state, char];
    _store.save(state);
  }

  void remove(String char) {
    state = state.where((c) => c != char).toList();
    _store.save(state);
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<String>>(
  (ref) => FavoritesNotifier(ref.watch(favoritesStoreProvider)),
);
