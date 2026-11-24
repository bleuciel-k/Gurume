import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/core/services/location_service.dart';
import 'package:oreguru/core/services/weather_service.dart';
import 'package:oreguru/data/models/party_and_preference_model.dart';
import 'package:oreguru/data/models/restaurant_model.dart';
import 'package:oreguru/data/repositories/restaurant_repository.dart';

/// 지도 상단 원탭(One-Tap) 상황별 필터 4종
enum OneTapFilter {
  openNow('🟢 지금 영업중'),
  soloFriendly('🎧 혼밥 가능'),
  noWaiting('⚡ 웨이팅 없음'),
  within500m('📍 내 주변 500m');

  final String label;
  const OneTapFilter(this.label);
}

/// 시간 의존 UI/필터 테스트를 결정론적으로 제어하기 위한 현재 시각 프로바이더
final currentDateTimeProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

class MapExplorerState {
  final Set<OneTapFilter> activeFilters;
  final String searchQuery;
  final String? selectedRestaurantId;
  final WeatherCondition currentWeather;
  final SeasonType currentSeason;
  final GeoPoint2D userLocation;
  final GeoPoint2D searchCenter;
  final GeoPoint2D? pendingViewportCenter;
  final bool hasLiveGps;
  final bool isLocating;

  const MapExplorerState({
    this.activeFilters = const {},
    this.searchQuery = '',
    this.selectedRestaurantId,
    this.currentWeather = WeatherCondition.rainy,
    this.currentSeason = SeasonType.autumn,
    this.userLocation = kDefaultYeonnamLocation,
    this.searchCenter = kDefaultYeonnamLocation,
    this.pendingViewportCenter,
    this.hasLiveGps = false,
    this.isLocating = false,
  });

  /// 현재 탐색 기준 중심점(`searchCenter`)과 매장 사이의 실시간 직선 거리(미터)
  int distanceMetersFromCenter(RestaurantModel restaurant) {
    return LocationService.roundedDistanceMeters(
      searchCenter,
      targetLat: restaurant.latitude,
      targetLng: restaurant.longitude,
    );
  }

  /// 현재 사용자 위치와 매장 사이의 실시간 직선 거리(미터)
  int distanceMetersFromUser(RestaurantModel restaurant) {
    return LocationService.roundedDistanceMeters(
      userLocation,
      targetLat: restaurant.latitude,
      targetLng: restaurant.longitude,
    );
  }

  /// 사용자가 지도를 150m 이상 이동했을 때 "이 지역에서 재검색" 버튼 표시 여부
  bool get shouldShowViewportResearch {
    final pending = pendingViewportCenter;
    if (pending == null) return false;
    return pending.distanceMetersTo(searchCenter) > 150;
  }

  MapExplorerState copyWith({
    Set<OneTapFilter>? activeFilters,
    String? searchQuery,
    String? selectedRestaurantId,
    bool clearSelectedRestaurant = false,
    WeatherCondition? currentWeather,
    SeasonType? currentSeason,
    GeoPoint2D? userLocation,
    GeoPoint2D? searchCenter,
    GeoPoint2D? pendingViewportCenter,
    bool clearPendingViewportCenter = false,
    bool? hasLiveGps,
    bool? isLocating,
  }) {
    return MapExplorerState(
      activeFilters: activeFilters ?? this.activeFilters,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRestaurantId: clearSelectedRestaurant
          ? null
          : (selectedRestaurantId ?? this.selectedRestaurantId),
      currentWeather: currentWeather ?? this.currentWeather,
      currentSeason: currentSeason ?? this.currentSeason,
      userLocation: userLocation ?? this.userLocation,
      searchCenter: searchCenter ?? this.searchCenter,
      pendingViewportCenter: clearPendingViewportCenter
          ? null
          : (pendingViewportCenter ?? this.pendingViewportCenter),
      hasLiveGps: hasLiveGps ?? this.hasLiveGps,
      isLocating: isLocating ?? this.isLocating,
    );
  }
}

class MapExplorerNotifier extends Notifier<MapExplorerState> {
  bool _hasRequestedInitialSync = false;
  bool _hasManualSearchCenter = false;
  bool _isDisposed = false;

