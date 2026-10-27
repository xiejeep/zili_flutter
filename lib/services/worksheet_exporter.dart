import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';

import '../data/library_repository.dart';
import '../models/hanzi_entry.dart';
import 'worksheet_image.dart';
import 'worksheet_pdf.dart';

/// Result of saving worksheet pages into the system photo album.
class WorksheetAlbumSave {
  const WorksheetAlbumSave({required this.pageCount, required this.bytes});

  final int pageCount;
  final int bytes;
}

class WorksheetExport {
  const WorksheetExport({
    required this.path,
    required this.size,
    required this.directory,
  });

  /// Absolute path of the written PDF.
  final String path;
  final int size;

  /// Folder the file landed in.
  final String directory;

  String get fileName => path.split(Platform.pathSeparator).last;
}

/// Turns the selected characters into something the user can keep.
///
/// The primary path is images straight into the photo album: it needs no file
/// manager, works the same on all three platforms and is what a parent will
/// actually reach for. The A4 PDF stays available because it is the better
/// format for printing.
class WorksheetExporter {
  WorksheetExporter._();

  /// Renders one PNG per page and saves them to the system photo album.
  ///
  /// Throws when the platform refuses to save, so the caller can surface the
  /// reason instead of claiming success.
  static Future<WorksheetAlbumSave> saveToAlbum({
    required List<HanziEntry> entries,
    required Library library,
  }) async {
    final pages = await WorksheetImage.build(entries: entries, library: library);
    final stamp = _stamp();
    var total = 0;

    for (var i = 0; i < pages.length; i++) {
      final bytes = pages[i];
      total += bytes.length;
      // A single page needs no index, several do, so the order is obvious in
      // the album.
      final name = pages.length == 1
          ? 'zili-worksheet-$stamp.png'
          : 'zili-worksheet-$stamp-${i + 1}.png';

      final result = await SaverGallery.saveImage(
        bytes,
        fileName: name,
        quality: 100,
        skipIfExists: false,
      );
      if (!result.isSuccess) {
        throw StateError('保存到相册失败：${result.errorMessage ?? '未知错误'}');
      }
    }

    return WorksheetAlbumSave(pageCount: pages.length, bytes: total);
  }

  /// Writes the A4 PDF next to the app's own files.
  static Future<WorksheetExport> exportPdf({
    required List<HanziEntry> entries,
    required Library library,
  }) async {
    final Uint8List bytes =
        await WorksheetPdf.build(entries: entries, library: library);
    final directory = await targetDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File('${directory.path}/zili-worksheet-${_stamp()}.pdf');
    await file.writeAsBytes(bytes, flush: true);

    return WorksheetExport(
      path: file.path,
      size: bytes.length,
      directory: directory.path,
    );
  }

  /// Picks the most discoverable writable folder for the current platform.
  ///
  /// - Android / HarmonyOS: an app specific folder inside the shared Downloads
  ///   directory.
  /// - iOS: the app documents directory, the only sandbox folder the Files app
  ///   surfaces (see `UIFileSharingEnabled` in ios/Runner/Info.plist).
  ///
  /// Note: from Android 11 on, `/Android/data` is closed to third party file
  /// managers, so this folder is really only reachable over adb. That is why
  /// the album export is the primary path. [isIOS] is injectable so the branch
  /// can be exercised from tests, where the host platform is macOS.
  static Future<Directory> targetDirectory({bool? isIOS}) async {
    if (!(isIOS ?? Platform.isIOS)) {
      try {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) return downloads;
      } on UnsupportedError {
        // Platform with no downloads concept, fall through.
      } catch (_) {
        // Any other platform hiccup, fall through.
      }
    }
    return getApplicationDocumentsDirectory();
  }

  /// Timestamp for the file name, down to the second.
  ///
  /// Seconds matter: the album and the PDF folder both key off the name, and a
  /// minute resolution would collide when a parent saves two worksheets in a
  /// row.
  static String _stamp() => DateTime.now()
      .toIso8601String()
      .substring(0, 19)
      .replaceAll(RegExp(r'[:\-T]'), '');
}
