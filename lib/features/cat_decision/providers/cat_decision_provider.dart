import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/data/models/party_and_preference_model.dart';
import 'package:oreguru/data/models/restaurant_model.dart';
import 'package:oreguru/features/candidate_tray/providers/candidate_provider.dart';
import 'package:oreguru/features/map_explorer/providers/map_filter_provider.dart';

/// 구루냥 결정 모달의 단계
enum CatModalStep {
  /// 1단계: 인원 및 성별 구성 선택 (2열 대형 직사각형 클레이 카드)
  selectParty,

  /// 2단계-A: 구루냥 취향 유도 질문 1 (분위기/텐션) + '구루냥 맘대로(날씨·계절)' 옵션
  askVibe,

  /// 2단계-B: 구루냥 취향 유도 질문 2 (맛 포인트) + '구루냥 맘대로(날씨·계절)' 옵션
  askTaste,

  /// 3단계: 앞발로 후보 카드들을 툭툭 건드리며 고민하는 연출
  thinkingPoking,

  /// 4단계: 최종 1곳 낚아채기 + 입맛 다시기/능글 대사 + 결과 카드
  pickedResult,

  /// 모든 후보지를 사용자가 거절하여 남은 후보지가 0개인 상태
  allRejected,
}

/// 추천 방식 트랙
enum DecisionTrack {
  /// 구루냥의 질문(분위기 + 맛)으로 유도하여 추천
  guidedPreference,

  /// 유도 없이 구루냥에게 온전히 맡겨 날씨·계절(근거 부족 시 랜덤)로 추천
  catWeatherPick,
}

/// 구루냥 캐릭터 표정/액션 상태
enum CatMoodPose {
  idleSmirk, // 능글맞은 미소
  curiousAsk, // 고개 갸웃 질문하기
  pokingCards, // 앞발로 카드 툭툭 치기
  lickingLips, // 입맛 다시기 (혀 날름 + 눈 반짝 - 날씨/계절 일임 픽)
  triumphantPick, // 낚아채서 윙크!
  sulkySad, // 모든 후보를 거절당해 시무룩
}

class CatDecisionState {
  final CatModalStep step;
  final CatMoodPose catPose;
  final DecisionTrack track;
  final PartyType? selectedParty;
  final VibePreference? selectedVibe;
  final TastePreference? selectedTaste;
  final Set<String> rejectedCandidateIds;
  final RestaurantModel? pickedRestaurant;
  final String catDialogue;
  final String decisionBadgeText;
  final int activePokeIndex;

  const CatDecisionState({
    this.step = CatModalStep.selectParty,
    this.catPose = CatMoodPose.idleSmirk,
    this.track = DecisionTrack.guidedPreference,
    this.selectedParty,
    this.selectedVibe,
    this.selectedTaste,
    this.rejectedCandidateIds = const {},
    this.pickedRestaurant,
    this.catDialogue = '호오~ 오늘 누구랑 가는지부터 보여달라냥! 😼',
    this.decisionBadgeText = '',
    this.activePokeIndex = 0,
  });

  CatDecisionState copyWith({
    CatModalStep? step,
    CatMoodPose? catPose,
    DecisionTrack? track,
    PartyType? selectedParty,
    VibePreference? selectedVibe,
    TastePreference? selectedTaste,
    Set<String>? rejectedCandidateIds,
    RestaurantModel? pickedRestaurant,
    bool clearPicked = false,
    String? catDialogue,
    String? decisionBadgeText,
    int? activePokeIndex,
  }) {
    return CatDecisionState(
      step: step ?? this.step,
      catPose: catPose ?? this.catPose,
      track: track ?? this.track,
      selectedParty: selectedParty ?? this.selectedParty,
      selectedVibe: selectedVibe ?? this.selectedVibe,
      selectedTaste: selectedTaste ?? this.selectedTaste,
      rejectedCandidateIds: rejectedCandidateIds ?? this.rejectedCandidateIds,
      pickedRestaurant:
          clearPicked ? null : (pickedRestaurant ?? this.pickedRestaurant),
      catDialogue: catDialogue ?? this.catDialogue,
      decisionBadgeText: decisionBadgeText ?? this.decisionBadgeText,
      activePokeIndex: activePokeIndex ?? this.activePokeIndex,
    );
  }
}

class CatDecisionNotifier extends Notifier<CatDecisionState> {
  final Random _random = Random();
  Timer? _pokeTimer;

  @override
  CatDecisionState build() {
    ref.onDispose(() => _pokeTimer?.cancel());
    return const CatDecisionState();
  }

