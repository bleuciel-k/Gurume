import 'dart:js_interop';

@JS('oreguruMaps.isLoaded')
external bool _jsIsLoaded();

@JS('oreguruMaps.getStoredKey')
external String _jsGetStoredKey();

@JS('oreguruMaps.loadWithKey')
external JSPromise<JSBoolean> _jsLoadWithKey(String apiKey);

@JS('oreguruStorage.get')
external String? _jsStorageGet(String key);

@JS('oreguruStorage.set')
external void _jsStorageSet(String key, String value);

@JS('oreguruStorage.remove')
external void _jsStorageRemove(String key);

bool isGoogleMapsWebPlatform() => true;

bool isGoogleMapsSdkReady() {
  try {
    return _jsIsLoaded();
  } catch (_) {
    return false;
  }
}

String getStoredWebMapsApiKey() {
  try {
    return _jsGetStoredKey();
  } catch (_) {
    return '';
  }
}

Future<bool> loadGoogleMapsWebSdk(String apiKey) async {
  try {
    final result = await _jsLoadWithKey(apiKey).toDart;
    return result.toDart;
  } catch (_) {
    return false;
  }
}

Future<String?> readPersistentValue(String key) async {
  try {
    return _jsStorageGet(key);
  } catch (_) {
    return null;
  }
}

Future<void> writePersistentValue(String key, String value) async {
  try {
    _jsStorageSet(key, value);
  } catch (_) {
    // 무시
  }
}

Future<void> removePersistentValue(String key) async {
  try {
    _jsStorageRemove(key);
  } catch (_) {
    // 무시
  }
}
