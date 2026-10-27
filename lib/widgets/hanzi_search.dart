import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/library_repository.dart';
import '../providers/library.dart';
import '../theme/app_theme.dart';

/// Looks characters up by hand.
///
/// Up to [Library.lookupLimit] characters at a time; every one of them becomes
/// a chip, and tapping a chip switches the page to that character. Characters
/// the library does not cover stay visible but inert, so a parent can see that
/// the character simply is not in the six textbooks yet rather than wondering
/// whether the search broke.
///
/// The page follows the search as it is typed: the first character the query
/// resolves to becomes the one being studied straight away, so typing a single
/// character is enough and the chips are only needed to pick a later one.
class HanziSearch extends ConsumerStatefulWidget {
  const HanziSearch({super.key, required this.library});

  final Library library;

  @override
  ConsumerState<HanziSearch> createState() => _HanziSearchState();
}

class _HanziSearchState extends ConsumerState<HanziSearch> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _followFirstHit(value);
  }

  /// Switches the page to the first covered character of [query].
  ///
  /// Characters the library lacks are skipped rather than blocking the jump,
  /// and a query with nothing covered at all leaves the current character
  /// alone so the board never goes blank mid keystroke. Focus is deliberately
  /// untouched here: the user is still typing.
  void _followFirstHit(String query) {
    for (final hit in widget.library.lookup(query)) {
      if (!hit.found) continue;
      if (ref.read(selectedCharProvider) != hit.char) {
        ref.read(selectedCharProvider.notifier).state = hit.char;
      }
      return;
    }
  }

  void _pick(String char) {
    // Drop the keyboard so the character being looked at is not covered.
    FocusScope.of(context).unfocus();
    ref.read(selectedCharProvider.notifier).state = char;
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedCharProvider);
    final hits = widget.library.lookup(_query);
    final missing = hits.where((h) => !h.found).map((h) => h.char).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          inputFormatters: [
            LengthLimitingTextInputFormatter(Library.lookupLimit),
          ],
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 15, color: ZiliColors.ink),
          decoration: InputDecoration(
            isDense: true,
            hintText: '输入想查的字，最多 ${Library.lookupLimit} 个',
            hintStyle: const TextStyle(fontSize: 14, color: ZiliColors.inkFaint),
            prefixIcon: const Icon(Icons.search,
                size: 20, color: ZiliColors.inkSoft),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: ZiliColors.inkSoft,
                    tooltip: '清空',
                    onPressed: _clear,
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            border: _border(ZiliColors.line),
            enabledBorder: _border(ZiliColors.line),
            focusedBorder: _border(ZiliColors.cinnabar, width: 1.4),
          ),
        ),
        if (hits.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hit in hits) _chip(hit, selected),
            ],
          ),
        ],
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '「${missing.join('」「')}」暂未收录',
            style: const TextStyle(fontSize: 12, color: ZiliColors.inkFaint),
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  Widget _chip(LookupHit hit, String selected) {
    final isSelected = hit.char == selected;
    final Color background;
    final Color foreground;
    final Color border;

    if (!hit.found) {
      background = ZiliColors.surfaceMuted;
      foreground = ZiliColors.inkFaint;
      border = ZiliColors.line;
    } else if (isSelected) {
      background = ZiliColors.cinnabar;
      foreground = Colors.white;
      border = ZiliColors.cinnabar;
    } else {
      background = Colors.white;
      foreground = ZiliColors.ink;
      border = ZiliColors.line;
    }

    return GestureDetector(
      onTap: hit.found ? () => _pick(hit.char) : null,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hit.char,
              style: TextStyle(
                fontSize: 24,
                color: foreground,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (!hit.found)
              const Text(
                '未收录',
                style: TextStyle(fontSize: 9, color: ZiliColors.inkFaint),
              ),
          ],
        ),
      ),
    );
  }
}
