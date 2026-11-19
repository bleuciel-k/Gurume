import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/widgets/clay_button.dart';
import 'package:oreguru/core/widgets/clay_container.dart';
import 'package:oreguru/data/models/restaurant_model.dart';
import 'package:oreguru/features/candidate_tray/providers/candidate_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 마커 클릭 시 부드럽게 올라오는 가게 상세 바텀 시트
/// 사진/대표아이콘, 한 줄 평, 영업상태, 길찾기 버튼, '후보지에 담기' 버튼 포함
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

          // 가게 대표 썸네일(클레이 일러스트 카드) + 기본 정보
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClayContainer(
                variant: ClaySurfaceVariant.recessed,
                borderRadius: AppRadii.cardChip,
                width: 84,
                height: 84,
                child: Container(
                  decoration: BoxDecoration(
                    color: restaurant.heroColor,
                    borderRadius: BorderRadius.circular(AppRadii.cardChip),
                  ),
                  child: Center(
                    child: Text(
                      restaurant.clayMarkerType.emoji,
                      style: const TextStyle(fontSize: 38),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 영업상태 & 별점 배지
                    Row(
                      children: [
                        _StatusBadge(
                          text: restaurant.isOpenNow ? '영업중' : '준비중',
                          color: restaurant.isOpenNow
                              ? AppColors.clayMint
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        if (restaurant.hasNoWaiting)
                          const _StatusBadge(
                            text: '웨이팅 없음',
                            color: AppColors.clayOrange,
                          ),
                        const Spacer(),
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
                    const SizedBox(height: 6),
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textEspresso,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${restaurant.category} · ${restaurant.distanceMeters}m · ${restaurant.openHoursText}',
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

          // 하단 액션: 길찾기 버튼 + 후보지에 담기 버튼
          Row(
            children: [
              Expanded(
                flex: 4,
                child: ClayButton(
                  variant: ClaySurfaceVariant.raised,
                  borderRadius: AppRadii.buttonInput,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onPressed: () => _openDirections(context, restaurant),
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

  Future<void> _openDirections(
    BuildContext context,
    RestaurantModel restaurant,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${restaurant.latitude},${restaurant.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${restaurant.name} 길찾기 좌표를 열었습니다.'),
        ),
      );
    }
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
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(10),
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
