import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 포스터 PNG 바이트를 기기 문서/지원 폴더에 저장하고 저장 경로를 반환합니다.
Future<String?> exportClayPosterPng(
  Uint8List pngBytes, {
  required String fileName,
  required String shareText,
}) async {
  try {
    Directory baseDir;
    try {
      baseDir = await getApplicationSupportDirectory();
    } catch (_) {
      baseDir = Directory.systemTemp;
    }

    final postersDir = Directory('${baseDir.path}/oreguru_posters');
    if (!await postersDir.exists()) {
      await postersDir.create(recursive: true);
    }

    final file = File('${postersDir.path}/$fileName');
    await file.writeAsBytes(pngBytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}
