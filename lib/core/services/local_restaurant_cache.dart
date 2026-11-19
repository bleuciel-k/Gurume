import 'dart:convert';

import 'package:oreguru/core/services/maps_platform_bridge.dart';
import 'package:oreguru/data/models/restaurant_model.dart';

class CachedRestaurantsSnapshot {
  final List<RestaurantModel> restaurants;
  final int lastSyncMillis;

  const CachedRestaurantsSnapshot({
    required this.restaurants,
    required this.lastSyncMillis,
  });
}

typedef StorageReader = Future<String?> Function(String key);
typedef StorageWriter = Future<void> Function(String key, String value);
typedef StorageRemover = Future<void> Function(String key);

/// Firestore 읽기 과금 및 네트워크 지연을 줄이기 위해
/// 맛집 목록과 마지막 동기화 타임스탬프를 영구 스토리지(Web localStorage / Mobile 디스크)에 보관합니다.
class LocalRestaurantCache {
  static const String _restaurantsKey = 'oreguru_cached_restaurants_v1';
  static const String _lastSyncKey = 'oreguru_last_sync_millis_v1';

  final StorageReader _reader;
  final StorageWriter _writer;
  final StorageRemover _remover;

  LocalRestaurantCache({
    StorageReader? reader,
    StorageWriter? writer,
    StorageRemover? remover,
  })  : _reader = reader ?? readPersistentValue,
        _writer = writer ?? writePersistentValue,
        _remover = remover ?? removePersistentValue;

  /// 위젯 테스트(FakeAsync) 등 디스크 I/O 없이 즉시 완료되어야 하는 환경용 인메모리 캐시
  factory LocalRestaurantCache.inMemory() {
    final memory = <String, String>{};
    return LocalRestaurantCache(
      reader: (key) async => memory[key],
      writer: (key, value) async => memory[key] = value,
      remover: (key) async => memory.remove(key),
    );
  }

  Future<CachedRestaurantsSnapshot?> loadSnapshot() async {
    final rawJson = await _reader(_restaurantsKey);
    if (rawJson == null || rawJson.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return null;

      final restaurants = decoded
          .whereType<Map>()
          .map((item) => RestaurantModel.fromMap(Map<String, dynamic>.from(item)))
          .where((r) => r.id.isNotEmpty)
          .toList();

      if (restaurants.isEmpty) return null;

      final rawSync = await _reader(_lastSyncKey);
      final lastSyncMillis = int.tryParse(rawSync ?? '') ?? 0;

      return CachedRestaurantsSnapshot(
        restaurants: restaurants,
        lastSyncMillis: lastSyncMillis,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSnapshot({
    required List<RestaurantModel> restaurants,
    required int lastSyncMillis,
  }) async {
    final encoded = jsonEncode(restaurants.map((r) => r.toMap()).toList());
    await _writer(_restaurantsKey, encoded);
    await _writer(_lastSyncKey, lastSyncMillis.toString());
  }

  Future<void> clear() async {
    await _remover(_restaurantsKey);
    await _remover(_lastSyncKey);
  }
}
