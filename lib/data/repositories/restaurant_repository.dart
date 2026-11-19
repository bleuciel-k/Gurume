import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/core/services/firebase_service.dart';
import 'package:oreguru/core/services/local_restaurant_cache.dart';
import 'package:oreguru/data/models/party_and_preference_model.dart';
import 'package:oreguru/data/models/restaurant_model.dart';

/// Firestore 증분 동기화 결과 리포트
@immutable
class SyncReport {
  final int totalCount;
  final int deltaFetchedCount;
  final int lastSyncMillis;
  final bool syncedFromFirestore;
  final String? errorMessage;

  const SyncReport({
    required this.totalCount,
    required this.deltaFetchedCount,
    required this.lastSyncMillis,
    required this.syncedFromFirestore,
    this.errorMessage,
  });
}

/// Google Places API 과금을 방지하고 Firestore 읽기 비용까지 최소화하기 위해
/// 1) 로컬 캐시 즉시 로드 (0원, 0ms)
/// 2) Firestore 증분 동기화 (`updatedAt > lastSyncMillis`)
/// 를 결합한 맛집 레포지토리.
class RestaurantRepository {
  static const String collectionName = 'restaurants';

  final FirebaseService _firebaseService;
  final LocalRestaurantCache _localCache;

  List<RestaurantModel>? _memoryCache;
  int _lastSyncMillis = 0;
  SyncReport? _lastSyncReport;

