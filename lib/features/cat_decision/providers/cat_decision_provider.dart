import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/core/services/cat_dialogue_engine.dart';
import 'package:oreguru/data/models/party_and_preference_model.dart';
import 'package:oreguru/data/models/restaurant_model.dart';
import 'package:oreguru/features/candidate_tray/providers/candidate_provider.dart';
import 'package:oreguru/features/map_explorer/providers/map_filter_provider.dart';

/// 구루냥 결정 모달의 단계
enum CatModalStep {
  /// 1단계: 인원 및 성별 구성 선택 (페르소나 전환 & 비토 룰렛 진입 포함)
  selectParty,

  /// 2단계-A: 구루냥 취향 유도 질문 1 (분위기/텐션) + '구루냥 맘대로(날씨·계절)' 옵션
  askVibe,

  /// 2단계-B: 구루냥 취향 유도 질문 2 (맛 포인트) + '구루냥 맘대로(날씨·계절)' 옵션
  askTaste,

  /// 2단계-C: 저녁 시간대 + 2인 이상 모임일 때 동적으로 추가되는 반주 의향 질문
  askDrink,

  /// 3단계: 앞발 '고양이 펀치'로 탈락 카드를 툭, 툭 쳐내며 최종 후보를 남기는 연출
  thinkingPoking,

  /// 4단계: 최종 1곳 낚아채기 + 결과 카드 + 포스터 공유 + 거절 제외 버튼
  pickedResult,

  /// 돌아가며 1곳씩 빼는 '비토(Veto) 룰렛' 모드
  vetoRoulette,

  /// 모든 후보지를 사용자가 거절하여 남은 후보지가 0개인 상태
  allRejected,
}

/// 추천 방식 트랙
enum DecisionTrack {
  /// 구루냥의 질문(분위기 + 맛 + 선택적 반주)으로 유도하여 추천
  guidedPreference,

  /// 유도 없이 구루냥에게 온전히 맡겨 날씨·계절(근거 부족 시 랜덤)로 추천
  catWeatherPick,
}

/// 구루냥 캐릭터 표정/액션 상태
enum CatMoodPose {
  idleSmirk, // 능글맞은 미소
  curiousAsk, // 고개 갸웃 질문하기
  pokingCards, // 앞발로 카드 툭툭 치기 (고양이 펀치)
  lickingLips, // 입맛 다시기 (혀 날름 + 눈 반짝 - 날씨/계절 일임 픽)
  triumphantPick, // 낚아채서 윙크!
  sulkySad, // 모든 후보를 거절당해 시무룩
}

class CatDecisionState {
  final CatModalStep step;
  final CatMoodPose catPose;
  final DecisionTrack track;
  final CatPersona persona;
  final PartyType? selectedParty;
  final VibePreference? selectedVibe;
  final TastePreference? selectedTaste;
  final DrinkPreference? selectedDrink;
  final Set<String> rejectedCandidateIds;
  final List<String> vetoHistory;
  final Set<String> eliminatedDuringPunchIds;
  final String? currentlyPunchedId;
  final RestaurantModel? pickedRestaurant;
  final String catDialogue;
  final String decisionBadgeText;
  final String situationTag;
  final int activePokeIndex;

  const CatDecisionState({
    this.step = CatModalStep.selectParty,
    this.catPose = CatMoodPose.idleSmirk,
    this.track = DecisionTrack.guidedPreference,
    this.persona = CatPersona.classic,
    this.selectedParty,
    this.selectedVibe,
    this.selectedTaste,
    this.selectedDrink,
    this.rejectedCandidateIds = const {},
    this.vetoHistory = const [],
    this.eliminatedDuringPunchIds = const {},
    this.currentlyPunchedId,
    this.pickedRestaurant,
    this.catDialogue = '호오~ 오늘 누구랑 가는지부터 보여달라냥! 😼',
    this.decisionBadgeText = '',
    this.situationTag = '',
    this.activePokeIndex = 0,
  });

