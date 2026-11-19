import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oreguru/app.dart';
import 'package:oreguru/core/services/local_restaurant_cache.dart';
import 'package:oreguru/core/services/marker_bitmap_cache.dart';
import 'package:oreguru/core/services/weather_service.dart';
import 'package:oreguru/data/models/party_and_preference_model.dart';
import 'package:oreguru/data/models/restaurant_model.dart';
import 'package:oreguru/data/repositories/restaurant_repository.dart';

void main() {
  testWidgets('オレグル 날씨 비노출, 장바구니 담기 및 구루냥 결정/거절 제외 테스트', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 880);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockWeatherService = WeatherService(
      client: MockClient(
        (_) async => http.Response(
          '{"current":{"weather_code":63,"temperature_2m":14.0}}',
          200,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weatherServiceProvider.overrideWithValue(mockWeatherService),
          localRestaurantCacheProvider.overrideWithValue(
            LocalRestaurantCache.inMemory(),
          ),
        ],
        child: const OreguruApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 초기 화면: 날씨 UI는 화면에 노출되지 않으며 장바구니 창은 숨겨져 있음
    expect(find.textContaining('비 오는 날'), findsNothing);
    expect(find.textContaining('화창한 날'), findsNothing);
    expect(find.text('골라줘!'), findsNothing);
    expect(find.text('연남 빗소리 주막'), findsOneWidget);
    expect(find.text('오레노 돈코츠 라멘'), findsOneWidget);

    // 2. 첫 번째 가게 담기
    await tester.tap(find.text('연남 빗소리 주막'));
    await tester.pumpAndSettle();
    expect(find.text('🛒 후보 장바구니 담기'), findsOneWidget);
    await tester.tap(find.text('🛒 후보 장바구니 담기'));
    await tester.pumpAndSettle();
    expect(find.text('🛒 1/6'), findsOneWidget);

    // 바텀 시트 닫고 두 번째 가게 담기
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('오레노 돈코츠 라멘'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🛒 후보 장바구니 담기'));
    await tester.pumpAndSettle();
    expect(find.text('🛒 2/6'), findsOneWidget);
    expect(find.text('골라줘!'), findsOneWidget);

    // 3. 구루냥 모달 열기
    await tester.tap(find.text('골라줘!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('누구랑 함께 가나요?'), findsOneWidget);
    await tester.ensureVisible(find.text('설레는 둘이서 (남녀)'));
    await tester.pump();

    // 4. 인원 선택 -> 질문 단계 (날씨 문구 미노출 확인)
    await tester.tap(find.text('설레는 둘이서 (남녀)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('질문 패스! 구루냥에게 온전히 맡기기 😼'), findsOneWidget);
    expect(find.text('고민 없이 구루냥의 직감에 100% 맡겨보세요!'), findsOneWidget);

    // 5. 구루냥에게 온전히 맡기기 실행 -> PICK 결과 확인
    await tester.tap(find.text('질문 패스! 구루냥에게 온전히 맡기기 😼'));
    await tester.pump();
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 260));
    }
    expect(find.text('PICK! 🐾'), findsOneWidget);

    // 6. 거절하기 -> 남은 1곳으로 재추첨
    final rejectBtn = find.textContaining('여긴 안 땡겨!');
    await tester.ensureVisible(rejectBtn);
    await tester.pump();
    await tester.tap(rejectBtn);
    await tester.pump();
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 260));
    }
    expect(find.text('PICK! 🐾'), findsOneWidget);
    expect(find.text('😿 여긴 안 땡겨! (이 가게도 제외하기)'), findsOneWidget);
  });

  test('3D 클레이 마커 PNG 비트맵 변환 및 캐싱 검증', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = RestaurantRepository();
    final restaurants = await repo.fetchCachedRestaurants();
    final cache = MarkerBitmapCache();

    final pngBytes = await cache.renderMarkerPngBytes(
      restaurants.first,
      isSelected: false,
      isCandidate: true,
    );
    expect(pngBytes.length, greaterThan(500));
    // PNG 시그니처 (0x89 P N G) 확인
    expect(pngBytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);

    final first = await cache.getMarkerBitmap(
      restaurants.first,
      isSelected: true,
      isCandidate: true,
    );
    final second = await cache.getMarkerBitmap(
      restaurants.first,
      isSelected: true,
      isCandidate: true,
    );
    expect(identical(first, second), isTrue);
  });

  test('실시간 WMO 기상 코드 변환 검증', () {
    expect(
      WeatherService.mapWmoToWeatherCondition(
        weatherCode: 61,
        temperatureC: 16,
      ),
      WeatherCondition.rainy,
    );
    expect(
      WeatherService.mapWmoToWeatherCondition(
        weatherCode: 0,
        temperatureC: 4,
      ),
      WeatherCondition.chilly,
    );
    expect(
      WeatherService.mapWmoToWeatherCondition(
        weatherCode: 0,
        temperatureC: 30,
      ),
      WeatherCondition.hot,
    );
    expect(
      WeatherService.mapWmoToWeatherCondition(
        weatherCode: 1,
        temperatureC: 20,
      ),
      WeatherCondition.sunny,
    );
  });

  test('RestaurantModel Firestore/JSON 직렬화 및 Delta Sync 병합 검증', () async {
    final original = RestaurantRepository.seedRestaurants.first;
    final map = original.toFirestore();
    final restored = RestaurantModel.fromMap(map);

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.heroColor.toARGB32(), original.heroColor.toARGB32());
    expect(restored.suitableParties, original.suitableParties);
    expect(restored.weatherComments[WeatherCondition.rainy],
        original.weatherComments[WeatherCondition.rainy]);
    expect(restored.updatedAtMillis, original.updatedAtMillis);

    // Delta Sync 병합 검증: 기존 1건 수정 + 신규 1건 추가
    final updatedExisting = original.copyWith(
      name: '연남 빗소리 주막 (리뉴얼)',
      updatedAtMillis: 1763350000000,
    );
    final newPlace = original.copyWith(
      id: 'rest_99',
      name: '망원 야키토리',
      updatedAtMillis: 1763350001000,
    );

    final merged = RestaurantRepository.mergeDeltaRestaurants(
      existing: RestaurantRepository.seedRestaurants,
      deltas: [updatedExisting, newPlace],
    );

    expect(merged.length, RestaurantRepository.seedRestaurants.length + 1);
    expect(
      merged.firstWhere((r) => r.id == original.id).name,
      '연남 빗소리 주막 (리뉴얼)',
    );
    expect(merged.any((r) => r.id == 'rest_99'), isTrue);

    // LocalRestaurantCache 저장 & 복원 검증
    final cache = LocalRestaurantCache();
    await cache.clear();
    await cache.saveSnapshot(
      restaurants: merged,
      lastSyncMillis: 1763350001000,
    );
    final loaded = await cache.loadSnapshot();
    expect(loaded, isNotNull);
    expect(loaded!.restaurants.length, merged.length);
    expect(loaded.lastSyncMillis, 1763350001000);
    await cache.clear();
  });
}
