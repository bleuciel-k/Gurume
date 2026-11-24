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
import 'package:oreguru/features/cat_decision/presentation/widgets/tuxedo_cat_stage.dart';
import 'package:oreguru/features/cat_decision/providers/cat_decision_provider.dart';
import 'package:oreguru/features/map_explorer/providers/map_filter_provider.dart';

/// 구루냥(턱시도 고양이) 결정 모달:
/// 1) 2열 대형 직사각형 인원/성별 카드 선택
/// 2) 2열 대형 직사각형 취향 유도 질문 (Q1 분위기 -> Q2 맛)
///    OR 유도 없이 구루냥에게 온전히 맡기기 (날씨·계절 입맛 다시기, 근거 없으면 랜덤)
/// 3) 앞발 툭툭 건드리기 연출
/// 4) 최종 1곳 결과 카드 + '여긴 안 땡겨! 빼고 다시 골라줘' 거절 제외 기능
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
                      if (catState.step == CatModalStep.askVibe ||
                          catState.step == CatModalStep.askTaste)
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
                      // 턱시도 고양이 구루냥 스테이지 & 말풍선
                      TuxedoCatStage(
                        pose: catState.catPose,
                        dialogue: catState.catDialogue,
                        badgeText: catState.step == CatModalStep.pickedResult
                            ? catState.decisionBadgeText
                            : null,
                      ),
                      const SizedBox(height: 18),

                      // 단계별 본문 전환
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: switch (catState.step) {
                          CatModalStep.selectParty =>
                            _buildPartyStep(ref, catState),
                          CatModalStep.askVibe =>
                            _buildVibeStep(ref, catState),
                          CatModalStep.askTaste =>
                            _buildTasteStep(ref, catState),
                          CatModalStep.thinkingPoking => _buildPokingStage(
                              remainingCandidates,
                              catState.activePokeIndex,
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

  /// 1단계: 2열 대형 직사각형 인원/성별 구성 선택 그리드
  Widget _buildPartyStep(WidgetRef ref, CatDecisionState state) {
    return Column(
      key: const ValueKey('step_party'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              visual: Text(
                party.emoji,
                style: const TextStyle(fontSize: 34),
              ),
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
  ) {
    return Column(
      key: const ValueKey('step_vibe'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EntrustToCatBanner(
          onTap: () =>
              ref.read(catDecisionProvider.notifier).entrustToCatByWeather(),
        ),
        const SizedBox(height: 18),
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
              visual: Text(
                vibe.emoji,
                style: const TextStyle(fontSize: 34),
              ),
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
          subtitle: '마지막 한 가지! 선택 즉시 구루냥이 골라드려요',
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
              visual: Text(
                taste.emoji,
                style: const TextStyle(fontSize: 34),
              ),
              onTap: () => ref
                  .read(catDecisionProvider.notifier)
                  .selectTasteAndDecide(taste),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 3단계: 구루냥이 후보 카드들을 앞발로 툭툭 건드리는 연출
  Widget _buildPokingStage(
    List<RestaurantModel> remaining,
    int activePokeIndex,
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
            final isPoked = i == activePokeIndex;
            return AnimatedScale(
              scale: isPoked ? 1.14 : 0.96,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: AnimatedRotation(
                turns: isPoked ? 0.02 : -0.01,
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
                      Text(
                        item.clayMarkerType.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 6),
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
                      if (isPoked) ...[
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
            );
          }),
        ),
      ],
    );
  }

  /// 4단계: 구루냥이 낚아챈 최종 1곳 추천 결과 카드 + 거절 제외 버튼
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
