import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/widgets/clay_container.dart';
import 'package:oreguru/features/map_explorer/providers/map_filter_provider.dart';

/// 지도 상단 가로 스크롤 형태의 원탭(One-Tap) 상황별 칩 필터 4개
class OneTapFilterBar extends ConsumerWidget {
  const OneTapFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilters = ref.watch(
      mapExplorerProvider.select((s) => s.activeFilters),
    );

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: OneTapFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = OneTapFilter.values[index];
          final isActive = activeFilters.contains(filter);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(mapExplorerProvider.notifier).toggleFilter(filter);
            },
            child: AnimatedScale(
              scale: isActive ? 1.03 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutBack,
              child: ClayContainer(
                variant: isActive
                    ? ClaySurfaceVariant.accent
                    : ClaySurfaceVariant.raised,
                borderRadius: AppRadii.cardChip,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: isActive
                    ? Border.all(
                        color: AppColors.rimBorderWhite,
                        width: 1.2,
                      )
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filter.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isActive
                            ? Colors.white
                            : AppColors.textEspresso,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
