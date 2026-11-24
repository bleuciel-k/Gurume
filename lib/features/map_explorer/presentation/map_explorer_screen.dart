import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:oreguru/core/constants/api_config.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/constants/map_style.dart';
import 'package:oreguru/core/services/firebase_service.dart';
import 'package:oreguru/core/services/location_service.dart';
import 'package:oreguru/core/services/maps_platform_bridge.dart';
import 'package:oreguru/core/services/marker_bitmap_cache.dart';
import 'package:oreguru/core/widgets/clay_button.dart';
import 'package:oreguru/core/widgets/clay_container.dart';
import 'package:oreguru/data/models/restaurant_model.dart';
import 'package:oreguru/data/repositories/restaurant_repository.dart';
import 'package:oreguru/features/candidate_tray/presentation/widgets/floating_candidate_tray.dart';
import 'package:oreguru/features/candidate_tray/providers/candidate_provider.dart';
import 'package:oreguru/features/cat_decision/presentation/cat_decision_modal.dart';
import 'package:oreguru/features/map_explorer/presentation/widgets/clay_3d_marker_widget.dart';
import 'package:oreguru/features/map_explorer/presentation/widgets/one_tap_filter_bar.dart';
import 'package:oreguru/features/map_explorer/presentation/widgets/restaurant_bottom_sheet.dart';
import 'package:oreguru/features/map_explorer/providers/map_filter_provider.dart';

/// 메인 지도 화면:
/// - 상단 맛집/메뉴 실시간 검색창 (기본 탐색 중심) + 원탭 필터 4개
/// - Google Maps SDK(3D 클레이 BitmapDescriptor 마커) & 2D 클레이 캔버스 지원
/// - 가게 클릭 시에만 하단 바텀 시트 등장 (초기 화면 하단 시야 100% 확보)
/// - 장바구니처럼 후보를 담으면 오른쪽 가장자리에 1열 세로로 슬림하게 나열
class MapExplorerScreen extends ConsumerStatefulWidget {
  const MapExplorerScreen({super.key});

  @override
  ConsumerState<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends ConsumerState<MapExplorerScreen> {
  bool _useNativeGoogleMap = false;
  bool _isLoadingMapSdk = false;
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final MarkerBitmapCache _markerBitmapCache = MarkerBitmapCache();
  Map<String, BitmapDescriptor> _markerBitmaps = const {};
  String _lastMarkerSignature = '';

  @override
  void initState() {
    super.initState();
    // 웹에서 컴파일 타임/저장된 Google Maps API 키가 이미 있으면 자동 프리로드
    if (isGoogleMapsWebPlatform() && !isGoogleMapsSdkReady()) {
      final presetKey = ApiConfig.hasCompileTimeGoogleMapsKey
          ? ApiConfig.googleMapsApiKey
          : getStoredWebMapsApiKey();
      if (presetKey.isNotEmpty) {
        loadGoogleMapsWebSdk(presetKey);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _markerBitmapCache.clear();
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  Future<void> _animateCameraTo(
    GeoPoint2D target, {
    double zoom = 16.0,
  }) async {
    final controller = _mapController;
    if (!_useNativeGoogleMap || controller == null) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(target.latitude, target.longitude),
          zoom,
        ),
      );
    } catch (_) {
      // 맵 뷰가 아직 준비되지 않았거나 전환 직전이면 무시
    }
  }

  Future<void> _handleLocateMe() async {
    HapticFeedback.selectionClick();
    final result =
        await ref.read(mapExplorerProvider.notifier).recenterToUserLocation();
    await _animateCameraTo(result.location, zoom: 16.0);
    if (!mounted) return;
    if (!result.isLiveGps) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.textEspresso,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.buttonInput),
          ),
          content: const Text(
            '위치 권한이 없어 기본 중심(연남동)으로 이동했어요.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
  }

