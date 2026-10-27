import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:zili_flutter/services/worksheet_exporter.dart';

/// Stands in for the real storage backend so folder selection can be tested
/// without a device. What matters is which folder wins on each platform, not
/// the platform channel itself.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider({this.downloads, this.throwOnDownloads = false});

  final String? downloads;
  final bool throwOnDownloads;

  @override
  Future<String?> getDownloadsPath() async {
    if (throwOnDownloads) {
      throw UnsupportedError('no downloads directory here');
    }
    return downloads;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async => '/fake/documents';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final original = PathProviderPlatform.instance;

  tearDown(() => PathProviderPlatform.instance = original);

  test('Android/HarmonyOS prefer the downloads folder', () async {
    PathProviderPlatform.instance =
        _FakePathProvider(downloads: '/fake/downloads');

    final dir = await WorksheetExporter.targetDirectory(isIOS: false);
    expect(dir.path, '/fake/downloads');
  });

  test('falls back to documents when there is no downloads folder', () async {
    PathProviderPlatform.instance = _FakePathProvider(downloads: null);

    final dir = await WorksheetExporter.targetDirectory(isIOS: false);
    expect(dir.path, '/fake/documents');
  });

  test('falls back to documents when downloads is unsupported', () async {
    PathProviderPlatform.instance = _FakePathProvider(throwOnDownloads: true);

    final dir = await WorksheetExporter.targetDirectory(isIOS: false);
    expect(dir.path, '/fake/documents');
  });

  test('iOS always uses the documents folder', () async {
    // getDownloadsDirectory does resolve on iOS, but that folder is not
    // surfaced to the user, so documents must win.
    PathProviderPlatform.instance =
        _FakePathProvider(downloads: '/fake/ios-downloads');

    final dir = await WorksheetExporter.targetDirectory(isIOS: true);
    expect(dir.path, '/fake/documents');
    expect(Platform.isIOS, isFalse, reason: '本机是 macOS，需注入参数才能覆盖 iOS 分支');
  });
}
