import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/widgets/clay_button.dart';
import 'package:oreguru/core/widgets/clay_container.dart';
import 'package:oreguru/data/models/restaurant_model.dart';
import 'package:oreguru/features/candidate_tray/providers/candidate_provider.dart';
import 'package:oreguru/features/map_explorer/providers/map_filter_provider.dart';

/// 장바구니 방식의 우측 1열 세로(Vertical Single-Column) 후보지 트레이.
/// - 담긴 가게가 0개일 때는 아예 숨겨져 지도 시야를 100% 확보합니다.
/// - 가게 클릭 후 장바구니에 담으면 오른쪽 가장자리에 1열 세로로 슬림하게 나열됩니다.
class FloatingCandidateTray extends ConsumerWidget {
  final VoidCallback onCallGuruNyan;

  const FloatingCandidateTray({
    super.key,
    required this.onCallGuruNyan,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(candidateTrayProvider);

    // 장바구니가 비어있으면 화면에 노출하지 않음
    if (candidates.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClayContainer(
      variant: ClaySurfaceVariant.card,
      borderRadius: AppRadii.sheetPanel,
      width: 78,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단 장바구니 카운터
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.clayOrangeSoftBg,
              borderRadius: BorderRadius.circular(AppRadii.badge),
            ),
            child: Text(
              '🛒 ${candidates.length}/$kMaxCandidateCount',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.clayOrangeDark,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 1열 세로 나열 리스트 (최대 높이 제한으로 시야 방해 최소화)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 210),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: candidates.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _VerticalCartItem(
                      restaurant: item,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(mapExplorerProvider.notifier)
                            .selectRestaurant(item.id);
                      },
                      onRemove: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(candidateTrayProvider.notifier)
                            .removeCandidate(item.id);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 2),

          // 구루냥 호출 콤팩트 오렌지 버튼
          ClayButton(
            variant: ClaySurfaceVariant.accent,
            borderRadius: AppRadii.buttonInput,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            onPressed: onCallGuruNyan,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('😼', style: TextStyle(fontSize: 17)),
                SizedBox(height: 1),
                Text(
                  '골라줘!',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalCartItem extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _VerticalCartItem({
    required this.restaurant,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Tooltip(
            message: restaurant.name,
            child: ClayContainer(
              variant: ClaySurfaceVariant.raised,
              borderRadius: AppRadii.buttonInput,
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              border: Border.all(
                color: AppColors.clayOrange.withAlpha(150),
                width: 1.4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 30,
                    decoration: BoxDecoration(
                      color: restaurant.heroColor,
                      borderRadius: BorderRadius.circular(AppRadii.badge),
                    ),
                    child: Center(
                      child: Text(
                        restaurant.clayMarkerType.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textEspresso,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.textEspresso,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
