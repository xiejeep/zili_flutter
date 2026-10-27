import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/library_repository.dart';
import '../models/hanzi_entry.dart';
import '../providers/library.dart';
import '../theme/app_theme.dart';

/// Browsing the library, either by textbook volume or by stroke count.
///
/// The textbook volumes only cover the writing lists of grades 1–3, so the
/// library also carries the rest of the level-1 characters (the national
/// standard's 3500). Those have no volume to live in, hence the second mode.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

/// Stroke-count buckets for the "all characters" mode.
const _strokeBuckets = <(String, int, int)>[
  ('全部', 0, 99),
  ('1–4 画', 1, 4),
  ('5–6 画', 5, 6),
  ('7–8 画', 7, 8),
  ('9–10 画', 9, 10),
  ('11–12 画', 11, 12),
  ('13 画以上', 13, 99),
];

class _LibraryPageState extends ConsumerState<LibraryPage> {
  int _mode = 0;
  int _book = 0;
  int _bucket = 0;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('字库')),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('字库加载失败：$e')),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modeSwitch(data.entries.length, data.textbooks.length),
            Expanded(
              child: _mode == 0
                  ? _byTextbook(data)
                  : _byStrokeCount(data.entries),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeSwitch(int total, int books) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _segmented('教材册次', 0, '$books 册'),
          const SizedBox(width: 8),
          _segmented('全部常用字', 1, '$total 字'),
        ],
      ),
    );
  }

  Widget _segmented(String label, int value, String note) {
    final on = _mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? ZiliColors.cinnabarSoft : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: on ? ZiliColors.cinnabar : ZiliColors.line,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: on ? ZiliColors.cinnabar : ZiliColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                note,
                style: const TextStyle(fontSize: 11, color: ZiliColors.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ---------- 教材册次 ---------- */

  Widget _byTextbook(Library data) {
    final book = data.textbooks[_book];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < data.textbooks.length; i++)
                _chip(
                  data.textbooks[i].title,
                  _book == i,
                  () => setState(() => _book = i),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            '${book.title} · 写字表 ${book.chars.length} 字',
            style: const TextStyle(fontSize: 13, color: ZiliColors.inkSoft),
          ),
        ),
        Expanded(child: _grid(book.chars)),
      ],
    );
  }

  /* ---------- 全部常用字 ---------- */

  Widget _byStrokeCount(List<HanziEntry> entries) {
    final (label, lo, hi) = _strokeBuckets[_bucket];
    final chars = entries
        .where((e) => e.strokeCount >= lo && e.strokeCount <= hi)
        .map((e) => e.char)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _strokeBuckets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _chip(
              _strokeBuckets[i].$1,
              _bucket == i,
              () => setState(() => _bucket = i),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            '$label · ${chars.length} 字',
            style: const TextStyle(fontSize: 13, color: ZiliColors.inkSoft),
          ),
        ),
        Expanded(child: _grid(chars)),
      ],
    );
  }

  /* ---------- shared ---------- */

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? ZiliColors.cinnabarSoft : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? ZiliColors.cinnabar : ZiliColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(color: on ? ZiliColors.cinnabar : ZiliColors.ink),
        ),
      ),
    );
  }

  Widget _grid(List<String> chars) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: chars.length,
      itemBuilder: (context, i) {
        final char = chars[i];
        return GestureDetector(
          onTap: () {
            ref.read(selectedCharProvider.notifier).state = char;
            Navigator.of(context).pop();
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZiliColors.line),
            ),
            alignment: Alignment.center,
            child: Text(
              char,
              style: const TextStyle(fontSize: 26, fontFamily: 'serif'),
            ),
          ),
        );
      },
    );
  }
}
