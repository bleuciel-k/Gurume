import 'package:flutter/material.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/widgets/clay_container.dart';
import 'package:oreguru/data/models/restaurant_model.dart';

/// 2D 커스텀 지도 위 등록된 맛집 위치에만 렌더링되는
/// 클레이모피즘 스타일 3D 건물/아이콘 커스텀 마커 위젯.
///
/// 실서비스에서는 RepaintBoundary -> BitmapDescriptor로 프리렌더링하여
/// Google Maps Marker 풀에 캐싱해 성능을 극대화합니다.
class Clay3DMarkerWidget extends StatelessWidget {
  final RestaurantModel restaurant;
  final bool isSelected;
  final bool isCandidate;
  final VoidCallback onTap;

  const Clay3DMarkerWidget({
    super.key,
    required this.restaurant,
    required this.isSelected,
    required this.isCandidate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final roofColor = restaurant.clayMarkerType.roofColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.18 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // 3D 점토 미니어처 가게 지붕 + 건물 블록
                ClayContainer(
                  variant: isSelected
                      ? ClaySurfaceVariant.accent
                      : ClaySurfaceVariant.raised,
                  borderRadius: AppRadii.cardChip,
                  padding: const EdgeInsets.all(4),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : (isCandidate
                            ? AppColors.clayOrange
                            : AppColors.rimBorderWhite),
                    width: isCandidate || isSelected ? 2.2 : 1.2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 점토 지붕(Awning/Roof)
                      Container(
                        width: 48,
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.lerp(roofColor, Colors.white, 0.25)!,
                              roofColor,
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                            bottom: Radius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // 음식점 3D 미니어처 건물 스프라이트 (로드 불가 시 이모지 폴백)
                      Container(
                        width: 44,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withAlpha(235)
                              : restaurant.heroColor,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.asset(
                            restaurant.clayMarkerType.assetPath,
                            width: 44,
                            height: 34,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                restaurant.clayMarkerType.emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 후보지에 담긴 가게면 우상단에 🐾 클레이 발바닥 배지 부착
                if (isCandidate)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: ClayContainer(
                      variant: ClaySurfaceVariant.accent,
                      borderRadius: AppRadii.badge,
                      padding: const EdgeInsets.all(4),
                      border: Border.all(color: Colors.white, width: 1.5),
                      child: const Text(
                        '🐾',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // 마커 하단 가게명 클레이 캡슐 라벨
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.clayOrange
                    : AppColors.clayCream.withAlpha(242),
                borderRadius: BorderRadius.circular(AppRadii.badge),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textEspresso.withAlpha(35),
                    offset: const Offset(0, 3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                restaurant.name,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.textEspresso,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
