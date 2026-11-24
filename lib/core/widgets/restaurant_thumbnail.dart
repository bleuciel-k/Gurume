import 'package:flutter/material.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/widgets/clay_container.dart';
import 'package:oreguru/data/models/restaurant_model.dart';

/// 맛집 썸네일 이미지(`thumbnailUrl`)가 있으면 네트워크 이미지를 표시하고,
/// 없거나 로드 실패 시 클레이 일러스트 이모지 카드로 부드럽게 폴백합니다.
class RestaurantThumbnail extends StatelessWidget {
  final RestaurantModel restaurant;
  final double size;
  final double emojiSize;

  const RestaurantThumbnail({
    super.key,
    required this.restaurant,
    this.size = 84,
    this.emojiSize = 38,
  });

  @override
  Widget build(BuildContext context) {
    final url = restaurant.thumbnailUrl?.trim();

    return ClayContainer(
      variant: ClaySurfaceVariant.recessed,
      borderRadius: AppRadii.cardChip,
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.cardChip),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildClayFallback();
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildClayFallback();
                },
              )
            : _buildClayFallback(),
      ),
    );
  }

  Widget _buildClayFallback() {
    return Container(
      width: size,
      height: size,
      color: restaurant.heroColor,
      alignment: Alignment.center,
      child: Image.asset(
        restaurant.clayMarkerType.assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Text(
          restaurant.clayMarkerType.emoji,
          style: TextStyle(fontSize: emojiSize),
        ),
      ),
    );
  }
}