  RestaurantRepository({
    FirebaseService? firebaseService,
    LocalRestaurantCache? localCache,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _localCache = localCache ?? LocalRestaurantCache();

  int get lastSyncMillis => _lastSyncMillis;
  SyncReport? get lastSyncReport => _lastSyncReport;

  /// 앱 실행 시 로컬 캐시를 즉시 반환하고, Firebase가 연결되어 있으면
  /// `updatedAt > lastSyncMillis` 증분(Delta)만 백그라운드로 병합합니다.
  Future<List<RestaurantModel>> fetchCachedRestaurants({
    bool forceDeltaSync = false,
  }) async {
    if (_memoryCache == null) {
      final snapshot = await _localCache.loadSnapshot();
      if (snapshot != null && snapshot.restaurants.isNotEmpty) {
        _memoryCache = snapshot.restaurants;
        _lastSyncMillis = snapshot.lastSyncMillis;
      } else {
        _memoryCache = List<RestaurantModel>.from(seedRestaurants);
        _lastSyncMillis = 0;
        await _localCache.saveSnapshot(
          restaurants: _memoryCache!,
          lastSyncMillis: _lastSyncMillis,
        );
      }
    }

    if (forceDeltaSync || _firebaseService.isConnected) {
      await syncDeltaFromFirestore();
    }

    return _memoryCache!;
  }

  /// Firestore `restaurants` 컬렉션에서 마지막 동기화 시각 이후 변경된 문서만 쿼리해 병합
  Future<SyncReport> syncDeltaFromFirestore() async {
    final current = _memoryCache ?? List<RestaurantModel>.from(seedRestaurants);
    final db = _firebaseService.firestore;

    if (db == null) {
      final report = SyncReport(
        totalCount: current.length,
        deltaFetchedCount: 0,
        lastSyncMillis: _lastSyncMillis,
        syncedFromFirestore: false,
      );
      _lastSyncReport = report;
      return report;
    }

    try {
      Query<Map<String, dynamic>> query = db.collection(collectionName);
      if (_lastSyncMillis > 0) {
        query = query.where('updatedAt', isGreaterThan: _lastSyncMillis);
      }

      final querySnapshot = await query.get();
      final deltaDocs = querySnapshot.docs
          .map(RestaurantModel.fromFirestore)
          .where((r) => r.id.isNotEmpty)
          .toList();

      final merged = mergeDeltaRestaurants(
        existing: current,
        deltas: deltaDocs,
      );

      final maxUpdatedAt = merged.fold<int>(
        _lastSyncMillis,
        (acc, r) => r.updatedAtMillis > acc ? r.updatedAtMillis : acc,
      );
      final nextSyncMillis = deltaDocs.isNotEmpty
          ? maxUpdatedAt
          : (_lastSyncMillis > 0
              ? _lastSyncMillis
              : DateTime.now().millisecondsSinceEpoch);

      _memoryCache = merged;
      _lastSyncMillis = nextSyncMillis;
      await _localCache.saveSnapshot(
        restaurants: merged,
        lastSyncMillis: nextSyncMillis,
      );

      final report = SyncReport(
        totalCount: merged.length,
        deltaFetchedCount: deltaDocs.length,
        lastSyncMillis: nextSyncMillis,
        syncedFromFirestore: true,
      );
      _lastSyncReport = report;
      return report;
    } catch (e) {
      final report = SyncReport(
        totalCount: current.length,
        deltaFetchedCount: 0,
        lastSyncMillis: _lastSyncMillis,
        syncedFromFirestore: false,
        errorMessage: e.toString(),
      );
      _lastSyncReport = report;
      return report;
    }
  }

  /// 기존 캐시 목록에 Firestore 증분(Delta) 문서를 ID 기준으로 병합(Upsert)
  static List<RestaurantModel> mergeDeltaRestaurants({
    required List<RestaurantModel> existing,
    required List<RestaurantModel> deltas,
  }) {
    if (deltas.isEmpty) return List<RestaurantModel>.from(existing);

    final byId = <String, RestaurantModel>{
      for (final r in existing) r.id: r,
    };
    for (final delta in deltas) {
      byId[delta.id] = delta;
    }
    return byId.values.toList();
  }

  /// 초기 시드 데이터 8곳을 Firestore `restaurants` 컬렉션에 일괄 업로드 (`WriteBatch`)
  Future<int> seedRestaurantsToFirestore() async {
    final db = _firebaseService.firestore;
    if (db == null) {
      throw StateError('Firebase가 아직 연결되지 않았습니다.');
    }

    final batch = db.batch();
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final col = db.collection(collectionName);

    for (final item in seedRestaurants) {
      final withTimestamp = item.copyWith(updatedAtMillis: nowMillis);
      batch.set(col.doc(item.id), withTimestamp.toFirestore());
    }

    await batch.commit();
    return seedRestaurants.length;
  }

  static const List<RestaurantModel> seedRestaurants = [
    RestaurantModel(
      id: 'rest_01',
      name: '연남 빗소리 주막',
      category: '한식주점 · 전/막걸리',
      oneLineReview: '빗소리 들으며 바삭한 해물파전에 밤막걸리 한 잔',
      latitude: 37.5624,
      longitude: 126.9252,
      geohash: 'wydm9q8',
      clayMarkerType: ClayMarkerType.izakayaRoof,
      heroColor: Color(0xFFFFEFE8),
      rating: 4.8,
      distanceMeters: 280,
      isOpenNow: true,
      hasNoWaiting: true,
      isSoloFriendly: false,
      openHoursText: '17:00 - 01:00',
      suitableParties: [
        PartyType.coupleMF,
        PartyType.duoSame,
        PartyType.friends34,
        PartyType.group5Plus,
      ],
      vibeTags: [VibePreference.lively, VibePreference.cozy],
      tasteTags: [TastePreference.savoryGrilled, TastePreference.spicyKick],
      weatherTags: [WeatherCondition.rainy, WeatherCondition.chilly],
      seasonTags: [SeasonType.spring, SeasonType.autumn, SeasonType.winter],
      signatureDish: '바삭한 해물파전',
      weatherComments: {
        WeatherCondition.rainy:
            '오늘은 비가 오니까 전이 있는 이 가게가 맛있어 보이는구나! 츄릅~ 🐾',
        WeatherCondition.chilly:
            '바람이 쌀쌀한 날엔 뜨끈한 김치전골에 파전이 최고지! 츄릅~ 🐾',
      },
      defaultTasteComment:
          '오늘 분위기에 겉바속촉 해물파전 한 입이면 게임 끝이라구! 😼',
      updatedAtMillis: 1763347000000,
    ),
    RestaurantModel(
      id: 'rest_02',
      name: '오레노 돈코츠 라멘',
      category: '일식 · 자가제면 라멘',
      oneLineReview: '18시간 푹 고아낸 진한 사골 육수와 반숙 계란',
      latitude: 37.5608,
      longitude: 126.9234,
      geohash: 'wydm9q4',
      clayMarkerType: ClayMarkerType.ramenHouse,
      heroColor: Color(0xFFFFF4E0),
      rating: 4.9,
      distanceMeters: 190,
      isOpenNow: true,
      hasNoWaiting: false,
      isSoloFriendly: true,
      openHoursText: '11:30 - 21:30',
      suitableParties: [
        PartyType.soloMale,
        PartyType.soloFemale,
        PartyType.coupleMF,
        PartyType.duoSame,
      ],
      vibeTags: [VibePreference.cozy, VibePreference.heartyFast],
      tasteTags: [TastePreference.warmSoup, TastePreference.savoryGrilled],
      weatherTags: [WeatherCondition.rainy, WeatherCondition.chilly],
      seasonTags: [SeasonType.autumn, SeasonType.winter],
      signatureDish: '진한 돈코츠 라멘',
      weatherComments: {
        WeatherCondition.rainy:
            '비 맞고 으슬으슬할 땐 뜨끈한 돈코츠 국물 한 모금이 보약이지! 츄릅~ 🐾',
        WeatherCondition.chilly:
            '날이 이렇게 쌀쌀하니 김 모락모락 나는 라멘이 땡기는구나! 츄릅~ 🐾',
      },
      defaultTasteComment:
          '혼자서도 둘이서도 후루룩 면치기하기 딱 좋은 성지라구! 😼',
      updatedAtMillis: 1763347000000,
    ),
    RestaurantModel(
      id: 'rest_03',
      name: '햇살 테라스 포케 & 소바',
      category: '캐주얼 · 냉소바/포케',
      oneLineReview: '통창 햇살 아래 시원한 살얼음 메밀소바와 아보카도 볼',
      latitude: 37.5632,
      longitude: 126.9278,
      geohash: 'wydm9qb',
      clayMarkerType: ClayMarkerType.pokeSalad,
      heroColor: Color(0xFFEAF7F6),
      rating: 4.7,
      distanceMeters: 420,
      isOpenNow: true,
      hasNoWaiting: true,
      isSoloFriendly: true,
      openHoursText: '11:00 - 21:00',
      suitableParties: [
        PartyType.soloMale,
        PartyType.soloFemale,
        PartyType.coupleMF,
        PartyType.duoSame,
      ],
      vibeTags: [VibePreference.aesthetic, VibePreference.cozy],
      tasteTags: [TastePreference.lightClean],
      weatherTags: [WeatherCondition.sunny, WeatherCondition.hot],
      seasonTags: [SeasonType.spring, SeasonType.summer],
      signatureDish: '살얼음 냉소바와 포케',
      weatherComments: {
        WeatherCondition.sunny:
            '햇살이 쨍하니 테라스에서 산뜻한 포케 먹기 딱 좋은 날이구만! 츄릅~ 🐾',
        WeatherCondition.hot:
            '더워서 입맛 없을 땐 살얼음 동동 냉소바가 정답이지! 츄릅~ 🐾',
      },
      defaultTasteComment:
          '속 편하고 예쁘게 잘 차려진 한 끼 원한다면 여기라구! 😼',
      updatedAtMillis: 1763347000000,
    ),
    RestaurantModel(
      id: 'rest_04',
      name: '화로구이 숯불갈비집',
      category: '육류 · 숙성 숯불구이',
      oneLineReview: '초벌해서 나와 굽기 편한 육즙 가득 숙성 목살',
      latitude: 37.5594,
      longitude: 126.9267,
      geohash: 'wydm9q1',
      clayMarkerType: ClayMarkerType.grillHouse,
      heroColor: Color(0xFFFFEBF0),
      rating: 4.8,
      distanceMeters: 470,
      isOpenNow: true,
      hasNoWaiting: true,
      isSoloFriendly: false,
      openHoursText: '16:00 - 23:30',
      suitableParties: [
        PartyType.coupleMF,
        PartyType.friends34,
        PartyType.group5Plus,
      ],
      vibeTags: [VibePreference.lively, VibePreference.heartyFast],
      tasteTags: [TastePreference.savoryGrilled],
      weatherTags: [WeatherCondition.sunny, WeatherCondition.chilly],
      seasonTags: [SeasonType.spring, SeasonType.autumn, SeasonType.winter],
      signatureDish: '육즙 가득 숙성 숯불목살',
      weatherComments: {
        WeatherCondition.chilly:
            '찬 바람 불 땐 숯불 앞에서 노릇노릇 고기 굽는 게 최고지! 츄릅~ 🐾',
        WeatherCondition.sunny:
            '오늘 기분도 좋은데 지글지글 고기 파티 어때? 입에 침이 고이네! 츄릅~ 🐾',
      },
      defaultTasteComment:
          '든든하게 기름칠하고 싶을 땐 이 집 고기만 한 게 없다구! 😼',
      updatedAtMillis: 1763347000000,
    ),
    RestaurantModel(
      id: 'rest_05',
      name: '매콤낙지 직화 덮밥',
      category: '한식 · 직화덮밥',
      oneLineReview: '불향 입힌 탱글한 낙지와 계란찜 조합이 환상적',
      latitude: 37.5618,
      longitude: 126.9221,
      geohash: 'wydm9q5',
      clayMarkerType: ClayMarkerType.riceBowlShop,
      heroColor: Color(0xFFFFEFE8),
      rating: 4.6,
      distanceMeters: 350,
      isOpenNow: true,
      hasNoWaiting: true,
      isSoloFriendly: true,
      openHoursText: '11:00 - 22:00',
      suitableParties: [
        PartyType.soloMale,
        PartyType.soloFemale,
        PartyType.duoSame,
        PartyType.friends34,
      ],
      vibeTags: [VibePreference.heartyFast, VibePreference.lively],
      tasteTags: [TastePreference.spicyKick, TastePreference.savoryGrilled],
      weatherTags: [WeatherCondition.hot, WeatherCondition.rainy],
      seasonTags: [SeasonType.summer, SeasonType.autumn],
      signatureDish: '직화 불향 낙지덮밥',
      weatherComments: {
        WeatherCondition.hot:
            '이열치열! 후끈한 날엔 화끈한 직화 낙지로 땀 쫙 빼줘야지! 츄릅~ 🐾',
        WeatherCondition.rainy:
            '비 와서 축 처질 땐 매콤한 불향 낙지 한 그릇으로 기분 전환! 츄릅~ 🐾',
      },
      defaultTasteComment:
          '스트레스 확 날려버리는 감칠맛 매콤함이라구! 😼',
      updatedAtMillis: 1763347000000,
    ),
    RestaurantModel(
      id: 'rest_06',
      name: '달빛 모츠나베 이자카야',
      category: '이자카야 · 대창전골',
      oneLineReview: '고소한 대창과 부추가 가득 올라간 보글보글 나베',
      latitude: 37.5588,
      longitude: 126.9245,
      geohash: 'wydm9q0',
      clayMarkerType: ClayMarkerType.spicyPot,
      heroColor: Color(0xFFF3EEFF),
      rating: 4.9,
      distanceMeters: 620,
      isOpenNow: true,
      hasNoWaiting: false,
      isSoloFriendly: false,
      openHoursText: '17:30 - 02:00',
      suitableParties: [
        PartyType.coupleMF,
        PartyType.duoSame,
        PartyType.friends34,
        PartyType.group5Plus,
      ],
      vibeTags: [VibePreference.cozy, VibePreference.aesthetic],
      tasteTags: [TastePreference.warmSoup, TastePreference.savoryGrilled],
      weatherTags: [WeatherCondition.rainy, WeatherCondition.chilly],
      seasonTags: [SeasonType.autumn, SeasonType.winter],
      signatureDish: '보글보글 모츠나베',
      weatherComments: {
        WeatherCondition.chilly:
            '찬 바람 솔솔 부니 보글보글 끓는 모츠나베 국물이 미치도록 땡기네! 츄릅~ 🐾',
        WeatherCondition.rainy:
            '비 오는 밤엔 따뜻한 전골 냄비 앞에 마주 앉는 게 로망이지! 츄릅~ 🐾',
      },
      defaultTasteComment:
          '진한 국물 한 스푼 떠먹으면 바로 감탄사가 터진다구! 😼',
      updatedAtMillis: 1763347000000,
    ),
    RestaurantModel(
      id: 'rest_07',
      name: '골목 화덕 피자리아',
      category: '양식 · 나폴리 화덕피자',
      oneLineReview: '쫄깃한 도우 위에 생바질과 부라타 치즈가 통째로',
      latitude: 37.5641,
      longitude: 126.9255,
      geohash: 'wydm9qc',
      clayMarkerType: ClayMarkerType.pastaTerrace,
      heroColor: Color(0xFFFFEFE8),
      rating: 4.7,
      distanceMeters: 480,
      isOpenNow: true,
      hasNoWaiting: true,
      isSoloFriendly: false,
      openHoursText: '12:00 - 22:00',
      suitableParties: [
        PartyType.coupleMF,
        PartyType.duoSame,
        PartyType.friends34,
        PartyType.group5Plus,
      ],
      vibeTags: [VibePreference.aesthetic, VibePreference.lively],
      tasteTags: [TastePreference.savoryGrilled, TastePreference.lightClean],
      weatherTags: [WeatherCondition.sunny],
      seasonTags: [SeasonType.spring, SeasonType.summer, SeasonType.autumn],
      signatureDish: '부라타 치즈 화덕피자',
      weatherComments: {
        WeatherCondition.sunny:
            '화창한 날엔 노릇한 화덕피자에 청량한 에이드 한 잔이 그림이지! 츄릅~ 🐾',
      },
      defaultTasteComment:
          '분위기도 맛도 실패 없는 감성 픽이라구! 😼',
      updatedAtMillis: 1763347000000,
    ),
    RestaurantModel(
      id: 'rest_08',
      name: '심야 카츠 카레 공방',
      category: '일식 · 수제 카츠카레',
      oneLineReview: '바삭한 안심카츠와 72시간 숙성 향신료 카레의 조화',
      latitude: 37.5602,
      longitude: 126.9285,
      geohash: 'wydm9q3',
      clayMarkerType: ClayMarkerType.riceBowlShop,
      heroColor: Color(0xFFFFF4E0),
      rating: 4.6,
      distanceMeters: 440,
      isOpenNow: false,
      hasNoWaiting: true,
      isSoloFriendly: true,
      openHoursText: '17:00 - 22:30 (브레이크 타임)',
      suitableParties: [
        PartyType.soloMale,
        PartyType.soloFemale,
        PartyType.duoSame,
      ],
      vibeTags: [VibePreference.heartyFast, VibePreference.cozy],
      tasteTags: [TastePreference.savoryGrilled, TastePreference.spicyKick],
      weatherTags: [WeatherCondition.sunny, WeatherCondition.chilly],
      seasonTags: [SeasonType.spring, SeasonType.autumn, SeasonType.winter],
      signatureDish: '수제 안심카츠 카레',
      weatherComments: {
        WeatherCondition.chilly:
            '조금 쌀쌀한 날엔 진하고 따뜻한 향신료 카레 한 접시가 딱이지! 츄릅~ 🐾',
      },
      defaultTasteComment:
          '바삭한 돈카츠에 진한 카레 조합은 언제 먹어도 반칙이라구! 😼',
      updatedAtMillis: 1763347000000,
    ),
  ];
}

final localRestaurantCacheProvider = Provider<LocalRestaurantCache>((ref) {
  return LocalRestaurantCache();
});

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepository(
    firebaseService: ref.watch(firebaseServiceProvider),
    localCache: ref.watch(localRestaurantCacheProvider),
  );
});

final restaurantsProvider = FutureProvider<List<RestaurantModel>>((ref) async {
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.fetchCachedRestaurants();
});
