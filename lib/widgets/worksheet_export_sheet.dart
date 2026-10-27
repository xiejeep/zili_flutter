import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hanzi_entry.dart';
import '../providers/library.dart';
import '../services/sheet_layout.dart';
import '../services/worksheet_exporter.dart';
import '../theme/app_theme.dart';
import 'worksheet_saved_dialog.dart';

enum _ExportKind { album, pdf }

/// Lets the user pick how to keep the worksheet, then runs it.
///
/// Images into the photo album are the default because they need no file
/// manager; the A4 PDF stays available for printing.
Future<void> showWorksheetExportSheet(
  BuildContext context,
  WidgetRef ref,
  List<HanziEntry> entries,
) async {
  final library = ref.read(libraryProvider).valueOrNull;
  if (library == null || entries.isEmpty) return;

  final pages = SheetLayoutBuilder.pageCount(entries.length);

  final kind = await showModalBottomSheet<_ExportKind>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined,
                color: ZiliColors.cinnabar),
            title: const Text('保存到相册'),
            subtitle: Text(
              entries.length == 1
                  ? '1 张图片，打开相册就能看'
                  : '$pages 张图片，打开相册就能看',
            ),
            onTap: () => Navigator.of(context).pop(_ExportKind.album),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined,
                color: ZiliColors.inkSoft),
            title: const Text('导出 PDF'),
            subtitle: const Text('A4 排版，适合打印'),
            onTap: () => Navigator.of(context).pop(_ExportKind.pdf),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (kind == null || !context.mounted) return;

  final result = await showDialog<Object>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ExportProgress(
      work: () => switch (kind) {
        _ExportKind.album =>
          WorksheetExporter.saveToAlbum(entries: entries, library: library),
        _ExportKind.pdf =>
          WorksheetExporter.exportPdf(entries: entries, library: library),
      },
    ),
  );

  if (!context.mounted) return;
  switch (result) {
    case WorksheetAlbumSave():
      await showAlbumSaved(context, result);
    case WorksheetExport():
      await showPdfSaved(context, result);
    default:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$result')),
      );
  }
}

/// Runs [work] behind a spinner and closes itself with either the value or the
/// error, so the caller never has to juggle a second dialog.
class _ExportProgress extends StatefulWidget {
  const _ExportProgress({required this.work});

  final Future<Object> Function() work;

  @override
  State<_ExportProgress> createState() => _ExportProgressState();
}

class _ExportProgressState extends State<_ExportProgress> {
  @override
  void initState() {
    super.initState();
    widget.work().then(
      (value) {
        if (mounted) Navigator.of(context).pop(value);
      },
      onError: (Object error) {
        if (mounted) Navigator.of(context).pop(error);
      },
    );
  }

  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox.square(
          dimension: 40,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
}
