import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/data/models/restaurant_model.dart';

/// 후보지 트레이에 담을 수 있는 최대 맛집 개수
const int kMaxCandidateCount = 6;

enum CandidateToggleResult {
  added,
  removed,
  limitReached,
}

class CandidateTrayNotifier extends Notifier<List<RestaurantModel>> {
  @override
  List<RestaurantModel> build() => const [];

  bool contains(String restaurantId) {
    return state.any((r) => r.id == restaurantId);
  }

  CandidateToggleResult toggleCandidate(RestaurantModel restaurant) {
    if (contains(restaurant.id)) {
      state = state.where((r) => r.id != restaurant.id).toList();
      return CandidateToggleResult.removed;
    }

    if (state.length >= kMaxCandidateCount) {
      return CandidateToggleResult.limitReached;
    }

    state = [...state, restaurant];
    return CandidateToggleResult.added;
  }

  void removeCandidate(String restaurantId) {
    state = state.where((r) => r.id != restaurantId).toList();
  }

  void clearAll() {
    state = const [];
  }
}

final candidateTrayProvider =
    NotifierProvider<CandidateTrayNotifier, List<RestaurantModel>>(
  CandidateTrayNotifier.new,
);
