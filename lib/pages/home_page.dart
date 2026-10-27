import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/library_repository.dart';
import '../models/hanzi_entry.dart';
import '../painters/hanzi_board.dart';
import '../painters/stroke_thumbnail.dart';
import '../providers/library.dart';
import '../theme/app_theme.dart';
import '../widgets/hanzi_search.dart';
import '../widgets/worksheet_export_sheet.dart';
import 'favorites_page.dart';
import 'textbook_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _board = HanziBoardController();
  String? _loadedChar;
  int _tab = 0;
  int _selectedStroke = -1;
  double _speed = 1;

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  /// Queues bundled syllable clips and surfaces playback failures once.
  void _playSyllables(List<String> clips) {
    final player = ref.read(syllablePlayerProvider);
    player.playSequence(clips);
    final error = player.takeError();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// Offers the worksheet as album images or an A4 PDF.
  Future<void> _exportWorksheet(List<HanziEntry> entries) async {
    if (entries.isEmpty) return;
    await showWorksheetExportSheet(context, ref, entries);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final char = ref.watch(selectedCharProvider);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      body: SafeArea(
        child: library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('字库加载失败：$e')),
          data: (data) {
            final entry = data.find(char) ?? data.entries.first;
            if (_loadedChar != entry.char) {
              _loadedChar = entry.char;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _board.load(data.glyph(entry.char));
                setState(() => _selectedStroke = -1);
              });
            }
            return _buildBody(context, data, entry, favorites);
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Library library,
    HanziEntry entry,
    List<String> favorites,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _header(entry),
        const SizedBox(height: 16),
        HanziSearch(library: library),
        const SizedBox(height: 16),
        _tabs(),
        const SizedBox(height: 16),
        if (_tab == 0) ..._characterTab(entry, favorites) else ..._definitionTab(entry),
      ],
    );
  }

  Widget _header(HanziEntry entry) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ZiliColors.cinnabar,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            '字',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('字里', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 3)),
            Text('一笔一画，认识汉字',
                style: TextStyle(fontSize: 12, color: ZiliColors.inkSoft)),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FavoritesPage()),
          ),
          icon: const Icon(Icons.star_border, size: 22),
          tooltip: '生字本',
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LibraryPage()),
          ),
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: const Text('教材字库'),
        ),
      ],
    );
  }

  Widget _tabs() {
    return Container(
      decoration: BoxDecoration(
        color: ZiliColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == i ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    i == 0 ? '字形与拼音' : '释义',
                    style: TextStyle(
                      fontWeight: _tab == i ? FontWeight.w600 : FontWeight.w400,
                      color: _tab == i ? ZiliColors.cinnabar : ZiliColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _characterTab(HanziEntry entry, List<String> favorites) {
    final starred = favorites.contains(entry.char);
    return [
      _boardCard(entry),
      const SizedBox(height: 16),
      _pinyinCard(entry, starred),
      const SizedBox(height: 16),
      _strokeGrid(entry),
      const SizedBox(height: 16),
      _pinyinLesson(entry),
    ];
  }

  Widget _boardCard(HanziEntry entry) {
    return _card(
      // The board fills the card instead of sitting at a fixed size, so the
      // strokes get all the width the page can spare. Capped so the square
      // does not become oversized next to the buttons on a tablet.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardSize = math.max(
            200.0,
            math.min(constraints.maxWidth, 360.0),
          );
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('一笔一画，认识汉字'),
                  _tag('${entry.strokeCount} 笔'),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: ZiliColors.gridLine),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: HanziBoard(controller: _board, size: boardSize),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // The controller changes state on its own (the animation ends, the
              // loop restarts), so the buttons must rebuild with it. Without this
              // the play button kept reading "停止播放" after the run finished and
              // tapping it started playback again instead of stopping.
              ListenableBuilder(
                listenable: _board,
                builder: (_, _) => Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => setState(() {
                          if (_board.playing) {
                            _board.reset();
                          } else {
                            _board.play(_speed);
                          }
                        }),
                        icon: Icon(
                          _board.playing ? Icons.stop : Icons.play_arrow,
                          size: 20,
                        ),
                        label: Text(_board.playing ? '停止播放' : '播放笔顺'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _speed = _speed == 1 ? 0.5 : (_speed == 0.5 ? 1.5 : 1);
                        if (_board.playing) _board.play(_speed);
                      }),
                      child: Text('${_speed}x'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _board.reset();
                        _selectedStroke = -1;
                      }),
                      child: const Icon(Icons.refresh, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _exportWorksheet([entry]),
                  child: const Text('保存字帖'),
                ),
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: _board,
                builder: (_, _) => Text(
                  _board.message,
                  style: const TextStyle(fontSize: 12, color: ZiliColors.inkSoft),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pinyinCard(HanziEntry entry, bool starred) {
    return _card(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('拼音 · ${entry.toneLabel}',
                        style: const TextStyle(fontSize: 12, color: ZiliColors.inkFaint)),
                    Text(entry.pinyin,
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _playSyllables([entry.syllable]),
                icon: const Icon(Icons.volume_up_outlined,
                    color: ZiliColors.cinnabar),
                tooltip: '听读音',
              ),
              IconButton(
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggle(entry.char);
                },
                icon: Icon(
                  starred ? Icons.star : Icons.star_border,
                  color: starred ? ZiliColors.cinnabar : ZiliColors.inkSoft,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _meta('部首', '${entry.radical} ${entry.radicalName}'),
              _meta('结构', entry.structure),
              _meta('笔画', '${entry.strokeCount} 笔'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _strokeGrid(HanziEntry entry) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('笔顺拆解 ${entry.strokeCount} 笔'),
              const Text('点一下，看这一笔',
                  style: TextStyle(fontSize: 12, color: ZiliColors.inkFaint)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < entry.strokeNames.length; i++)
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedStroke = i;
                    _board.select(i);
                  }),
                  child: Container(
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedStroke == i
                          ? ZiliColors.cinnabarSoft
                          : ZiliColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedStroke == i
                            ? ZiliColors.cinnabar
                            : ZiliColors.line,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 12, color: ZiliColors.inkFaint)),
                        const SizedBox(height: 2),
                        StrokeThumbnail(
                          glyph: _board.glyph,
                          index: i,
                          size: 38,
                        ),
                        const SizedBox(height: 2),
                        Text(entry.strokeNames[i],
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pinyinLesson(HanziEntry entry) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('拼音小课堂'),
          const SizedBox(height: 12),
          Row(
            children: [
              if (entry.initial.isNotEmpty) ...[
                _sound(entry.initial,
                    entry.initial == 'w' || entry.initial == 'y' ? '拼写字母' : '声母'),
                const Text('  +  '),
              ],
              _sound(entry.finalSound,
                  '${entry.initial == 'y' ? '拼写部分' : '韵母'} · ${entry.toneLabel}'),
              const Text('  =  '),
              Text(entry.pinyin,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: ZiliColors.cinnabar)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _definitionTab(HanziEntry entry) {
    return [
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(entry.char,
                    style: const TextStyle(fontSize: 48, fontFamily: 'serif')),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.pinyin, style: const TextStyle(fontSize: 18)),
                    Text('${entry.structure} · ${entry.radical}部 · ${entry.strokeCount}笔',
                        style: const TextStyle(fontSize: 12, color: ZiliColors.inkSoft)),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('基本释义', style: TextStyle(fontSize: 12, color: ZiliColors.inkFaint)),
            const SizedBox(height: 6),
            Text(entry.meaning, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('读一读，记住它'),
            const SizedBox(height: 12),
            Text(entry.sentence, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text('常见用法', style: TextStyle(fontSize: 12, color: ZiliColors.inkFaint)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                for (var i = 0; i < entry.words.length; i++)
                  ActionChip(
                    avatar: const Icon(Icons.volume_up_outlined,
                        size: 16, color: ZiliColors.cinnabar),
                    label: Text(entry.words[i]),
                    backgroundColor: ZiliColors.surfaceMuted,
                    side: const BorderSide(color: ZiliColors.line),
                    onPressed: () => _playSyllables(
                      i < entry.wordSyllables.length
                          ? entry.wordSyllables[i]
                          : const [],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZiliColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZiliColors.line),
      ),
      child: child,
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ZiliColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );

  Widget _meta(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: ZiliColors.inkFaint)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14)),
          ],
        ),
      );

  Widget _sound(String text, String label) => Column(
        children: [
          Text(text,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: ZiliColors.inkFaint)),
        ],
      );
}
