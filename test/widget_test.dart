import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oreguru/app.dart';
import 'package:oreguru/core/services/cat_dialogue_engine.dart';
import 'package:oreguru/core/services/local_restaurant_cache.dart';
import 'package:oreguru/core/services/location_service.dart';
import 'package:oreguru/core/services/marker_bitmap_cache.dart';
import 'package:oreguru/core/services/navigation_launcher.dart';
import 'package:oreguru/core/services/weather_service.dart';
import 'package:oreguru/core/widgets/navigation_sheet.dart';
import 'package:oreguru/data/models/party_and_preference_model.dart';
import 'package:oreguru/data/models/restaurant_model.dart';
import 'package:oreguru/data/repositories/restaurant_repository.dart';
import 'package:oreguru/features/cat_decision/providers/cat_decision_provider.dart';
import 'package:oreguru/features/map_explorer/presentation/widgets/one_tap_filter_bar.dart';
import 'package:oreguru/features/map_explorer/providers/map_filter_provider.dart';

class _FakeLocationService extends LocationService {
  final LocationFetchResult result;

  _FakeLocationService(this.result);

  @override
  Future<LocationFetchResult> getCurrentLocation() async => result;
}

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
          locationServiceProvider.overrideWithValue(
            _FakeLocationService(
              const LocationFetchResult(
                location: kDefaultYeonnamLocation,
                isLiveGps: true,
              ),
            ),
          ),
          // 화요일 점심 피크 고정 (반주 동적 질문 미노출 시간대)
          currentDateTimeProvider.overrideWithValue(
            () => DateTime(2026, 11, 24, 12, 30),
          ),
        ],
        child: const OreguruApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 초기 화면: 날씨 UI 및 개발자 디버그 배지는 노출되지 않음
    expect(find.textContaining('비 오는 날'), findsNothing);
    expect(find.textContaining('화창한 날'), findsNothing);
    expect(find.text('💾 캐시'), findsNothing);
    expect(find.text('Google 지도'), findsNothing);
    expect(find.byKey(const Key('settings_button')), findsOneWidget);
    expect(find.byKey(const Key('locate_me_button')), findsOneWidget);
    expect(find.text('골라줘!'), findsNothing);
    expect(find.text('연남 빗소리 주막'), findsOneWidget);
    expect(find.text('오레노 돈코츠 라멘'), findsOneWidget);

    // 2. 첫 번째 가게 탭 -> 브레이크타임/영업상태 및 가격대 배지 확인 & 담기
    await tester.tap(find.text('연남 빗소리 주막'));
    await tester.pumpAndSettle();
    expect(find.text('💰 1.5~2만원대'), findsOneWidget);
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

  testWidgets('Phase 2: 페르소나, 불금 저녁 반주 질문, 고양이 펀치 및 클레이 포스터 공유 검증', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 880);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockWeatherService = WeatherService(
      client: MockClient(
        (_) async => http.Response(
          '{"current":{"weather_code":1,"temperature_2m":18.0}}',
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
          locationServiceProvider.overrideWithValue(
            _FakeLocationService(
              const LocationFetchResult(
                location: kDefaultYeonnamLocation,
                isLiveGps: true,
              ),
            ),
          ),
          // 금요일 저녁 19:00 고정 -> 🔥 불금 저녁 + 저녁 2인 이상 한잔 질문 활성화
          currentDateTimeProvider.overrideWithValue(
            () => DateTime(2026, 11, 20, 19, 0),
          ),
        ],
        child: const OreguruApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 두 가게 담기
    await tester.tap(find.text('연남 빗소리 주막'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🛒 후보 장바구니 담기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('오레노 돈코츠 라멘'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🛒 후보 장바구니 담기'));
    await tester.pumpAndSettle();

    // 구루냥 모달 열기 -> 🔥 불금 저녁 태그 노출 & 페르소나 전환 검증
    await tester.tap(find.text('골라줘!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('🔥 불금 저녁'), findsOneWidget);

    await tester.tap(find.byKey(const Key('persona_pickyButler')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('가성비'), findsWidgets);

    // 2인 커플 -> 분위기 -> 맛 선택 -> 저녁 2인+ 동적 반주 질문 자동 진입
    await tester.ensureVisible(find.text('설레는 둘이서 (남녀)'));
    await tester.pump();
    await tester.tap(find.text('설레는 둘이서 (남녀)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.ensureVisible(find.text('시끌벅적 신나게'));
    await tester.pump();
    await tester.tap(find.text('시끌벅적 신나게'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.ensureVisible(find.text('고소·바삭 육즙 폭발'));
    await tester.pump();
    await tester.tap(find.text('고소·바삭 육즙 폭발'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('오늘 가볍게 한잔 곁들일 건가냥?'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('drink_yesDrink')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('drink_yesDrink')));
    await tester.pump();

    // 고양이 펀치 탈락 연출 확인
    await tester.pump(const Duration(milliseconds: 540));
    expect(find.text('🐾 퍽! 탈락'), findsWidgets);

    // 최종 PICK 확인 + 클레이 포스터 공유 다이얼로그 검증
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 260));
    }
    expect(find.text('PICK! 🐾'), findsOneWidget);

    final shareBtn = find.byKey(const Key('share_poster_button'));
    await tester.ensureVisible(shareBtn);
    await tester.pump();
    await tester.tap(shareBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('이의 제기 불가'), findsOneWidget);
    expect(find.byKey(const Key('save_poster_png_button')), findsOneWidget);
    expect(find.byKey(const Key('copy_poster_text_button')), findsOneWidget);

    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map?;
        copiedText = args?['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.ensureVisible(find.byKey(const Key('copy_poster_text_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('copy_poster_text_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(copiedText, contains('이의 제기 불가'));
    expect(find.textContaining('클립보드에 복사했어요'), findsWidgets);
  });

  testWidgets('Phase 2: 비토(Veto) 룰렛 모드 빼기 · 되살리기 · 생존 픽 검증', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 880);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockWeatherService = WeatherService(
      client: MockClient(
        (_) async => http.Response(
          '{"current":{"weather_code":1,"temperature_2m":20.0}}',
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
          locationServiceProvider.overrideWithValue(
            _FakeLocationService(
              const LocationFetchResult(
                location: kDefaultYeonnamLocation,
                isLiveGps: true,
              ),
            ),
          ),
          currentDateTimeProvider.overrideWithValue(
            () => DateTime(2026, 11, 24, 19, 0),
          ),
        ],
        child: const OreguruApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 3곳 장바구니에 담기
    for (final name in [
      '연남 빗소리 주막',
      '오레노 돈코츠 라멘',
      '화로구이 숯불갈비집',
    ]) {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🛒 후보 장바구니 담기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
    }

    // 구루냥 모달 -> 비토 룰렛 모드 진입
    await tester.tap(find.text('골라줘!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final vetoStartBtn = find.byKey(const Key('start_veto_mode_button'));
    await tester.ensureVisible(vetoStartBtn);
    await tester.pump();
    await tester.tap(vetoStartBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('veto_card_rest_01')), findsOneWidget);
    expect(find.byKey(const Key('veto_card_rest_02')), findsOneWidget);
    expect(find.byKey(const Key('veto_card_rest_04')), findsOneWidget);

    // 1곳 빼기 -> Undo 버튼으로 복구 확인
    await tester.tap(find.byKey(const Key('veto_card_rest_01')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('veto_card_rest_01')), findsNothing);
    expect(find.byKey(const Key('veto_undo_button')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('veto_undo_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('veto_undo_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('veto_card_rest_01')), findsOneWidget);

    // 2곳 연속 비토 시 생존한 1곳으로 자동 추첨 완료
    await tester.tap(find.byKey(const Key('veto_card_rest_01')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('veto_card_rest_02')));
    await tester.pump();

    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 260));
    }
    expect(find.text('PICK! 🐾'), findsOneWidget);
    expect(find.text('화로구이 숯불갈비집'), findsWidgets);
  });

  testWidgets('설정 모달, 멀티 길찾기 시트 및 뷰포트 재검색 동작 검증', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 880);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MapNavApp? launchedApp;
    String? launchedName;

    final mockWeatherService = WeatherService(
      client: MockClient(
        (_) async => http.Response(
          '{"current":{"weather_code":1,"temperature_2m":20.0}}',
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
          locationServiceProvider.overrideWithValue(
            _FakeLocationService(
              const LocationFetchResult(
                location: kDefaultYeonnamLocation,
                isLiveGps: true,
              ),
            ),
          ),
          // 브레이크타임 시간(15:30) 고정 -> 오레노 돈코츠 라멘은 브레이크타임
          currentDateTimeProvider.overrideWithValue(
            () => DateTime(2026, 11, 24, 15, 30),
          ),
          navigationLaunchHandlerProvider.overrideWithValue(({
            required MapNavApp app,
            required double latitude,
            required double longitude,
            required String name,
          }) async {
            launchedApp = app;
            launchedName = name;
            return true;
          }),
        ],
        child: const OreguruApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 설정(⚙️) 모달 열기 -> 지도 전환 & DB 설정 항목 노출 확인
    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle();
    expect(find.text('⚙️ 지도 및 데이터 설정'), findsOneWidget);
    expect(find.text('🗺️ Google Maps 지도로 전환'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 2. 브레이크타임 배지 & 4종 길찾기 앱 선택 시트 검증
    await tester.tap(find.text('오레노 돈코츠 라멘'));
    await tester.pumpAndSettle();
    expect(find.text('브레이크타임'), findsOneWidget);
    expect(find.text('💰 1~1.5만원대'), findsOneWidget);

    await tester.tap(find.text('길찾기'));
    await tester.pumpAndSettle();
    expect(find.text('🧭 길찾기 앱 선택'), findsOneWidget);
    expect(find.text('네이버 지도'), findsOneWidget);
    expect(find.text('카카오맵'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Apple Maps'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_app_kakao')));
    await tester.pumpAndSettle();
    expect(launchedApp, MapNavApp.kakao);
    expect(launchedName, '오레노 돈코츠 라멘');

    // 바텀 시트 닫은 뒤 뷰포트 이동 및 반경 필터 검증
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    // 3. 뷰포트 150m 이상 이동 시 "이 지역에서 재검색" 노출 & 적용 시 searchCenter 이동
    final element = tester.element(find.byType(OreguruApp));
    final container = ProviderScope.containerOf(element);
    container.read(mapExplorerProvider.notifier).setPendingViewportCenter(
          const GeoPoint2D(latitude: 37.5500, longitude: 126.9200),
        );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('viewport_research_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('viewport_research_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('viewport_research_button')), findsNothing);

    // 500m 필터 활성화 시 멀리 이동한 중심점 기준으로 연남동 매장들이 필터 아웃됨
    await tester.drag(find.byType(OneTapFilterBar), const Offset(-260, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('📍 내 주변 500m'));
    await tester.pumpAndSettle();
    expect(find.text('오레노 돈코츠 라멘'), findsNothing);

    // 내 위치(🎯) 버튼 탭 시 연남동 GPS로 복귀되어 다시 노출
    await tester.tap(find.byKey(const Key('locate_me_button')));
    await tester.pumpAndSettle();
    expect(find.text('오레노 돈코츠 라멘'), findsOneWidget);
  });

  test('CatDialogueEngine 상황별 대사 및 저녁 2인+ 반주 질문 분기 검증', () {
    // 2026-11-20 is Friday
    final fridayNight = DateTime(2026, 11, 20, 19, 30);
    // 2026-11-23 is Monday
    final mondayLunch = DateTime(2026, 11, 23, 12, 15);
    final lateNight = DateTime(2026, 11, 24, 23, 30);

    expect(CatDialogueEngine.resolveSituationTag(fridayNight), '🔥 불금 저녁');
    expect(CatDialogueEngine.resolveSituationTag(mondayLunch), '💥 헬요일 점심');
    expect(CatDialogueEngine.resolveSituationTag(lateNight), '🌙 심야 야식 타임');

    expect(
      CatDialogueEngine.buildOpeningDialogue(
        persona: CatPersona.classic,
        now: fridayNight,
      ),
      contains('불금'),
    );
    expect(
      CatDialogueEngine.buildOpeningDialogue(
        persona: CatPersona.classic,
        now: mondayLunch,
      ),
      contains('월요일 점심'),
    );

    expect(
      CatDialogueEngine.shouldAskDrinkQuestion(
        party: PartyType.coupleMF,
        now: fridayNight,
      ),
      isTrue,
    );
    expect(
      CatDialogueEngine.shouldAskDrinkQuestion(
        party: PartyType.coupleMF,
        now: mondayLunch,
      ),
      isFalse,
    );
    expect(
      CatDialogueEngine.shouldAskDrinkQuestion(
        party: PartyType.soloMale,
        now: fridayNight,
      ),
      isFalse,
    );
  });

  test('CatPersona 가중치 스코어링 (깐깐한 집사냥 vs 모험가냥) 검증', () {
    final izakayaWaiting = RestaurantRepository.seedRestaurants
        .firstWhere((r) => r.id == 'rest_06'); // 웨이팅 있음, 2~3만원대, 평점 4.9
    final affordableNoWait = RestaurantRepository.seedRestaurants
        .firstWhere((r) => r.id == 'rest_05'); // 웨이팅 없음, 1~1.5만원대, 매콤

    final butlerIzakayaScore = CatDecisionNotifier.scoreRestaurantForPersona(
      izakayaWaiting,
      persona: CatPersona.pickyButler,
    );
    final butlerAffordableScore = CatDecisionNotifier.scoreRestaurantForPersona(
      affordableNoWait,
      persona: CatPersona.pickyButler,
    );
    expect(butlerAffordableScore, greaterThan(butlerIzakayaScore));

    final adventurerIzakayaScore = CatDecisionNotifier.scoreRestaurantForPersona(
      izakayaWaiting,
      persona: CatPersona.adventurer,
    );
    expect(adventurerIzakayaScore, greaterThan(0));
  });

  test('22개 3D 클레이 PNG 에셋 번들 등록 및 로드 검증', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final paths = <String>[
      'assets/images/clay/gurunyan_mascot.png',
      ...PartyType.values.map((e) => e.assetPath),
      ...VibePreference.values.map((e) => e.assetPath),
      ...TastePreference.values.map((e) => e.assetPath),
      ...ClayMarkerType.values.map((e) => e.assetPath),
    ];
    expect(paths.length, 22);
    for (final path in paths) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(1000), reason: 'Asset $path empty');
    }
  });

  test('OpeningHoursSchedule 실시간 영업중 · 브레이크타임 · 심야 · 정기휴무 검증', () {
    const lunchDinnerPlace = OpeningHoursSchedule(
      openTime: '11:30',
      closeTime: '21:30',
      breakStart: '15:00',
      breakEnd: '17:00',
      closedWeekdays: [DateTime.sunday],
    );

    expect(
      lunchDinnerPlace.evaluateStatus(DateTime(2026, 11, 24, 12, 0)),
      OpenStatus.open,
    );
    expect(
      lunchDinnerPlace.evaluateStatus(DateTime(2026, 11, 24, 15, 30)),
      OpenStatus.breakTime,
    );
    expect(
      lunchDinnerPlace.evaluateStatus(DateTime(2026, 11, 24, 10, 0)),
      OpenStatus.closed,
    );
    expect(
      lunchDinnerPlace.evaluateStatus(DateTime(2026, 11, 24, 22, 0)),
      OpenStatus.closed,
    );
    expect(
      lunchDinnerPlace.evaluateStatus(DateTime(2026, 11, 22, 13, 0)),
      OpenStatus.closed,
    );

    const lateNightIzakaya = OpeningHoursSchedule(
      openTime: '17:30',
      closeTime: '02:00',
      closedWeekdays: [DateTime.monday],
    );
    expect(
      lateNightIzakaya.evaluateStatus(DateTime(2026, 11, 25, 1, 15)),
      OpenStatus.open,
    );
    expect(
      lateNightIzakaya.evaluateStatus(DateTime(2026, 11, 24, 1, 15)),
      OpenStatus.closed,
    );
    expect(
      lateNightIzakaya.evaluateStatus(DateTime(2026, 11, 25, 2, 30)),
      OpenStatus.closed,
    );
  });

  test('LocationService Haversine 직선 거리 계산 및 포맷팅 검증', () {
    final sameMeters = LocationService.calculateDistanceMeters(
      startLat: kDefaultYeonnamLocation.latitude,
      startLng: kDefaultYeonnamLocation.longitude,
      endLat: kDefaultYeonnamLocation.latitude,
      endLng: kDefaultYeonnamLocation.longitude,
    );
    expect(sameMeters, 0.0);

    final firstSeed = RestaurantRepository.seedRestaurants.first;
    final meters = LocationService.roundedDistanceMeters(
      kDefaultYeonnamLocation,
      targetLat: firstSeed.latitude,
      targetLng: firstSeed.longitude,
    );
    expect(meters, greaterThan(100));
    expect(meters, lessThan(200));

    expect(LocationService.formatDistance(0), '0m');
    expect(LocationService.formatDistance(280), '280m');
    expect(LocationService.formatDistance(1250), '1.3km');
  });

  test('NavigationLauncher 4대 지도 앱 딥링크/폴백 URL 생성 검증', () {
    final naverApp = NavigationLauncher.buildAppUri(
      MapNavApp.naver,
      latitude: 37.5624,
      longitude: 126.9252,
      name: '연남 빗소리 주막',
    );
    expect(naverApp.scheme, 'nmap');
    expect(naverApp.queryParameters['dlat'], '37.5624');

    final kakaoApp = NavigationLauncher.buildAppUri(
      MapNavApp.kakao,
      latitude: 37.5624,
      longitude: 126.9252,
      name: '연남 빗소리 주막',
    );
    expect(kakaoApp.scheme, 'kakaomap');

    final googleWeb = NavigationLauncher.buildWebFallbackUri(
      MapNavApp.google,
      latitude: 37.5624,
      longitude: 126.9252,
      name: '연남 빗소리 주막',
    );
    expect(googleWeb.host, 'www.google.com');

    final appleWeb = NavigationLauncher.buildWebFallbackUri(
      MapNavApp.apple,
      latitude: 37.5624,
      longitude: 126.9252,
      name: '연남 빗소리 주막',
    );
    expect(appleWeb.host, 'maps.apple.com');
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

  test('RestaurantModel Firestore/JSON 직렬화 및 Tombstone Delta Sync 검증', () async {
    final original = RestaurantRepository.seedRestaurants.first.copyWith(
      thumbnailUrl: 'https://example.com/pajeon.jpg',
    );
    final map = original.toFirestore();
    final restored = RestaurantModel.fromMap(map);

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.thumbnailUrl, 'https://example.com/pajeon.jpg');
    expect(restored.priceRangeText, original.priceRangeText);
    expect(restored.openingHours?.openTime, original.openingHours?.openTime);
    expect(restored.openingHours?.closeTime, original.openingHours?.closeTime);
    expect(restored.heroColor.toARGB32(), original.heroColor.toARGB32());
    expect(restored.suitableParties, original.suitableParties);
    expect(restored.weatherComments[WeatherCondition.rainy],
        original.weatherComments[WeatherCondition.rainy]);
    expect(restored.updatedAtMillis, original.updatedAtMillis);

    final updatedExisting = original.copyWith(
      name: '연남 빗소리 주막 (리뉴얼)',
      updatedAtMillis: 1763350000000,
    );
    final newPlace = original.copyWith(
      id: 'rest_99',
      name: '망원 야키토리',
      updatedAtMillis: 1763350001000,
    );
    final tombstoneTarget = RestaurantRepository.seedRestaurants[1].copyWith(
      isDeleted: true,
      updatedAtMillis: 1763350002000,
    );

    final merged = RestaurantRepository.mergeDeltaRestaurants(
      existing: RestaurantRepository.seedRestaurants,
      deltas: [updatedExisting, newPlace, tombstoneTarget],
    );

    expect(merged.length, RestaurantRepository.seedRestaurants.length);
    expect(
      merged.firstWhere((r) => r.id == original.id).name,
      '연남 빗소리 주막 (리뉴얼)',
    );
    expect(merged.any((r) => r.id == 'rest_99'), isTrue);
    expect(merged.any((r) => r.id == tombstoneTarget.id), isFalse);

    final cache = LocalRestaurantCache();
    await cache.clear();
    await cache.saveSnapshot(
      restaurants: merged,
      lastSyncMillis: 1763350002000,
    );
    final loaded = await cache.loadSnapshot();
    expect(loaded, isNotNull);
    expect(loaded!.restaurants.length, merged.length);
    expect(loaded.lastSyncMillis, 1763350002000);
    await cache.clear();
  });
}
