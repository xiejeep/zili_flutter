import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hanzi_entry.dart';
import '../providers/library.dart';
import '../theme/app_theme.dart';
import '../widgets/worksheet_export_sheet.dart';

/// The saved characters, tap one to study it.
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  Future<void> _exportAll(List<HanziEntry> entries) async {
    if (entries.isEmpty) return;
    await showWorksheetExportSheet(context, ref, entries);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的生字本'),
        actions: [
          if (favorites.isNotEmpty)
            TextButton(
              onPressed: () => _exportAll(_entries(favorites)),
              child: const Text('保存字帖'),
            ),
        ],
      ),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('字库加载失败：$e')),
        data: (data) => _buildBody(favorites, data),
      ),
    );
  }

  List<HanziEntry> _entries(List<String> favorites) {
    final library = ref.read(libraryProvider).valueOrNull;
    if (library == null) return const [];
    return favorites
        .map((c) => library.find(c))
        .whereType<HanziEntry>()
        .toList();
  }

  Widget _buildBody(List<String> favorites, dynamic data) {
    if (favorites.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '把想练习的字加入收藏，就能在这里找到它。',
            textAlign: TextAlign.center,
            style: TextStyle(color: ZiliColors.inkSoft),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            '共 ${favorites.length} 个字',
            style: const TextStyle(fontSize: 13, color: ZiliColors.inkSoft),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemCount: favorites.length,
            itemBuilder: (context, i) {
              final char = favorites[i];
              final entry = data.find(char) as HanziEntry?;
              return GestureDetector(
                onTap: () {
                  ref.read(selectedCharProvider.notifier).state = char;
                  Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZiliColors.line),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        char,
                        style: const TextStyle(
                            fontSize: 30, fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry?.pinyin ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: ZiliColors.inkSoft),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => ref
                            .read(favoritesProvider.notifier)
                            .remove(char),
                        child: const Text(
                          '移除',
                          style: TextStyle(
                              fontSize: 11, color: ZiliColors.inkFaint),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
