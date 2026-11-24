import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/services/location_service.dart';
import 'package:oreguru/core/widgets/clay_button.dart';
import 'package:oreguru/core/widgets/clay_container.dart';
import 'package:oreguru/core/widgets/clay_rect_choice_card.dart';
import 'package:oreguru/core/widgets/navigation_sheet.dart';
import 'package:oreguru/core/widgets/restaurant_thumbnail.dart';
import 'package:oreguru/data/models/party_and_preference_model.dart';
import 'package:oreguru/data/models/restaurant_model.dart';
import 'package:oreguru/features/candidate_tray/providers/candidate_provider.dart';
import 'package:oreguru/features/cat_decision/presentation/widgets/clay_share_poster_dialog.dart';
import 'package:oreguru/features/cat_decision/presentation/widgets/tuxedo_cat_stage.dart';
import 'package:oreguru/features/cat_decision/providers/cat_decision_provider.dart';
import 'package:oreguru/features/map_explorer/providers/map_filter_provider.dart';

/// 구루냥(턱시도 고양이) 결정 모달:
/// 1) 구루냥 페르소나 3종 + 2열 대형 클레이 인원/성별 카드 + '비토(Veto) 룰렛' 모드
/// 2) 2열 대형 직사각형 취향 유도 질문 (Q1 분위기 -> Q2 맛 -> 저녁 2인+ 동적 반주 Q3)
///    OR 유도 없이 구루냥에게 온전히 맡기기 (날씨·계절·상황 입맛 다시기)
/// 3) 앞발 '고양이 펀치' 탈락 카드 밀쳐내기 연출
/// 4) 최종 1곳 결과 카드 + 멀티 길찾기 + 클레이 포스터 공유 + 거절 제외 기능
class CatDecisionModal extends ConsumerWidget {
  const CatDecisionModal({super.key});

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    ref.read(catDecisionProvider.notifier).startNewSession();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CatDecisionModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catState = ref.watch(catDecisionProvider);
    final candidates = ref.watch(candidateTrayProvider);

    final remainingCandidates = candidates
        .where((r) => !catState.rejectedCandidateIds.contains(r.id))
        .toList();