  void _scheduleMarkerBitmapSync(
    List<RestaurantModel> restaurants, {
    required String? selectedId,
    required Set<String> candidateIds,
  }) {
    final signature = [
      restaurants.map((r) => r.id).join(','),
      selectedId ?? '',
      (candidateIds.toList()..sort()).join(','),
    ].join('|');

    if (signature == _lastMarkerSignature) return;
    _lastMarkerSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final bitmaps = await _markerBitmapCache.buildMarkersMap(
        restaurants,
        selectedId: selectedId,
        candidateIds: candidateIds,
      );
      if (mounted) {
        setState(() => _markerBitmaps = bitmaps);
      }
    });
  }

  Future<bool> _toggleGoogleMapMode({String? webApiKeyOverride}) async {
    if (_useNativeGoogleMap) {
      _mapController = null;
      setState(() => _useNativeGoogleMap = false);
      return true;
    }

    if (!isGoogleMapsWebPlatform() || isGoogleMapsSdkReady()) {
      setState(() => _useNativeGoogleMap = true);
      return true;
    }

    final keyCandidate = webApiKeyOverride?.trim().isNotEmpty == true
        ? webApiKeyOverride!.trim()
        : (ApiConfig.hasCompileTimeGoogleMapsKey
            ? ApiConfig.googleMapsApiKey
            : getStoredWebMapsApiKey());

    if (keyCandidate.isNotEmpty) {
      return _activateWebMapsWithKey(keyCandidate);
    }

    return false;
  }

  Future<bool> _activateWebMapsWithKey(String apiKey) async {
    setState(() => _isLoadingMapSdk = true);
    final loaded = await loadGoogleMapsWebSdk(apiKey.trim());
    if (!mounted) return loaded;
    setState(() {
      _isLoadingMapSdk = false;
      if (loaded) {
        _useNativeGoogleMap = true;
      }
    });

    if (!loaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.textEspresso,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.buttonInput),
          ),
          content: const Text(
            'Google Maps SDK 로드에 실패했어요. API 키와 Maps JavaScript API 활성화 상태를 확인해 주세요.',
          ),
        ),
      );
    }
    return loaded;
  }

  /// 지도 전환 · Web Maps API 키 · Firestore DB 동기화 · 위치/캐시 상태를 한곳에 모은 설정 모달
  Future<void> _showSettingsModal() async {
    final firebase = ref.read(firebaseServiceProvider);
    final repo = ref.read(restaurantRepositoryProvider);
    final mapsKeyCtrl = TextEditingController(text: getStoredWebMapsApiKey());
    final apiKeyCtrl = TextEditingController();
    final appIdCtrl = TextEditingController();
    final projectIdCtrl = TextEditingController();
    final databaseIdCtrl = TextEditingController(text: '(default)');

    String? statusFeedback;
    bool busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isConnected = firebase.isConnected;
            final lastSync = repo.lastSyncMillis;
            final lastSyncText = lastSync > 0
                ? DateTime.fromMillisecondsSinceEpoch(lastSync)
                    .toLocal()
                    .toString()
                    .substring(0, 19)
                : '로컬 시드 캐시 사용 중';
            final explorer = ref.read(mapExplorerProvider);

            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClayContainer(
                variant: ClaySurfaceVariant.card,
                borderRadius: AppRadii.sheetPanel,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '⚙️ 지도 및 데이터 설정',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textEspresso,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.of(dialogContext).pop(),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.textTaupe,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 섹션 1: 지도 엔진 & 위치 상태
                      ClayContainer(
                        variant: ClaySurfaceVariant.recessed,
                        borderRadius: AppRadii.buttonInput,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🗺️ 현재 지도: ${_useNativeGoogleMap ? 'Google Maps SDK' : '2D 클레이 캔버스'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textEspresso,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              explorer.hasLiveGps
                                  ? '📍 GPS 수신됨 (${explorer.userLocation.latitude.toStringAsFixed(4)}, ${explorer.userLocation.longitude.toStringAsFixed(4)})'
                                  : '📍 기본 기준 위치 사용 중 (연남동)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTaupe,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (isGoogleMapsWebPlatform() &&
                                !isGoogleMapsSdkReady() &&
                                !ApiConfig.hasCompileTimeGoogleMapsKey) ...[
                              _DialogInputField(
                                controller: mapsKeyCtrl,
                                hint: 'Google Maps Web API Key (AIzaSy...)',
                              ),
                              const SizedBox(height: 8),
                            ],
                            ClayButton(
                              variant: _useNativeGoogleMap
                                  ? ClaySurfaceVariant.raised
                                  : ClaySurfaceVariant.accent,
                              borderRadius: AppRadii.buttonInput,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              onPressed: busy || _isLoadingMapSdk
                                  ? null
                                  : () async {
                                      final ok = await _toggleGoogleMapMode(
                                        webApiKeyOverride: mapsKeyCtrl.text,
                                      );
                                      setDialogState(() {
                                        statusFeedback = ok
                                            ? (_useNativeGoogleMap
                                                ? 'Google Maps 모드로 전환했어요.'
                                                : '2D 클레이 맵 모드로 전환했어요.')
                                            : '웹에서 Google Maps를 켜려면 Maps JavaScript API 키를 입력해 주세요.';
                                      });
                                    },
                              child: Center(
                                child: Text(
                                  _isLoadingMapSdk
                                      ? 'Google Maps 로딩 중...'
                                      : (_useNativeGoogleMap
                                          ? '🎨 2D 클레이 맵으로 전환'
                                          : '🗺️ Google Maps 지도로 전환'),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _useNativeGoogleMap
                                        ? AppColors.textEspresso
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 섹션 2: Firestore DB 캐시 동기화
                      ClayContainer(
                        variant: ClaySurfaceVariant.recessed,
                        borderRadius: AppRadii.buttonInput,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnected
                                  ? '🔥 DB 연결됨: ${firebase.activeProjectId} (${firebase.activeDatabaseId})'
                                  : '💾 로컬 디스크 캐시 모드 (Firestore 미연결)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textEspresso,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '마지막 동기화: $lastSyncText',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTaupe,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (statusFeedback != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          statusFeedback!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.clayOrangeDark,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (isConnected) ...[
                        ClayButton(
                          variant: ClaySurfaceVariant.accent,
                          borderRadius: AppRadii.buttonInput,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: busy
                              ? null
                              : () async {
                                  setDialogState(() {
                                    busy = true;
                                    statusFeedback = null;
                                  });
                                  final report =
                                      await repo.syncDeltaFromFirestore();
                                  ref.invalidate(restaurantsProvider);
                                  setDialogState(() {
                                    busy = false;
                                    statusFeedback = report.errorMessage != null
                                        ? '동기화 실패: ${report.errorMessage}'
                                        : '증분 동기화 완료! 변경분 ${report.deltaFetchedCount}건 반영 (총 ${report.totalCount}곳)';
                                  });
                                },
                          child: Text(
                            busy
                                ? '동기화 중...'
                                : '🔄 증분 동기화 (updatedAt > lastSync)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClayButton(
                          variant: ClaySurfaceVariant.raised,
                          borderRadius: AppRadii.buttonInput,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: busy
                              ? null
                              : () async {
                                  setDialogState(() {
                                    busy = true;
                                    statusFeedback = null;
                                  });
                                  try {
                                    final count =
                                        await repo.seedRestaurantsToFirestore();
                                    setDialogState(() {
                                      busy = false;
                                      statusFeedback =
                                          '시드 맛집 $count곳을 Firestore에 업로드했어요!';
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      busy = false;
                                      statusFeedback =
                                          '업로드 실패 (보안규칙 확인): $e';
                                    });
                                  }
                                },
                          child: const Text(
                            '🌱 초기 맛집 8곳 시드 업로드',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textEspresso,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClayButton(
                          variant: ClaySurfaceVariant.raised,
                          borderRadius: AppRadii.buttonInput,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          onPressed: busy
                              ? null
                              : () async {
                                  await firebase.disconnectRuntime();
                                  setDialogState(() {
                                    statusFeedback = '로컬 캐시 모드로 전환했어요.';
                                  });
                                },
                          child: const Text(
                            '연결 해제 (로컬 캐시로 전환)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTaupe,
                            ),
                          ),
                        ),
                      ] else ...[
                        _DialogInputField(
                          controller: projectIdCtrl,
                          hint: 'Firebase Project ID (예: oreguru-app)',
                        ),
                        const SizedBox(height: 8),
                        _DialogInputField(
                          controller: apiKeyCtrl,
                          hint: 'Firebase Web API Key (AIzaSy...)',
                        ),
                        const SizedBox(height: 8),
                        _DialogInputField(
                          controller: appIdCtrl,
                          hint: 'Firebase App ID (1:...:web:...)',
                        ),
                        const SizedBox(height: 8),
                        _DialogInputField(
                          controller: databaseIdCtrl,
                          hint: 'Database ID (기본: (default))',
                        ),
                        const SizedBox(height: 12),
                        ClayButton(
                          variant: ClaySurfaceVariant.accent,
                          borderRadius: AppRadii.buttonInput,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: busy
                              ? null
                              : () async {
                                  setDialogState(() {
                                    busy = true;
                                    statusFeedback = null;
                                  });
                                  final ok = await firebase.connectRuntime(
                                    FirebaseRuntimeConfig(
                                      apiKey: apiKeyCtrl.text.trim(),
                                      appId: appIdCtrl.text.trim(),
                                      projectId: projectIdCtrl.text.trim(),
                                      databaseId: databaseIdCtrl.text.trim(),
                                    ),
                                  );
                                  if (ok) {
                                    final report =
                                        await repo.syncDeltaFromFirestore();
                                    ref.invalidate(restaurantsProvider);
                                    setDialogState(() {
                                      busy = false;
                                      statusFeedback = report.errorMessage != null
                                          ? '연결됨! (동기화 참고: ${report.errorMessage})'
                                          : 'Firebase 연결 & 동기화 완료! (총 ${report.totalCount}곳)';
                                    });
                                  } else {
                                    setDialogState(() {
                                      busy = false;
                                      statusFeedback =
                                          'Project ID, API Key, App ID를 모두 확인해 주세요.';
                                    });
                                  }
                                },
                          child: Text(
                            busy ? '연결 중...' : '🔗 Firebase 프로젝트 연결',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    mapsKeyCtrl.dispose();
    apiKeyCtrl.dispose();
    appIdCtrl.dispose();
    projectIdCtrl.dispose();
    databaseIdCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredRestaurants = ref.watch(filteredRestaurantsProvider);
    final selectedRestaurant = ref.watch(selectedRestaurantProvider);
    final candidates = ref.watch(candidateTrayProvider);
    final explorerState = ref.watch(mapExplorerProvider);

    ref.listen<String?>(
      mapExplorerProvider.select((s) => s.selectedRestaurantId),
      (prev, next) {
        if (next == null || next == prev) return;
        final restaurants =
            ref.read(restaurantsProvider).valueOrNull ?? const [];
        for (final r in restaurants) {
          if (r.id == next) {
            _animateCameraTo(
              GeoPoint2D(latitude: r.latitude, longitude: r.longitude),
              zoom: 16.5,
            );
            break;
          }
        }
      },
    );

    final candidateIds = candidates.map((e) => e.id).toSet();
    final hasSearchQuery = explorerState.searchQuery.trim().isNotEmpty;

    _scheduleMarkerBitmapSync(
      filteredRestaurants,
      selectedId: selectedRestaurant?.id,
      candidateIds: candidateIds,
    );

    return Scaffold(
      backgroundColor: AppColors.bgIvory,
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 지도 레이어 (실제 Google Maps SDK + 3D 클레이 BitmapDescriptor OR 로컬 클레이 2D 캔버스)
            Positioned.fill(
              child: _useNativeGoogleMap
                  ? _buildNativeGoogleMap(
                      filteredRestaurants,
                      explorerState,
                    )
                  : _Clay2DMapCanvas(
                      restaurants: filteredRestaurants,
                      selectedId: selectedRestaurant?.id,
                      candidateIds: candidateIds,
                      onTapMapBackground: () {
                        FocusScope.of(context).unfocus();
                        ref
                            .read(mapExplorerProvider.notifier)
                            .selectRestaurant(null);
                      },
                      onTapMarker: (id) {
                        FocusScope.of(context).unfocus();
                        HapticFeedback.selectionClick();
                        ref
                            .read(mapExplorerProvider.notifier)
                            .selectRestaurant(id);
                      },
                    ),
            ),

            // 2. 상단 헤더: 브랜드+설정 버튼 -> 맛집/메뉴 검색창 -> 원탭 필터 -> 재검색/검색결과 퀵바
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      ClayContainer(
                        variant: ClaySurfaceVariant.raised,
                        borderRadius: AppRadii.cardChip,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 7,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('😼', style: TextStyle(fontSize: 17)),
                            SizedBox(width: 6),
                            Text(
                              'オレグル',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textEspresso,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // 프로덕션 설정 버튼(지도 전환 / DB 동기화 / GPS 진단 통합)
                      ClayButton(
                        key: const Key('settings_button'),
                        variant: ClaySurfaceVariant.raised,
                        borderRadius: AppRadii.buttonInput,
                        padding: const EdgeInsets.all(8),
                        onPressed: _showSettingsModal,
                        child: const Icon(
                          Icons.settings_rounded,
                          size: 20,
                          color: AppColors.textEspresso,
                        ),
                      ),
                    ],
                  ),
                ),

                // 가게 / 메뉴 실시간 검색창
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: ClayContainer(
                    variant: ClaySurfaceVariant.card,
                    borderRadius: AppRadii.buttonInput,
                    border: Border.all(
                      color: AppColors.inputStroke,
                      width: 1.0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppColors.clayOrange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) => ref
                                .read(mapExplorerProvider.notifier)
                                .setSearchQuery(value),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textEspresso,
                            ),
                            decoration: const InputDecoration(
                              hintText: '가게 이름, 메뉴(라멘, 파전 등) 검색...',
                              hintStyle: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        if (hasSearchQuery)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              ref
                                  .read(mapExplorerProvider.notifier)
                                  .setSearchQuery('');
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.bgWarmSand,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: AppColors.textTaupe,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 원탭 상황별 필터 칩 4개
                const OneTapFilterBar(),

                // 지도 이동 시 노출되는 "이 지역에서 재검색" 버튼
                if (explorerState.shouldShowViewportResearch)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Center(
                      child: ClayButton(
                        key: const Key('viewport_research_button'),
                        variant: ClaySurfaceVariant.raised,
                        borderRadius: AppRadii.buttonInput,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(mapExplorerProvider.notifier)
                              .applyViewportSearch();
                        },
                        child: const Text(
                          '🔄 이 지역에서 재검색',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.clayOrangeDark,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 검색어 입력 시 일치하는 가게 바로 선택 칩 리스트
                if (hasSearchQuery)
                  _SearchQuickResultStrip(
                    results: filteredRestaurants,
                    distanceFormatter: (r) => LocationService.formatDistance(
                      explorerState.distanceMetersFromCenter(r),
                    ),
                    onSelect: (id) {
                      FocusScope.of(context).unfocus();
                      ref
                          .read(mapExplorerProvider.notifier)
                          .selectRestaurant(id);
                    },
                  ),
                  ],
                ),
              ),
            ),

            // 3. 좌측 하단 내 위치로 이동 버튼 (🎯)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: 16,
              bottom: selectedRestaurant != null ? 320 : 22,
              child: SafeArea(
                top: false,
                child: ClayButton(
                  key: const Key('locate_me_button'),
                  variant: ClaySurfaceVariant.raised,
                  borderRadius: AppRadii.buttonInput,
                  padding: const EdgeInsets.all(11),
                  onPressed: explorerState.isLocating ? null : _handleLocateMe,
                  child: explorerState.isLocating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.clayOrange,
                          ),
                        )
                      : Icon(
                          Icons.my_location_rounded,
                          size: 20,
                          color: explorerState.hasLiveGps
                              ? AppColors.clayOrange
                              : AppColors.textEspresso,
                        ),
                ),
              ),
            ),

            // 4. 우측 1열 세로 후보지 장바구니 (후보가 1곳 이상 담겼을 때만 노출)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              right: 12,
              bottom: selectedRestaurant != null ? 320 : 22,
              child: SafeArea(
                top: false,
                child: FloatingCandidateTray(
                  onCallGuruNyan: () => CatDecisionModal.show(context, ref),
                ),
              ),
            ),

            // 5. 가게 마커/검색결과 클릭 시에만 올라오는 상세 바텀 시트
            if (selectedRestaurant != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: RestaurantBottomSheet(
                    key: ValueKey('sheet_${selectedRestaurant.id}'),
                    restaurant: selectedRestaurant,
                    onClose: () => ref
                        .read(mapExplorerProvider.notifier)
                        .selectRestaurant(null),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 실제 Google Maps Platform SDK 뷰 (kOreguruMapStyleJson + 3D 클레이 BitmapDescriptor 마커 적용)
  Widget _buildNativeGoogleMap(
    List<RestaurantModel> restaurants,
    MapExplorerState explorerState,
  ) {
    final markers = restaurants.map((r) {
      final customIcon = _markerBitmaps[r.id];
      return Marker(
        markerId: MarkerId(r.id),
        position: LatLng(r.latitude, r.longitude),
        icon: customIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        anchor: const Offset(0.5, 0.72),
        onTap: () =>
            ref.read(mapExplorerProvider.notifier).selectRestaurant(r.id),
      );
    }).toSet();

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          explorerState.searchCenter.latitude,
          explorerState.searchCenter.longitude,
        ),
        zoom: 16.0,
      ),
      style: kOreguruMapStyleJson,
      myLocationEnabled: explorerState.hasLiveGps,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      markers: markers,
      onMapCreated: (controller) {
        _mapController = controller;
      },
      onCameraMove: (position) {
        ref.read(mapExplorerProvider.notifier).setPendingViewportCenter(
              GeoPoint2D(
                latitude: position.target.latitude,
                longitude: position.target.longitude,
              ),
            );
      },
      onTap: (_) =>
          ref.read(mapExplorerProvider.notifier).selectRestaurant(null),
    );
  }
}

class _SearchQuickResultStrip extends StatelessWidget {
  final List<RestaurantModel> results;
  final String Function(RestaurantModel) distanceFormatter;
  final ValueChanged<String> onSelect;

  const _SearchQuickResultStrip({
    required this.results,
    required this.distanceFormatter,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ClayContainer(
          variant: ClaySurfaceVariant.card,
          borderRadius: AppRadii.buttonInput,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: const Text(
            '검색 조건에 맞는 가게가 없어요. 필터를 조절하거나 다른 메뉴로 검색해 보세요!',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textTaupe,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final r = results[index];
          return GestureDetector(
            onTap: () => onSelect(r.id),
            child: ClayContainer(
              variant: ClaySurfaceVariant.raised,
              borderRadius: AppRadii.buttonInput,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: Border.all(
                color: AppColors.clayOrange.withAlpha(110),
                width: 1.2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r.clayMarkerType.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textEspresso,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    distanceFormatter(r),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.clayOrangeDark,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// API 키 없이도 2D 저채도 아이보리(#F1E6D2) 맵 + 3D 클레이 마커를
/// 즉시 검증할 수 있는 2D 커스텀 지도 캔버스
class _Clay2DMapCanvas extends StatelessWidget {
  final List<RestaurantModel> restaurants;
  final String? selectedId;
  final Set<String> candidateIds;
  final VoidCallback onTapMapBackground;
  final ValueChanged<String> onTapMarker;

  const _Clay2DMapCanvas({
    required this.restaurants,
    required this.selectedId,
    required this.candidateIds,
    required this.onTapMapBackground,
    required this.onTapMarker,
  });

  Offset _project(RestaurantModel r, Size size) {
    const minLat = 37.5582;
    const maxLat = 37.5646;
    const minLng = 126.9215;
    const maxLng = 126.9292;

    final tx = ((r.longitude - minLng) / (maxLng - minLng)).clamp(0.0, 1.0);
    final ty = (1.0 - (r.latitude - minLat) / (maxLat - minLat)).clamp(0.0, 1.0);

    // 상단 검색창·원탭 필터바 아래(~195px)와 우측 장바구니 여백을 피해서 배치
    final minX = 56.0;
    final maxX = math.max(minX + 80.0, size.width - 108.0);
    final minY = math.max(198.0, size.height * 0.27);
    final maxY = math.max(minY + 120.0, size.height - 95.0);

    return Offset(
      minX + tx * (maxX - minX),
      minY + ty * (maxY - minY),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapMapBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final myDotX = size.width * 0.45;
          final minY = math.max(198.0, size.height * 0.27);
          final maxY = math.max(minY + 120.0, size.height - 95.0);
          final myDotY = minY + (maxY - minY) * 0.50;

          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                size: size,
                painter: _Flat2DMapBackgroundPainter(
                  center: Offset(myDotX, myDotY),
                ),
              ),
              Positioned(
                left: myDotX - 11,
                top: myDotY - 11,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.clayOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.clayOrange.withAlpha(90),
                        blurRadius: 12,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              ...restaurants.map((r) {
                final pos = _project(r, size);
                return Positioned(
                  left: pos.dx - 44,
                  top: pos.dy - 54,
                  child: Clay3DMarkerWidget(
                    restaurant: r,
                    isSelected: r.id == selectedId,
                    isCandidate: candidateIds.contains(r.id),
                    onTap: () => onTapMarker(r.id),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _Flat2DMapBackgroundPainter extends CustomPainter {
  final Offset center;

  const _Flat2DMapBackgroundPainter({required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    // 따뜻한 아이보리 바탕 (#F1E6D2)
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.bgIvory,
    );

    // 저채도 연두빛 공원 구역
    final parkPaint = Paint()..color = const Color(0xFFDCE5C9);
    final parkPath = Path()
      ..moveTo(size.width * 0.14, 0)
      ..lineTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.54, size.height)
      ..lineTo(size.width * 0.42, size.height)
      ..close();
    canvas.drawPath(parkPath, parkPaint);

    // 일반 평면 2D 건물 블록
    final flatBuildingPaint = Paint()..color = const Color(0xFFE5D7BD);
    final flatBuildings = [
      Rect.fromLTWH(size.width * 0.06, size.height * 0.26, 58, 44),
      Rect.fromLTWH(size.width * 0.56, size.height * 0.25, 70, 50),
      Rect.fromLTWH(size.width * 0.64, size.height * 0.42, 62, 46),
      Rect.fromLTWH(size.width * 0.08, size.height * 0.54, 62, 56),
      Rect.fromLTWH(size.width * 0.54, size.height * 0.62, 78, 50),
      Rect.fromLTWH(size.width * 0.32, size.height * 0.28, 54, 42),
    ];
    for (final rect in flatBuildings) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        flatBuildingPaint,
      );
    }

    // 도로 네트워크
    final roadPaint = Paint()
      ..color = AppColors.clayCream
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final subRoadPaint = Paint()
      ..color = AppColors.clayCream
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height * 0.38),
      Offset(size.width, size.height * 0.43),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.64),
      Offset(size.width, size.height * 0.58),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.46, 0),
      Offset(size.width * 0.64, size.height),
      subRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.24, size.height * 0.20),
      Offset(size.width * 0.85, size.height * 0.30),
      subRoadPaint,
    );

    // 500m 반경 가이드 링
    canvas.drawCircle(
      center,
      math.min(size.width, size.height) * 0.32,
      Paint()
        ..color = AppColors.clayOrange.withAlpha(38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant _Flat2DMapBackgroundPainter oldDelegate) =>
      oldDelegate.center != center;
}

class _DialogInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _DialogInputField({
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      variant: ClaySurfaceVariant.recessed,
      borderRadius: AppRadii.buttonInput,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textEspresso,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
