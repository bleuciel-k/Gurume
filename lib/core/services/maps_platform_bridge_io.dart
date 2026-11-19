import 'dart:io';

bool isGoogleMapsWebPlatform() => false;

bool isGoogleMapsSdkReady() => true;

String getStoredWebMapsApiKey() => '';

Future<bool> loadGoogleMapsWebSdk(String apiKey) async => true;

File _cacheFileForKey(String key) {
  final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final dir = Directory('${Directory.systemTemp.path}/oreguru_cache');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return File('${dir.path}/$safeKey.json');
}

Future<String?> readPersistentValue(String key) async {
  try {
    final file = _cacheFileForKey(key);
    if (!await file.exists()) return null;
    return await file.readAsString();
  } catch (_) {
    return null;
  }
}

Future<void> writePersistentValue(String key, String value) async {
  try {
    final file = _cacheFileForKey(key);
    await file.writeAsString(value, flush: true);
  } catch (_) {
    // 디스크 쓰기 불가 환경에서는 무시하고 메모리 캐시 유지
  }
}

Future<void> removePersistentValue(String key) async {
  try {
    final file = _cacheFileForKey(key);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // 무시
  }
}