  CatDecisionState copyWith({
    CatModalStep? step,
    CatMoodPose? catPose,
    DecisionTrack? track,
    CatPersona? persona,
    PartyType? selectedParty,
    VibePreference? selectedVibe,
    TastePreference? selectedTaste,
    DrinkPreference? selectedDrink,
    bool clearDrink = false,
    Set<String>? rejectedCandidateIds,
    List<String>? vetoHistory,
    Set<String>? eliminatedDuringPunchIds,
    String? currentlyPunchedId,
    bool clearCurrentlyPunched = false,
    RestaurantModel? pickedRestaurant,
    bool clearPicked = false,
    String? catDialogue,
    String? decisionBadgeText,
    String? situationTag,
    int? activePokeIndex,
  }) {
    return CatDecisionState(
      step: step ?? this.step,
      catPose: catPose ?? this.catPose,
      track: track ?? this.track,
      persona: persona ?? this.persona,
      selectedParty: selectedParty ?? this.selectedParty,
      selectedVibe: selectedVibe ?? this.selectedVibe,
      selectedTaste: selectedTaste ?? this.selectedTaste,
      selectedDrink:
          clearDrink ? null : (selectedDrink ?? this.selectedDrink),
      rejectedCandidateIds: rejectedCandidateIds ?? this.rejectedCandidateIds,
      vetoHistory: vetoHistory ?? this.vetoHistory,
      eliminatedDuringPunchIds:
          eliminatedDuringPunchIds ?? this.eliminatedDuringPunchIds,
      currentlyPunchedId: clearCurrentlyPunched
          ? null
          : (currentlyPunchedId ?? this.currentlyPunchedId),
      pickedRestaurant:
          clearPicked ? null : (pickedRestaurant ?? this.pickedRestaurant),
      catDialogue: catDialogue ?? this.catDialogue,
      decisionBadgeText: decisionBadgeText ?? this.decisionBadgeText,
      situationTag: situationTag ?? this.situationTag,
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

  /// 페르소나 및 요일/시간대별 후보 점수 산출 (유닛 테스트에서 직접 검증 가능)
  static int scoreRestaurantForPersona(
    RestaurantModel restaurant, {
    required CatPersona persona,
    PartyType? party,
    VibePreference? vibe,
    TastePreference? taste,
    DrinkPreference? drink,
  }) {
    int score = 0;
    if (party != null) {
      if (restaurant.suitableParties.contains(party)) score += 30;
      if (party.isSolo && restaurant.isSoloFriendly) score += 20;
    }
    if (vibe != null && restaurant.vibeTags.contains(vibe)) {
      score += 35;
    }
    if (taste != null && restaurant.tasteTags.contains(taste)) {
      score += 35;
    }

    if (drink == DrinkPreference.yesDrink) {
      if (restaurant.clayMarkerType == ClayMarkerType.izakayaRoof ||
          restaurant.clayMarkerType == ClayMarkerType.grillHouse ||
          restaurant.clayMarkerType == ClayMarkerType.spicyPot) {
        score += 30;
      }
    } else if (drink == DrinkPreference.noDrink) {
      if (restaurant.clayMarkerType == ClayMarkerType.ramenHouse ||
          restaurant.clayMarkerType == ClayMarkerType.riceBowlShop ||
          restaurant.clayMarkerType == ClayMarkerType.pokeSalad ||
          restaurant.clayMarkerType == ClayMarkerType.pastaTerrace) {
        score += 20;
      }
    }

    switch (persona) {
      case CatPersona.classic:
        break;
      case CatPersona.pickyButler:
        if (restaurant.hasNoWaiting) score += 25;
        if (restaurant.priceRangeText.trim().startsWith('1')) score += 20;
        if (restaurant.rating >= 4.8) score += 15;
      case CatPersona.adventurer:
        if (restaurant.vibeTags.contains(VibePreference.aesthetic) ||
            restaurant.tasteTags.contains(TastePreference.spicyKick)) {
          score += 25;
        }
        if (restaurant.clayMarkerType == ClayMarkerType.spicyPot ||
            restaurant.clayMarkerType == ClayMarkerType.izakayaRoof ||
            restaurant.clayMarkerType == ClayMarkerType.pastaTerrace) {
          score += 15;
        }
    }

    return score;
  }

  /// 모달을 열 때마다 세션 초기화 (페르소나 유지, 시간대별 상황 태그 & 오프닝 대사 갱신)
  void startNewSession() {
    _pokeTimer?.cancel();
    final now = ref.read(currentDateTimeProvider)();
    final activePersona = state.persona;
    state = CatDecisionState(
      step: CatModalStep.selectParty,
      catPose: CatMoodPose.idleSmirk,
      persona: activePersona,
      situationTag: CatDialogueEngine.resolveSituationTag(now),
      catDialogue: CatDialogueEngine.buildOpeningDialogue(
        persona: activePersona,
        now: now,
      ),
    );
  }

  /// 구루냥 페르소나 변경 (기본 / 깐깐한 집사냥 / 모험가냥)
  void setPersona(CatPersona persona) {
    final now = ref.read(currentDateTimeProvider)();
    state = state.copyWith(
      persona: persona,
      situationTag: CatDialogueEngine.resolveSituationTag(now),
      catDialogue: state.step == CatModalStep.selectParty
          ? CatDialogueEngine.buildOpeningDialogue(persona: persona, now: now)
          : state.catDialogue,
    );
  }

  /// 1단계: 인원/성별 카드 선택 -> 구루냥 질문 1단계로 이동
  void selectParty(PartyType party) {
    state = state.copyWith(
      selectedParty: party,
      clearDrink: true,
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

  /// 2단계-B: 맛 선택 완료 -> 저녁+2인 이상이면 한잔 질문 분기, 아니면 즉시 추첨
  void selectTasteAndDecide(TastePreference taste) {
    final now = ref.read(currentDateTimeProvider)();
    if (CatDialogueEngine.shouldAskDrinkQuestion(
      party: state.selectedParty,
      now: now,
    )) {
      state = state.copyWith(
        selectedTaste: taste,
        step: CatModalStep.askDrink,
        catPose: CatMoodPose.curiousAsk,
        catDialogue: '저녁에 여럿이 모였구나! 오늘 가볍게 한잔 곁들일 건가냥? 🍺',
      );
      return;
    }

    state = state.copyWith(
      selectedTaste: taste,
      clearDrink: true,
      track: DecisionTrack.guidedPreference,
    );
    _runThinkingAndPick(DecisionTrack.guidedPreference);
  }

  /// 2단계-C: 저녁 2인 이상 동적 반주 질문 응답 -> 추첨 시작
  void selectDrinkAndDecide(DrinkPreference drink) {
    state = state.copyWith(
      selectedDrink: drink,
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

  /// 돌아가며 1곳씩 빼는 '비토(Veto) 룰렛' 모드 시작
  void startVetoMode() {
    _pokeTimer?.cancel();
    state = state.copyWith(
      step: CatModalStep.vetoRoulette,
      catPose: CatMoodPose.idleSmirk,
      rejectedCandidateIds: const {},
      vetoHistory: const [],
      eliminatedDuringPunchIds: const {},
      clearCurrentlyPunched: true,
      clearPicked: true,
      catDialogue: '돌아가며 오늘 절대 안 땡기는 집을 1곳씩 빼보라냥! 끝까지 살아남은 곳으로 간다! 🚫',
    );
  }

  /// 비토 룰렛: 지정된 가게 제외 (1곳만 남으면 즉시 최종 추천 연출 돌입)
  void vetoCandidate(String restaurantId) {
    final allCandidates = ref.read(candidateTrayProvider);
    final nextRejected = Set<String>.from(state.rejectedCandidateIds)
      ..add(restaurantId);
    final nextHistory = [...state.vetoHistory, restaurantId];
    final remaining = allCandidates
        .where((r) => !nextRejected.contains(r.id))
        .toList();

    if (remaining.isEmpty) {
      state = state.copyWith(
        rejectedCandidateIds: nextRejected,
        vetoHistory: nextHistory,
        step: CatModalStep.allRejected,
        catPose: CatMoodPose.sulkySad,
        catDialogue: '전부 빼버렸구나! 지도에서 후보지를 다시 골라오라냥~ 😿',
      );
      return;
    }

    if (remaining.length == 1) {
      state = state.copyWith(
        rejectedCandidateIds: nextRejected,
        vetoHistory: nextHistory,
        track: DecisionTrack.guidedPreference,
      );
      _runThinkingAndPick(DecisionTrack.guidedPreference);
      return;
    }

    state = state.copyWith(
      rejectedCandidateIds: nextRejected,
      vetoHistory: nextHistory,
      catDialogue:
          '${nextHistory.length}번 주자 컷! 다음 사람 폰 넘겨라냥~ (${remaining.length}곳 생존) 🐾',
    );
  }

  /// 비토 룰렛 마지막 제외 1건 되돌리기
  void undoLastVeto() {
    if (state.vetoHistory.isEmpty) return;
    final nextHistory = List<String>.from(state.vetoHistory);
    final lastId = nextHistory.removeLast();
    final nextRejected = Set<String>.from(state.rejectedCandidateIds)
      ..remove(lastId);
    final allCandidates = ref.read(candidateTrayProvider);
    final remainingCount =
        allCandidates.where((r) => !nextRejected.contains(r.id)).length;

    state = state.copyWith(
      rejectedCandidateIds: nextRejected,
      vetoHistory: nextHistory,
      catDialogue: '휴~ 방금 뺀 가게를 되살렸다냥! (현재 $remainingCount곳 생존) 😼',
    );
  }

  /// 비토 룰렛 생존 후보 중 즉시 구루냥에게 최종 결정 맡기기
  void finishVetoAndPick() {
    state = state.copyWith(track: DecisionTrack.guidedPreference);
    _runThinkingAndPick(DecisionTrack.guidedPreference);
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
        eliminatedDuringPunchIds: const {},
        clearCurrentlyPunched: true,
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
      eliminatedDuringPunchIds: const {},
      clearCurrentlyPunched: true,
      clearPicked: true,
    );

    _runThinkingAndPick(state.track);
  }

  /// 이전 단계로 되돌아가기
  void goBackStep() {
    _pokeTimer?.cancel();
    if (state.step == CatModalStep.askDrink) {
      state = state.copyWith(
        step: CatModalStep.askTaste,
        catPose: CatMoodPose.curiousAsk,
        catDialogue: '방금 고른 맛 포인트를 다시 바꿔볼까냥? 😋',
      );
    } else if (state.step == CatModalStep.askTaste) {
      state = state.copyWith(
        step: CatModalStep.askVibe,
        catPose: CatMoodPose.curiousAsk,
        catDialogue: '분위기를 다시 골라볼까? 아니면 내 맘대로 고르게 맡겨도 좋다냥! 😼',
      );
    } else if (state.step == CatModalStep.askVibe ||
        state.step == CatModalStep.vetoRoulette) {
      final now = ref.read(currentDateTimeProvider)();
      state = state.copyWith(
        step: CatModalStep.selectParty,
        catPose: CatMoodPose.idleSmirk,
        rejectedCandidateIds: const {},
        vetoHistory: const [],
        catDialogue: CatDialogueEngine.buildOpeningDialogue(
          persona: state.persona,
          now: now,
        ),
      );
    }
  }

  /// 3단계: 앞발 '고양이 펀치'로 탈락 카드를 툭, 툭 날려버리는 연출(6틱 x 260ms) 후 최종 1곳 공개
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

    final outcome = _resolveOutcome(remaining, track);
    final losers = remaining
        .where((r) => r.id != outcome.chosen.id)
        .toList()
      ..shuffle(_random);

    state = state.copyWith(
      step: CatModalStep.thinkingPoking,
      catPose: CatMoodPose.pokingCards,
      activePokeIndex: 0,
      eliminatedDuringPunchIds: const {},
      clearCurrentlyPunched: true,
      catDialogue: track == DecisionTrack.catWeatherPick
          ? '흐음~ 날씨랑 상황 냄새를 맡으며 탈락 카드를 툭, 툭 쳐내는 중이라냥... 🐾'
          : '${state.persona.emoji} ${state.persona.label} 레이더 가동! 맘에 안 드는 카드를 펀치로 치우는 중~ 🐾',
    );

    int tick = 0;
    _pokeTimer = Timer.periodic(const Duration(milliseconds: 260), (timer) {
      tick++;
      if (tick < 6) {
        final nextEliminated = Set<String>.from(state.eliminatedDuringPunchIds);
        String? punchedNow;
        if (losers.isNotEmpty) {
          final targetCount =
              ((losers.length * tick) / 5).ceil().clamp(0, losers.length);
          for (int i = 0; i < targetCount; i++) {
            nextEliminated.add(losers[i].id);
          }
          if (targetCount > 0) {
            punchedNow = losers[targetCount - 1].id;
          }
        }
        state = state.copyWith(
          activePokeIndex: tick % remaining.length,
          eliminatedDuringPunchIds: nextEliminated,
          currentlyPunchedId: punchedNow,
          clearCurrentlyPunched: punchedNow == null,
        );
      } else {
        timer.cancel();
        state = state.copyWith(
          step: CatModalStep.pickedResult,
          catPose: outcome.pose,
          pickedRestaurant: outcome.chosen,
          catDialogue: outcome.dialogue,
          decisionBadgeText: outcome.badgeText,
          eliminatedDuringPunchIds: const {},
          clearCurrentlyPunched: true,
        );
      }
    });
  }

  ({
    RestaurantModel chosen,
    String dialogue,
    String badgeText,
    CatMoodPose pose,
  }) _resolveOutcome(List<RestaurantModel> remaining, DecisionTrack track) {
    final explorer = ref.read(mapExplorerProvider);
    final weather = explorer.currentWeather;
    final season = explorer.currentSeason;
    final now = ref.read(currentDateTimeProvider)();
    final persona = state.persona;

    if (track == DecisionTrack.catWeatherPick) {
      final scores = <String, int>{};
      for (final r in remaining) {
        int score = 0;
        if (r.weatherTags.contains(weather)) score += 50;
        if (r.seasonTags.contains(season)) score += 25;
        if (persona == CatPersona.pickyButler && r.hasNoWaiting) score += 10;
        if (persona == CatPersona.adventurer &&
            r.vibeTags.contains(VibePreference.aesthetic)) {
          score += 10;
        }
        scores[r.id] = score;
      }

      final uniqueScores = scores.values.toSet();
      final maxScore = scores.values.fold<int>(0, max);
      final hasClearEvidence =
          maxScore > 0 && (remaining.length == 1 || uniqueScores.length > 1);

      final RestaurantModel chosen;
      final String badgeText;
      if (!hasClearEvidence) {
        chosen = remaining[_random.nextInt(remaining.length)];
        badgeText = '🎲 ${persona.label} 랜덤 직감 픽';
      } else {
        final topGroup =
            remaining.where((r) => scores[r.id] == maxScore).toList();
        chosen = topGroup[_random.nextInt(topGroup.length)];
        badgeText = '${persona.emoji} ${persona.label} 직감 추천 픽';
      }

      return (
        chosen: chosen,
        pose: CatMoodPose.lickingLips,
        badgeText: badgeText,
        dialogue: CatDialogueEngine.buildPickedDialogue(
          picked: chosen,
          persona: persona,
          isWeatherPick: true,
          weather: weather,
          season: season,
          now: now,
          hasClearWeatherEvidence: hasClearEvidence,
          drinkPreference: state.selectedDrink,
        ),
      );
    }

    int bestScore = -1;
    List<RestaurantModel> topCandidates = [];

    for (final r in remaining) {
      final score = scoreRestaurantForPersona(
        r,
        persona: persona,
        party: state.selectedParty,
        vibe: state.selectedVibe,
        taste: state.selectedTaste,
        drink: state.selectedDrink,
      );

      if (score > bestScore) {
        bestScore = score;
        topCandidates = [r];
      } else if (score == bestScore) {
        topCandidates.add(r);
      }
    }

    final chosen = topCandidates[_random.nextInt(topCandidates.length)];
    final partyBadge = state.selectedParty?.badgeLabel ?? '';
    final prefix = partyBadge.isNotEmpty ? '$partyBadge · ' : '';

    return (
      chosen: chosen,
      pose: CatMoodPose.triumphantPick,
      badgeText: '${persona.emoji} $prefix${persona.label} 맞춤 픽',
      dialogue: CatDialogueEngine.buildPickedDialogue(
        picked: chosen,
        persona: persona,
        isWeatherPick: false,
        weather: weather,
        season: season,
        now: now,
        hasClearWeatherEvidence: false,
        drinkPreference: state.selectedDrink,
      ),
    );
  }
}

final catDecisionProvider =
    NotifierProvider<CatDecisionNotifier, CatDecisionState>(
  CatDecisionNotifier.new,
);
