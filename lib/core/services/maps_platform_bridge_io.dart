import 'dart:io';

import 'package:path_provider/path_provider.dart';

bool isGoogleMapsWebPlatform() => false;

bool isGoogleMapsSdkReady() => true;

String getStoredWebMapsApiKey() => '';

Future<bool> loadGoogleMapsWebSdk(String apiKey) async => true;

Directory? _cachedCacheDirectory;

Future<Directory> _resolveCacheDirectory() async {
  final cached = _cachedCacheDirectory;
  if (cached != null) return cached;

  Directory baseDir;
  try {
    baseDir = await getApplicationSupportDirectory();
  } catch (_) {
    // 순수 Dart 테스트나 플랫폼 바인딩이 없는 환경에서는 임시 디렉토리로 안전 폴백
    baseDir = Directory.systemTemp;
  }

  final cacheDir = Directory('${baseDir.path}/oreguru_cache');
  if (!await cacheDir.exists()) {
    await cacheDir.create(recursive: true);
  }
  _cachedCacheDirectory = cacheDir;
  return cacheDir;
}

Future<File> _cacheFileForKey(String key) async {
  final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final dir = await _resolveCacheDirectory();
  return File('${dir.path}/$safeKey.json');
}

Future<String?> readPersistentValue(String key) async {
  try {
    final file = await _cacheFileForKey(key);
    if (!await file.exists()) return null;
    return await file.readAsString();
  } catch (_) {
    return null;
  }
}

Future<void> writePersistentValue(String key, String value) async {
  try {
    final file = await _cacheFileForKey(key);
    await file.writeAsString(value, flush: true);
  } catch (_) {
    // 디스크 쓰기 불가 환경에서는 무시하고 메모리 캐시 유지
  }
}

Future<void> removePersistentValue(String key) async {
  try {
    final file = await _cacheFileForKey(key);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // 무시
  }
}
