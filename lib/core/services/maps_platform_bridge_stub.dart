final Map<String, String> _memoryStorage = {};

bool isGoogleMapsWebPlatform() => false;

bool isGoogleMapsSdkReady() => true;

String getStoredWebMapsApiKey() => '';

Future<bool> loadGoogleMapsWebSdk(String apiKey) async => true;

Future<String?> readPersistentValue(String key) async => _memoryStorage[key];

Future<void> writePersistentValue(String key, String value) async {
  _memoryStorage[key] = value;
}

Future<void> removePersistentValue(String key) async {
  _memoryStorage.remove(key);
}
