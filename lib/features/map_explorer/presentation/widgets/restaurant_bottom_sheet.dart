import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/services/location_service.dart';
import 'package:oreguru/core/widgets/clay_button.dart';
import 'package:oreguru/core/widgets/clay_container.dart';
import 'package:oreguru/core/widgets/navigation_sheet.dart';
import 'package:oreguru/core/widgets/restaurant_thumbnail.dart';
import 'package:oreguru/data/models/restaurant_model.dart';
import 'package:oreguru/features/candidate_tray/providers/candidate_provider.dart';
import 'package:oreguru/features/map_explorer/providers/map_filter_provider.dart';

/// 마커 클릭 시 부드럽게 올라오는 가게 상세 바텀 시트
/// 사진/대표아이콘, 가격대, 실시간 영업상태, 거리, 멀티 길찾기 버튼, '후보지에 담기' 버튼 포함
class RestaurantBottomSheet extends ConsumerWidget {
  final RestaurantModel restaurant;
  final VoidCallback onClose;

  const RestaurantBottomSheet({
    super.key,
    required this.restaurant,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(candidateTrayProvider);
    final isCandidate = candidates.any((r) => r.id == restaurant.id);
    final mapState = ref.watch(mapExplorerProvider);
    final now = ref.watch(currentDateTimeProvider)();

    final openStatus = restaurant.evaluateOpenStatus(now);
    final liveMeters = mapState.distanceMetersFromCenter(restaurant);
    final distanceLabel = LocationService.formatDistance(liveMeters);

    final (statusLabel, statusColor) = switch (openStatus) {
      OpenStatus.open => ('영업중', AppColors.clayMintDark),
      OpenStatus.breakTime => ('브레이크타임', AppColors.clayButterDark),
      OpenStatus.closed => ('영업종료', AppColors.textMuted),
    };

    return ClayContainer(
      variant: ClaySurfaceVariant.card,
      borderRadius: AppRadii.sheetPanel,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 드래그 핸들 + 닫기 버튼
          Row(
            children: [
              const Spacer(),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.shadowWarmBeige,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.bgWarmSand,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textTaupe,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 가게 대표 썸네일(실사진 우선, 미제공 시 클레이 일러스트) + 기본 정보
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RestaurantThumbnail(
                restaurant: restaurant,
                size: 84,
                emojiSize: 38,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 실시간 영업상태 & 웨이팅 & 가격대 & 별점 배지
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusBadge(
                          text: statusLabel,
                          color: statusColor,
                        ),
                        if (restaurant.hasNoWaiting)
                          const _StatusBadge(
                            text: '웨이팅 없음',
                            color: AppColors.clayOrangeDark,
                          ),
                        if (restaurant.priceRangeText.isNotEmpty)
                          _StatusBadge(
                            text: '💰 ${restaurant.priceRangeText}',
                            color: AppColors.textTaupe,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textEspresso,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.clayButter,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          restaurant.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textEspresso,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${restaurant.category} · $distanceLabel · ${restaurant.openHoursText}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTaupe,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 한 줄 평 클레이 박스
          ClayContainer(
            variant: ClaySurfaceVariant.recessed,
            borderRadius: AppRadii.buttonInput,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"${restaurant.oneLineReview}"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textEspresso,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 하단 액션: 멀티 지도 길찾기 버튼 + 후보지에 담기 버튼
          Row(
            children: [
              Expanded(
                flex: 4,
                child: ClayButton(
                  variant: ClaySurfaceVariant.raised,
                  borderRadius: AppRadii.buttonInput,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onPressed: () {
                    final onLaunch = ref.read(navigationLaunchHandlerProvider);
                    showClayNavigationSheet(
                      context,
                      restaurant,
                      onLaunch: onLaunch,
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_walk_rounded,
                        size: 18,
                        color: AppColors.textEspresso,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '길찾기',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textEspresso,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: ClayButton(
                  variant: isCandidate
                      ? ClaySurfaceVariant.mint
                      : ClaySurfaceVariant.accent,
                  borderRadius: AppRadii.buttonInput,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onPressed: () {
                    final res = ref
                        .read(candidateTrayProvider.notifier)
                        .toggleCandidate(restaurant);
                    if (res == CandidateToggleResult.limitReached &&
                        context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.textEspresso,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          content: const Text(
                            '후보지는 최대 6개까지만 담을 수 있다냥! 🐾',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isCandidate ? '✓ 장바구니에 담김' : '🛒 후보 장바구니 담기',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(32),
        borderRadius: BorderRadius.circular(AppRadii.badge),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
