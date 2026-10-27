import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/worksheet_exporter.dart';
import '../theme/app_theme.dart';

/// Confirms the worksheet images landed in the photo album.
///
/// Saving is silent otherwise and the album is a big place, so the name to look
/// for is spelled out.
Future<void> showAlbumSaved(
  BuildContext context,
  WorksheetAlbumSave save,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('已保存到相册'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            save.pageCount == 1 ? '共 1 张图片' : '共 ${save.pageCount} 张图片',
            style: const TextStyle(fontSize: 14, color: ZiliColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            '约 ${(save.bytes / 1024).round()} KB',
            style: const TextStyle(fontSize: 12, color: ZiliColors.inkFaint),
          ),
          const SizedBox(height: 14),
          const Text(
            '打开相册就能看到，文件名以 zili-worksheet 开头。',
            style: TextStyle(fontSize: 12, color: ZiliColors.inkSoft),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

/// Confirms where the A4 PDF landed. Unlike the album, this folder is not
/// somewhere the user would guess, so the full path is shown.
Future<void> showPdfSaved(
  BuildContext context,
  WorksheetExport export,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('PDF 已保存'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            export.fileName,
            style: const TextStyle(
              fontSize: 14,
              color: ZiliColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(export.size / 1024).round()} KB',
            style: const TextStyle(fontSize: 12, color: ZiliColors.inkFaint),
          ),
          const SizedBox(height: 14),
          const Text(
            '存放位置',
            style: TextStyle(fontSize: 12, color: ZiliColors.inkSoft),
          ),
          const SizedBox(height: 4),
          SelectableText(
            export.directory,
            style: const TextStyle(fontSize: 12, color: ZiliColors.ink),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: export.path));
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('复制路径'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}
