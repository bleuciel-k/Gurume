import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/services/navigation_launcher.dart';
import 'package:oreguru/core/widgets/clay_button.dart';
import 'package:oreguru/core/widgets/clay_container.dart';
import 'package:oreguru/data/models/restaurant_model.dart';

typedef NavigationLaunchHandler = Future<bool> Function({
  required MapNavApp app,
  required double latitude,
  required double longitude,
  required String name,
});

/// 테스트 환경에서 실제 url_launcher 호출을 가로챌 수 있도록 분리한 프로바이더
final navigationLaunchHandlerProvider = Provider<NavigationLaunchHandler>((ref) {
  return NavigationLauncher.launchNavigation;
});

/// 네이버지도 · 카카오맵 · Google Maps · Apple Maps 선택 바텀시트
Future<void> showClayNavigationSheet(
  BuildContext context,
  RestaurantModel restaurant, {
  NavigationLaunchHandler? onLaunch,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClayContainer(
            variant: ClaySurfaceVariant.card,
            borderRadius: AppRadii.heroContainer,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withAlpha(110),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      '🧭 길찾기 앱 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textEspresso,
                      ),
                    ),
                    const Spacer(),
                    ClayContainer(
                      variant: ClaySurfaceVariant.recessed,
                      borderRadius: AppRadii.badge,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        '${restaurant.clayMarkerType.emoji} ${restaurant.name}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textEspresso,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '원하는 지도 앱을 고르면 도보 경로로 바로 연결해 드려요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTaupe,
                  ),
                ),
                const SizedBox(height: 14),
                for (final app in MapNavApp.values) ...[
                  _NavAppOptionTile(
                    key: Key('nav_app_${app.name}'),
                    app: app,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      final launcher =
                          onLaunch ?? NavigationLauncher.launchNavigation;
                      final ok = await launcher(
                        app: app,
                        latitude: restaurant.latitude,
                        longitude: restaurant.longitude,
                        name: restaurant.name,
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.textEspresso,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.buttonInput),
                            ),
                            content: Text(
                              '${app.label}을(를) 열 수 없어 웹 브라우저를 확인해 주세요.',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
                ClayButton(
                  variant: ClaySurfaceVariant.raised,
                  width: double.infinity,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Center(
                    child: Text(
                      '닫기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTaupe,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _NavAppOptionTile extends StatelessWidget {
  final MapNavApp app;
  final VoidCallback onTap;

  const _NavAppOptionTile({
    super.key,
    required this.app,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClayContainer(
        variant: ClaySurfaceVariant.raised,
        borderRadius: AppRadii.cardChip,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: app.accentColor.withAlpha(32),
                borderRadius: BorderRadius.circular(AppRadii.buttonInput),
                border: Border.all(
                  color: app.accentColor.withAlpha(90),
                  width: 1.2,
                ),
              ),
              child: Text(
                app.badgeEmoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textEspresso,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTaupe,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.clayOrangeSoftBg,
                borderRadius: BorderRadius.circular(AppRadii.badge),
              ),
              child: const Text(
                '길찾기 →',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.clayOrangeDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