    final showBack = catState.step == CatModalStep.askVibe ||
        catState.step == CatModalStep.askTaste ||
        catState.step == CatModalStep.askDrink ||
        catState.step == CatModalStep.vetoRoulette;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.65,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgIvory,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadii.heroContainer),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // 모달 상단 핸들 + 뒤로/닫기 바
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                  child: Row(
                    children: [
                      if (showBack)
                        GestureDetector(
                          onTap: () => ref
                              .read(catDecisionProvider.notifier)
                              .goBackStep(),
                          child: ClayContainer(
                            variant: ClaySurfaceVariant.raised,
                            borderRadius: AppRadii.buttonInput,
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: AppColors.textEspresso,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 34),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.shadowWarmBeige,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: ClayContainer(
                          variant: ClaySurfaceVariant.raised,
                          borderRadius: AppRadii.buttonInput,
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textEspresso,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 메인 스크롤 콘텐츠
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                    children: [
                      // 턱시도 고양이 구루냥 스테이지 & 말풍선 (페르소나 소품 & 요일·시간대 태그 포함)
                      TuxedoCatStage(
                        pose: catState.catPose,
                        dialogue: catState.catDialogue,
                        persona: catState.persona,
                        situationTag: catState.situationTag,
                        badgeText: catState.step == CatModalStep.pickedResult
                            ? catState.decisionBadgeText
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // 단계별 본문 전환
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: switch (catState.step) {
                          CatModalStep.selectParty => _buildPartyStep(
                              ref,
                              catState,
                              remainingCandidates.length,
                            ),
                          CatModalStep.askVibe => _buildVibeStep(
                              ref,
                              catState,
                              remainingCandidates.length,
                            ),
                          CatModalStep.askTaste =>
                            _buildTasteStep(ref, catState),
                          CatModalStep.askDrink =>
                            _buildDrinkStep(ref, catState),
                          CatModalStep.thinkingPoking => _buildPokingStage(
                              remainingCandidates,
                              catState,
                            ),
                          CatModalStep.vetoRoulette => _buildVetoRouletteStage(
                              ref,
                              remainingCandidates,
                              catState,
                            ),
                          CatModalStep.pickedResult => _buildPickedResult(
                              context,
                              ref,
                              catState,
                              remainingCandidates.length,
                            ),
                          CatModalStep.allRejected =>
                            _buildAllRejected(context),
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClayCardVisual(String assetPath, String fallbackEmoji) {
    return SizedBox.expand(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              fallbackEmoji,
              style: const TextStyle(fontSize: 34),
            ),
          ),
        ),
      ),
    );
  }

  /// 1단계: 페르소나 선택 + 비토 룰렛 + 2열 대형 직사각형 인원/성별 구성 선택 그리드
  Widget _buildPartyStep(
    WidgetRef ref,
    CatDecisionState state,
    int remainingCount,
  ) {
    return Column(
      key: const ValueKey('step_party'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 구루냥 성격(페르소나) 스위치 바
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: CatPersona.values.map((persona) {
              final isSelected = state.persona == persona;
              return Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: GestureDetector(
                  key: Key('persona_${persona.name}'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(catDecisionProvider.notifier).setPersona(persona);
                  },
                  child: ClayContainer(
                    variant: isSelected
                        ? ClaySurfaceVariant.accent
                        : ClaySurfaceVariant.raised,
                    borderRadius: AppRadii.buttonInput,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    child: Text(
                      '${persona.emoji} ${persona.label}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color:
                            isSelected ? Colors.white : AppColors.textEspresso,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${state.persona.emoji} ${state.persona.description}',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textTaupe,
          ),
        ),

        if (remainingCount >= 2) ...[
          const SizedBox(height: 10),
          _VetoRouletteBanner(
            remainingCount: remainingCount,
            onTap: () => ref.read(catDecisionProvider.notifier).startVetoMode(),
          ),
        ],

        const SizedBox(height: 14),
        const _StepHeader(
          stepBadge: 'STEP 1',
          title: '누구랑 함께 가나요?',
          subtitle: '모임 구성에 딱 맞는 가게를 가려낼 수 있게 알려주세요!',
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.08,
          children: PartyType.values.map((party) {
            return ClayRectChoiceCard(
              title: party.title,
              subtitle: party.subtitle,
              badgeTint: party.cardTint,
              isSelected: state.selectedParty == party,
              visual: _buildClayCardVisual(party.assetPath, party.emoji),
              onTap: () =>
                  ref.read(catDecisionProvider.notifier).selectParty(party),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 2단계-A: 2열 대형 직사각형 분위기 질문 + '구루냥에게 온전히 맡기기' 옵션
  Widget _buildVibeStep(
    WidgetRef ref,
    CatDecisionState state,
    int remainingCount,
  ) {
    return Column(
      key: const ValueKey('step_vibe'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EntrustToCatBanner(
          onTap: () =>
              ref.read(catDecisionProvider.notifier).entrustToCatByWeather(),
        ),
        if (remainingCount >= 2) ...[
          const SizedBox(height: 10),
          _VetoRouletteBanner(
            remainingCount: remainingCount,
            onTap: () => ref.read(catDecisionProvider.notifier).startVetoMode(),
          ),
        ],
        const SizedBox(height: 16),
        const _StepHeader(
          stepBadge: 'STEP 2 · 취향 힌트 1/2',
          title: '오늘 끌리는 분위기는?',
          subtitle: '구루냥이 힌트를 듣고 딱 맞는 가게를 골라줄게요',
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.12,
          children: VibePreference.values.map((vibe) {
            return ClayRectChoiceCard(
              title: vibe.title,
              subtitle: vibe.subtitle,
              badgeTint: vibe.cardTint,
              isSelected: state.selectedVibe == vibe,
              visual: _buildClayCardVisual(vibe.assetPath, vibe.emoji),
              onTap: () =>
                  ref.read(catDecisionProvider.notifier).selectVibe(vibe),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 2단계-B: 2열 대형 직사각형 맛 포인트 질문 + '구루냥에게 온전히 맡기기' 옵션
  Widget _buildTasteStep(
    WidgetRef ref,
    CatDecisionState state,
  ) {
    return Column(
      key: const ValueKey('step_taste'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EntrustToCatBanner(
          onTap: () =>
              ref.read(catDecisionProvider.notifier).entrustToCatByWeather(),
        ),
        const SizedBox(height: 18),
        const _StepHeader(
          stepBadge: 'STEP 2 · 취향 힌트 2/2',
          title: '지금 입에서 땡기는 맛은?',
          subtitle: '선택 즉시 구루냥이 골라드려요 (저녁 모임이면 한잔 여부 확인)',
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.12,
          children: TastePreference.values.map((taste) {
            return ClayRectChoiceCard(
              title: taste.title,
              subtitle: taste.subtitle,
              badgeTint: taste.cardTint,
              isSelected: state.selectedTaste == taste,
              visual: _buildClayCardVisual(taste.assetPath, taste.emoji),
              onTap: () => ref
                  .read(catDecisionProvider.notifier)
                  .selectTasteAndDecide(taste),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 2단계-C: 저녁 시간대 + 2인 이상 모임일 때 동적 등장하는 반주 질문
  Widget _buildDrinkStep(
    WidgetRef ref,
    CatDecisionState state,
  ) {
    return Column(
      key: const ValueKey('step_drink'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EntrustToCatBanner(
          onTap: () =>
              ref.read(catDecisionProvider.notifier).entrustToCatByWeather(),
        ),
        const SizedBox(height: 18),
        const _StepHeader(
          stepBadge: 'STEP 3 · 저녁 모임 보너스',
          title: '오늘 가볍게 한잔 곁들일 건가냥?',
          subtitle: '술 한잔 분위기와 깔끔한 식사 위주 중 골라주세요',
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.15,
          children: DrinkPreference.values.map((drink) {
            return ClayRectChoiceCard(
              key: Key('drink_${drink.name}'),
              title: drink.title,
              subtitle: drink.subtitle,
              badgeTint: drink.cardTint,
              isSelected: state.selectedDrink == drink,
              visual: Text(
                drink.emoji,
                style: const TextStyle(fontSize: 38),
              ),
              onTap: () => ref
                  .read(catDecisionProvider.notifier)
                  .selectDrinkAndDecide(drink),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 돌아가며 1곳씩 빼는 '비토(Veto) 룰렛' 스테이지
  Widget _buildVetoRouletteStage(
    WidgetRef ref,
    List<RestaurantModel> remaining,
    CatDecisionState state,
  ) {
    return Column(
      key: const ValueKey('step_veto_roulette'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          stepBadge: '🚫 비토(Veto) 룰렛 · ${remaining.length}곳 생존',
          title: '돌아가며 안 땡기는 곳을 빼주세요!',
          subtitle: '마지막 1곳이 남거나 아래 결정 버튼을 누르면 구루냥이 바로 픽해요',
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.96,
          children: remaining.map((item) {
            return GestureDetector(
              key: Key('veto_card_${item.id}'),
              onTap: () {
                HapticFeedback.mediumImpact();
                ref.read(catDecisionProvider.notifier).vetoCandidate(item.id);
              },
              child: ClayContainer(
                variant: ClaySurfaceVariant.card,
                borderRadius: AppRadii.cardChip,
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RestaurantThumbnail(
                      restaurant: item,
                      size: 62,
                      emojiSize: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textEspresso,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.signatureDish,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTaupe,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.clayBerry.withAlpha(30),
                        borderRadius: BorderRadius.circular(AppRadii.badge),
                      ),
                      child: const Text(
                        '✕ 여기 빼기',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.clayBerry,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (state.vetoHistory.isNotEmpty) ...[
          ClayButton(
            key: const Key('veto_undo_button'),
            variant: ClaySurfaceVariant.raised,
            borderRadius: AppRadii.buttonInput,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(catDecisionProvider.notifier).undoLastVeto();
            },
            child: const Center(
              child: Text(
                '↩️ 방금 뺀 가게 되살리기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textEspresso,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        ClayButton(
          key: const Key('veto_finish_button'),
          variant: ClaySurfaceVariant.accent,
          borderRadius: AppRadii.buttonInput,
          padding: const EdgeInsets.symmetric(vertical: 14),
          onPressed: () {
            HapticFeedback.mediumImpact();
            ref.read(catDecisionProvider.notifier).finishVetoAndPick();
          },
          child: Center(
            child: Text(
              '😼 남은 ${remaining.length}곳 중 구루냥이 바로 결정!',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 3단계: 구루냥 '고양이 펀치'로 탈락 후보 카드를 툭, 툭 날려버리는 연출
  Widget _buildPokingStage(
    List<RestaurantModel> remaining,
    CatDecisionState catState,
  ) {
    return Column(
      key: const ValueKey('step_poking'),
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: List.generate(remaining.length, (i) {
            final item = remaining[i];
            final isEliminated =
                catState.eliminatedDuringPunchIds.contains(item.id);
            final isJustPunched = catState.currentlyPunchedId == item.id;
            final isPoked = i == catState.activePokeIndex && !isEliminated;

            return AnimatedSlide(
              offset: isEliminated
                  ? Offset(i.isEven ? -1.35 : 1.35, 0.25)
                  : Offset.zero,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInCubic,
              child: AnimatedOpacity(
                opacity: isEliminated ? 0.18 : 1.0,
                duration: const Duration(milliseconds: 220),
                child: AnimatedScale(
                  scale: isJustPunched ? 0.90 : (isPoked ? 1.12 : 0.98),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: AnimatedRotation(
                    turns: isEliminated
                        ? (i.isEven ? -0.14 : 0.14)
                        : (isPoked ? 0.02 : -0.01),
                    duration: const Duration(milliseconds: 180),
                    child: ClayContainer(
                      variant: isPoked
                          ? ClaySurfaceVariant.accent
                          : ClaySurfaceVariant.card,
                      borderRadius: AppRadii.cardChip,
                      width: 148,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          RestaurantThumbnail(
                            restaurant: item,
                            size: 52,
                            emojiSize: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isPoked
                                  ? Colors.white
                                  : AppColors.textEspresso,
                            ),
                          ),
                          if (isEliminated || isJustPunched) ...[
                            const SizedBox(height: 4),
                            const Text(
                              '🐾 퍽! 탈락',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppColors.clayBerry,
                              ),
                            ),
                          ] else if (isPoked) ...[
                            const SizedBox(height: 4),
                            const Text(
                              '🐾 툭!',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// 4단계: 구루냥이 낚아챈 최종 1곳 추천 결과 카드 + 멀티 길찾기 + 포스터 공유 + 거절 제외
  Widget _buildPickedResult(
    BuildContext context,
    WidgetRef ref,
    CatDecisionState state,
    int remainingCount,
  ) {
    final picked = state.pickedRestaurant;
    if (picked == null) return const SizedBox.shrink();

    final mapState = ref.watch(mapExplorerProvider);
    final now = ref.watch(currentDateTimeProvider)();
    final liveMeters = mapState.distanceMetersFromCenter(picked);
    final distanceLabel = LocationService.formatDistance(liveMeters);
    final openStatus = picked.evaluateOpenStatus(now);
    final (statusLabel, statusColor) = switch (openStatus) {
      OpenStatus.open => ('영업중', AppColors.clayMintDark),
      OpenStatus.breakTime => ('브레이크타임', AppColors.clayButterDark),
      OpenStatus.closed => ('영업종료', AppColors.textMuted),
    };
    final hasMoreOptions = remainingCount > 1;

    return Column(
      key: ValueKey('step_picked_${picked.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClayContainer(
          variant: ClaySurfaceVariant.card,
          borderRadius: AppRadii.sheetPanel,
          padding: const EdgeInsets.all(20),
          border: Border.all(
            color: AppColors.clayOrange.withAlpha(180),
            width: 2.0,
          ),
          child: Column(
            children: [
              // 대표 음식 이미지/아이콘 + PICK 왕관 배지
              Stack(
                clipBehavior: Clip.none,
                children: [
                  RestaurantThumbnail(
                    restaurant: picked,
                    size: 96,
                    emojiSize: 48,
                  ),
                  Positioned(
                    top: -10,
                    right: -10,
                    child: ClayContainer(
                      variant: ClaySurfaceVariant.accent,
                      borderRadius: AppRadii.badge,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: const Text(
                        'PICK! 🐾',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                picked.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textEspresso,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(32),
                      borderRadius: BorderRadius.circular(AppRadii.badge),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (picked.priceRangeText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgWarmSand,
                        borderRadius: BorderRadius.circular(AppRadii.badge),
                      ),
                      child: Text(
                        '💰 ${picked.priceRangeText}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTaupe,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${picked.category} · ⭐ ${picked.rating} · $distanceLabel',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTaupe,
                ),
              ),
              const SizedBox(height: 12),

              // 대표 메뉴 & 한줄평
              ClayContainer(
                variant: ClaySurfaceVariant.recessed,
                borderRadius: AppRadii.buttonInput,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Text(
                      '🍽️ 추천 메뉴: ${picked.signatureDish}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.clayOrangeDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      picked.oneLineReview,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textEspresso,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 메인 CTA: 여기로 출발! (멀티 지도 선택 시트)
        ClayButton(
          variant: ClaySurfaceVariant.accent,
          borderRadius: AppRadii.buttonInput,
          padding: const EdgeInsets.symmetric(vertical: 16),
          onPressed: () {
            final onLaunch = ref.read(navigationLaunchHandlerProvider);
            showClayNavigationSheet(
              context,
              picked,
              onLaunch: onLaunch,
            );
          },
          child: const Text(
            '📍 여기로 출발! (길찾기 앱 선택)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 클레이 포스터 공유하기 버튼
        ClayButton(
          key: const Key('share_poster_button'),
          variant: ClaySurfaceVariant.raised,
          borderRadius: AppRadii.buttonInput,
          padding: const EdgeInsets.symmetric(vertical: 13),
          onPressed: () {
            HapticFeedback.selectionClick();
            showClaySharePosterDialog(
              context,
              restaurant: picked,
              persona: state.persona,
              catDialogue: state.catDialogue,
              distanceLabel: distanceLabel,
              openStatusLabel: statusLabel,
            );
          },
          child: const Center(
            child: Text(
              '📸 클레이 포스터 공유하기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.clayOrangeDark,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 거절 시 재추천 목록에서 영구 제외하는 버튼
        ClayButton(
          variant: ClaySurfaceVariant.raised,
          borderRadius: AppRadii.buttonInput,
          padding: const EdgeInsets.symmetric(vertical: 14),
          onPressed: () {
            HapticFeedback.mediumImpact();
            ref.read(catDecisionProvider.notifier).rejectCurrentAndRepick();
          },
          child: Text(
            hasMoreOptions
                ? '😿 여긴 안 땡겨! 이 가게 빼고 다시 골라줘 (${remainingCount - 1}곳 남음)'
                : '😿 여긴 안 땡겨! (이 가게도 제외하기)',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textTaupe,
            ),
          ),
        ),
      ],
    );
  }

  /// 모든 후보지가 거절되었을 때 화면
  Widget _buildAllRejected(BuildContext context) {
    return ClayContainer(
      key: const ValueKey('step_all_rejected'),
      variant: ClaySurfaceVariant.card,
      borderRadius: AppRadii.sheetPanel,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Text(
            '담은 후보지를 전부 뺐다냥! 🐾',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textEspresso,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '지도에서 새로운 맛집을 더 담아오면\n이 구루냥이 다시 기가 막히게 골라줄게!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textTaupe,
            ),
          ),
          const SizedBox(height: 16),
          ClayButton(
            variant: ClaySurfaceVariant.accent,
            borderRadius: AppRadii.buttonInput,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '🗺️ 지도로 돌아가서 다시 담기',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 질문 단계 상단에 크게 배치되는 '구루냥에게 온전히 맡기기' 직사각형 카드 버튼
class _EntrustToCatBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _EntrustToCatBanner({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClayButton(
      variant: ClaySurfaceVariant.accent,
      borderRadius: AppRadii.cardChip,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      onPressed: onTap,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(65),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                '😼🎲',
                style: TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '질문 패스! 구루냥에게 온전히 맡기기 😼',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '고민 없이 구루냥의 직감에 100% 맡겨보세요!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(235),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _VetoRouletteBanner extends StatelessWidget {
  final int remainingCount;
  final VoidCallback onTap;

  const _VetoRouletteBanner({
    required this.remainingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClayButton(
      key: const Key('start_veto_mode_button'),
      variant: ClaySurfaceVariant.raised,
      borderRadius: AppRadii.buttonInput,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      onPressed: onTap,
      child: Row(
        children: [
          const Text('🚫', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '돌아가며 빼기 (비토 룰렛)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textEspresso,
                  ),
                ),
                Text(
                  '모임원과 후보 $remainingCount곳 중 싫은 곳부터 1개씩 지워보세요',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTaupe,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.clayOrangeDark,
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String stepBadge;
  final String title;
  final String subtitle;

  const _StepHeader({
    required this.stepBadge,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.clayOrangeSoftBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            stepBadge,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.clayOrangeDark,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: AppColors.textEspresso,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textTaupe,
          ),
        ),
      ],
    );
  }
}