  @override
  MapExplorerState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
    });

    final weatherService = ref.read(weatherServiceProvider);
    final season = weatherService.resolveCurrentSeason();

    if (!_hasRequestedInitialSync) {
      _hasRequestedInitialSync = true;
      Future.microtask(fetchLiveLocationAndWeather);
    }

    return MapExplorerState(
      currentWeather: switch (season) {
        SeasonType.winter => WeatherCondition.chilly,
        SeasonType.summer => WeatherCondition.hot,
        SeasonType.spring || SeasonType.autumn => WeatherCondition.sunny,
      },
      currentSeason: season,
    );
  }

  /// 앱 시작 시 실제 GPS 좌표를 조회하고 해당 좌표의 실시간 날씨/계절을 조용히 동기화
  Future<void> fetchLiveLocationAndWeather() async {
    final locationService = ref.read(locationServiceProvider);
    state = state.copyWith(isLocating: true);

    final locResult = await locationService.getCurrentLocation();
    if (_isDisposed) return;

    state = state.copyWith(
      userLocation: locResult.location,
      searchCenter: _hasManualSearchCenter ? null : locResult.location,
      clearPendingViewportCenter: !_hasManualSearchCenter,
      hasLiveGps: locResult.isLiveGps,
      isLocating: false,
    );

    await refreshWeatherInBackground(location: locResult.location);
  }

  /// UI 노출 없이 백그라운드에서 실시간 날씨/계절 상태를 조용히 갱신
  Future<void> refreshWeatherInBackground({GeoPoint2D? location}) async {
    final weatherService = ref.read(weatherServiceProvider);
    final target = location ?? state.searchCenter;
    final liveWeather = await weatherService.fetchCurrentWeather(
      latitude: target.latitude,
      longitude: target.longitude,
    );
    if (_isDisposed) return;

    final liveSeason = weatherService.resolveCurrentSeason();
    state = state.copyWith(
      currentWeather: liveWeather,
      currentSeason: liveSeason,
    );
  }

  /// 지도 카메라 이동 시 새 중심 좌표 기록
  void setPendingViewportCenter(GeoPoint2D? center) {
    if (center == null) {
      state = state.copyWith(clearPendingViewportCenter: true);
      return;
    }
    state = state.copyWith(pendingViewportCenter: center);
  }

  /// "이 지역에서 재검색" 버튼 탭 시 현재 뷰포트 중심을 탐색 반경 기준으로 적용
  void applyViewportSearch() {
    final nextCenter = state.pendingViewportCenter;
    if (nextCenter == null) return;
    _hasManualSearchCenter = true;
    state = state.copyWith(
      searchCenter: nextCenter,
      clearPendingViewportCenter: true,
    );
    Future.microtask(() => refreshWeatherInBackground(location: nextCenter));
  }

  /// 내 위치(🎯) 버튼 탭 시 GPS를 다시 조회하고 탐색 기준 중심을 내 위치로 복귀
  Future<LocationFetchResult> recenterToUserLocation() async {
    final locationService = ref.read(locationServiceProvider);
    state = state.copyWith(isLocating: true);

    final result = await locationService.getCurrentLocation();
    if (_isDisposed) return result;

    _hasManualSearchCenter = false;
    state = state.copyWith(
      userLocation: result.location,
      searchCenter: result.location,
      clearPendingViewportCenter: true,
      hasLiveGps: result.isLiveGps,
      isLocating: false,
    );

    unawaited(refreshWeatherInBackground(location: result.location));
    return result;
  }

  void toggleFilter(OneTapFilter filter) {
    final next = Set<OneTapFilter>.from(state.activeFilters);
    if (next.contains(filter)) {
      next.remove(filter);
    } else {
      next.add(filter);
    }
    state = state.copyWith(activeFilters: next);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void selectRestaurant(String? restaurantId) {
    state = state.copyWith(
      selectedRestaurantId: restaurantId,
      clearSelectedRestaurant: restaurantId == null,
    );
  }

  void setWeather(WeatherCondition weather) {
    state = state.copyWith(currentWeather: weather);
  }

  void setSeason(SeasonType season) {
    state = state.copyWith(currentSeason: season);
  }
}

final mapExplorerProvider =
    NotifierProvider<MapExplorerNotifier, MapExplorerState>(
  MapExplorerNotifier.new,
);

/// 활성화된 원탭 필터, 검색어, 실시간 영업시간 및 탐색 중심 거리를 즉시 적용한 맛집 목록
final filteredRestaurantsProvider = Provider<List<RestaurantModel>>((ref) {
  final restaurantsAsync = ref.watch(restaurantsProvider);
  final activeFilters = ref.watch(
    mapExplorerProvider.select((s) => s.activeFilters),
  );
  final query = ref.watch(
    mapExplorerProvider.select((s) => s.searchQuery.trim().toLowerCase()),
  );
  final searchCenter = ref.watch(
    mapExplorerProvider.select((s) => s.searchCenter),
  );
  final now = ref.watch(currentDateTimeProvider)();

  return restaurantsAsync.maybeWhen(
    data: (restaurants) {
      return restaurants.where((r) {
        if (r.isDeleted) return false;
        if (activeFilters.contains(OneTapFilter.openNow) &&
            !r.isCurrentlyOpen(now)) {
          return false;
        }
        if (activeFilters.contains(OneTapFilter.soloFriendly) &&
            !r.isSoloFriendly) {
          return false;
        }
        if (activeFilters.contains(OneTapFilter.noWaiting) &&
            !r.hasNoWaiting) {
          return false;
        }
        if (activeFilters.contains(OneTapFilter.within500m)) {
          final meters = LocationService.calculateDistanceMeters(
            startLat: searchCenter.latitude,
            startLng: searchCenter.longitude,
            endLat: r.latitude,
            endLng: r.longitude,
          );
          if (meters > 500) {
            return false;
          }
        }
        if (query.isNotEmpty) {
          final haystack =
              '${r.name} ${r.category} ${r.signatureDish} ${r.oneLineReview} ${r.priceRangeText}'
                  .toLowerCase();
          if (!haystack.contains(query)) return false;
        }
        return true;
      }).toList();
    },
    orElse: () => const [],
  );
});

/// 현재 바텀 시트에 표시할 선택된 맛집
final selectedRestaurantProvider = Provider<RestaurantModel?>((ref) {
  final selectedId = ref.watch(
    mapExplorerProvider.select((s) => s.selectedRestaurantId),
  );
  if (selectedId == null) return null;

  final restaurants = ref.watch(restaurantsProvider).valueOrNull ?? const [];
  for (final r in restaurants) {
    if (r.id == selectedId && !r.isDeleted) return r;
  }
  return null;
});
