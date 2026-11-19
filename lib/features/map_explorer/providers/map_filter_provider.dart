import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class MapExplorerState {
  final Set<OneTapFilter> activeFilters;
  final String searchQuery;
  final String? selectedRestaurantId;
  final WeatherCondition currentWeather;
  final SeasonType currentSeason;

  const MapExplorerState({
    this.activeFilters = const {},
    this.searchQuery = '',
    this.selectedRestaurantId,
    this.currentWeather = WeatherCondition.rainy,
    this.currentSeason = SeasonType.autumn,
  });

  MapExplorerState copyWith({
    Set<OneTapFilter>? activeFilters,
    String? searchQuery,
    String? selectedRestaurantId,
    bool clearSelectedRestaurant = false,
    WeatherCondition? currentWeather,
    SeasonType? currentSeason,
  }) {
    return MapExplorerState(
      activeFilters: activeFilters ?? this.activeFilters,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRestaurantId: clearSelectedRestaurant
          ? null
          : (selectedRestaurantId ?? this.selectedRestaurantId),
      currentWeather: currentWeather ?? this.currentWeather,
      currentSeason: currentSeason ?? this.currentSeason,
    );
  }
}

class MapExplorerNotifier extends Notifier<MapExplorerState> {
  bool _hasRequestedLiveWeather = false;

  @override
  MapExplorerState build() {
    final weatherService = ref.read(weatherServiceProvider);
    final season = weatherService.resolveCurrentSeason();

    if (!_hasRequestedLiveWeather) {
      _hasRequestedLiveWeather = true;
      Future.microtask(refreshWeatherInBackground);
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

  /// UI 노출 없이 백그라운드에서 실시간 날씨/계절 상태를 조용히 갱신
  Future<void> refreshWeatherInBackground() async {
    final weatherService = ref.read(weatherServiceProvider);
    final liveWeather = await weatherService.fetchCurrentWeather();
    final liveSeason = weatherService.resolveCurrentSeason();
    state = state.copyWith(
      currentWeather: liveWeather,
      currentSeason: liveSeason,
    );
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

/// 활성화된 원탭 필터 및 검색어를 즉시 적용한 지도 마커/검색 결과용 맛집 목록
final filteredRestaurantsProvider = Provider<List<RestaurantModel>>((ref) {
  final restaurantsAsync = ref.watch(restaurantsProvider);
  final activeFilters = ref.watch(
    mapExplorerProvider.select((s) => s.activeFilters),
  );
  final query = ref.watch(
    mapExplorerProvider.select((s) => s.searchQuery.trim().toLowerCase()),
  );

  return restaurantsAsync.maybeWhen(
    data: (restaurants) {
      return restaurants.where((r) {
        if (activeFilters.contains(OneTapFilter.openNow) && !r.isOpenNow) {
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
        if (activeFilters.contains(OneTapFilter.within500m) &&
            r.distanceMeters > 500) {
          return false;
        }
        if (query.isNotEmpty) {
          final haystack =
              '${r.name} ${r.category} ${r.signatureDish} ${r.oneLineReview}'
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
    if (r.id == selectedId) return r;
  }
  return null;
});