  /// 모달을 열 때마다 세션 초기화 (거절 목록 포함 리셋)
  void startNewSession() {
    _pokeTimer?.cancel();
    state = const CatDecisionState(
      step: CatModalStep.selectParty,
      catPose: CatMoodPose.idleSmirk,
      catDialogue: '후보지는 잘 담아왔군! 오늘 누구랑 가는 모임인지 골라보라냥~ 😼',
    );
  }

  /// 1단계: 인원/성별 카드 선택 -> 구루냥 질문 1단계로 이동
  void selectParty(PartyType party) {
    state = state.copyWith(
      selectedParty: party,
      step: CatModalStep.askVibe,
      catPose: CatMoodPose.curiousAsk,
      catDialogue:
          '[${party.badgeLabel}] 조합이로구나! 오늘 어떤 분위기가 땡기나? 귀찮으면 내 맘대로 골라줄 수도 있지~ 😼',
    );
  }

  /// 2단계-A: 분위기 선택 -> 맛 질문 단계로 이동
  void selectVibe(VibePreference vibe) {
    state = state.copyWith(
      selectedVibe: vibe,
      step: CatModalStep.askTaste,
      catPose: CatMoodPose.curiousAsk,
      catDialogue:
          '좋아, "${vibe.title}" 느낌이지? 자, 마지막 힌트! 지금 입안에서 어떤 맛이 땡기나냥? 😋',
    );
  }

  /// 2단계-B: 맛 선택 완료 -> 트랙 A (취향 유도 기반 추첨 시작)
  void selectTasteAndDecide(TastePreference taste) {
    state = state.copyWith(
      selectedTaste: taste,
      track: DecisionTrack.guidedPreference,
    );
    _runThinkingAndPick(DecisionTrack.guidedPreference);
  }

  /// 트랙 B: 유도 질문 없이 구루냥에게 온전히 맡기기 (날씨·계절 기반 + 근거 없으면 랜덤)
  void entrustToCatByWeather() {
    state = state.copyWith(
      track: DecisionTrack.catWeatherPick,
    );
    _runThinkingAndPick(DecisionTrack.catWeatherPick);
  }

  /// 결과 카드에서 [여긴 안 땡겨! 빼고 다시 골라줘] 탭 시
  /// 방금 고른 가게를 영구 거절 목록에 추가하여 절대 재추천하지 않음
  void rejectCurrentAndRepick() {
    final current = state.pickedRestaurant;
    if (current == null) return;

    final nextRejected = Set<String>.from(state.rejectedCandidateIds)
      ..add(current.id);

    final allCandidates = ref.read(candidateTrayProvider);
    final remaining = allCandidates
        .where((r) => !nextRejected.contains(r.id))
        .toList();

    if (remaining.isEmpty) {
      _pokeTimer?.cancel();
      state = state.copyWith(
        rejectedCandidateIds: nextRejected,
        clearPicked: true,
        step: CatModalStep.allRejected,
        catPose: CatMoodPose.sulkySad,
        catDialogue:
            '어라... 담은 후보지를 전부 빼버렸구나! 지도에서 새로운 가게를 더 담아오라냥~ 😿',
      );
      return;
    }

    state = state.copyWith(
      rejectedCandidateIds: nextRejected,
      clearPicked: true,
    );

    _runThinkingAndPick(state.track);
  }

  /// 이전 단계로 되돌아가기 (인원 재선택 등)
  void goBackStep() {
    _pokeTimer?.cancel();
    if (state.step == CatModalStep.askTaste) {
      state = state.copyWith(
        step: CatModalStep.askVibe,
        catPose: CatMoodPose.curiousAsk,
        catDialogue: '분위기를 다시 골라볼까? 아니면 내 맘대로 고르게 맡겨도 좋다냥! 😼',
      );
    } else if (state.step == CatModalStep.askVibe) {
      state = state.copyWith(
        step: CatModalStep.selectParty,
        catPose: CatMoodPose.idleSmirk,
        catDialogue: '모임 구성을 다시 골라보라냥! 🐾',
      );
    }
  }

  /// 앞발로 후보 카드들을 툭툭 건드리는 연출(1.6초) 후 최종 1곳 선정
  void _runThinkingAndPick(DecisionTrack track) {
    _pokeTimer?.cancel();
    final allCandidates = ref.read(candidateTrayProvider);
    final remaining = allCandidates
        .where((r) => !state.rejectedCandidateIds.contains(r.id))
        .toList();

    if (remaining.isEmpty) {
      state = state.copyWith(
        step: CatModalStep.allRejected,
        catPose: CatMoodPose.sulkySad,
        catDialogue: '남은 후보지가 없다냥! 지도에서 맛집을 더 담아와 줘! 😿',
      );
      return;
    }

    state = state.copyWith(
      step: CatModalStep.thinkingPoking,
      catPose: CatMoodPose.pokingCards,
      activePokeIndex: 0,
      catDialogue: track == DecisionTrack.catWeatherPick
          ? '흐음~ 오늘 날씨랑 계절 냄새를 킁킁 맡아보는 중이라냥... 🐾'
          : '네가 고른 취향을 조합해서 딱 맞는 집을 고르는 중이라냥... 🐾',
    );

    int tick = 0;
    _pokeTimer = Timer.periodic(const Duration(milliseconds: 260), (timer) {
      tick++;
      if (tick < 6) {
        state = state.copyWith(
          activePokeIndex: tick % remaining.length,
        );
      } else {
        timer.cancel();
        _finalizePick(remaining, track);
      }
    });
  }

  void _finalizePick(List<RestaurantModel> remaining, DecisionTrack track) {
    final explorer = ref.read(mapExplorerProvider);
    final weather = explorer.currentWeather;
    final season = explorer.currentSeason;

    late final RestaurantModel chosen;
    late final String dialogue;
    late final String badgeText;
    late final CatMoodPose pose;

    if (track == DecisionTrack.catWeatherPick) {
      // [트랙 B: 날씨·계절 기반 온전히 맡기기]
      final scores = <String, int>{};
      for (final r in remaining) {
        int score = 0;
        if (r.weatherTags.contains(weather)) score += 50;
        if (r.seasonTags.contains(season)) score += 25;
        scores[r.id] = score;
      }

      final uniqueScores = scores.values.toSet();
      final maxScore = scores.values.fold<int>(0, max);

      // 날씨나 계절로 딱히 나눌 근거가 없는 경우:
      // 1) 일치하는 날씨/계절 태그가 전혀 없음 (maxScore == 0)
      // 2) 남은 후보가 2곳 이상인데 모든 후보의 날씨/계절 점수가 완전히 동일함
      final hasClearEvidence =
          maxScore > 0 && (remaining.length == 1 || uniqueScores.length > 1);

      if (!hasClearEvidence) {
        // 근거가 없으면 남은 후보지 중에서 완전히 랜덤 선택!
        chosen = remaining[_random.nextInt(remaining.length)];
        badgeText = '🎲 구루냥 랜덤 직감 픽';
      } else {
        final topGroup =
            remaining.where((r) => scores[r.id] == maxScore).toList();
        chosen = topGroup[_random.nextInt(topGroup.length)];
        badgeText = '😼 구루냥 직감 추천 픽';
      }

      pose = CatMoodPose.lickingLips; // 혀 날름거리며 입맛 다시기!
      dialogue = chosen.buildWeatherCatComment(
        weather,
        season,
        hasClearWeatherEvidence: hasClearEvidence,
      );
    } else {
      // [트랙 A: 인원 + 분위기 + 맛 취향 유도 추천]
      final party = state.selectedParty;
      final vibe = state.selectedVibe;
      final taste = state.selectedTaste;

      int bestScore = -1;
      List<RestaurantModel> topCandidates = [];

      for (final r in remaining) {
        int score = 0;
        if (party != null) {
          if (r.suitableParties.contains(party)) score += 30;
          if (party.isSolo && r.isSoloFriendly) score += 20;
        }
        if (vibe != null && r.vibeTags.contains(vibe)) {
          score += 35;
        }
        if (taste != null && r.tasteTags.contains(taste)) {
          score += 35;
        }

        if (score > bestScore) {
          bestScore = score;
          topCandidates = [r];
        } else if (score == bestScore) {
          topCandidates.add(r);
        }
      }

      chosen = topCandidates[_random.nextInt(topCandidates.length)];
      pose = CatMoodPose.triumphantPick;
      badgeText = '😼 ${party?.badgeLabel ?? ''} 취향 맞춤 픽';
      dialogue = chosen.defaultTasteComment;
    }

    state = state.copyWith(
      step: CatModalStep.pickedResult,
      catPose: pose,
      pickedRestaurant: chosen,
      catDialogue: dialogue,
      decisionBadgeText: badgeText,
    );
  }
}

final catDecisionProvider =
    NotifierProvider<CatDecisionNotifier, CatDecisionState>(
  CatDecisionNotifier.new,
);
