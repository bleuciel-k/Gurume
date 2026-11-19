import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/widgets/clay_container.dart';

/// 인원/성별 선택 및 구루냥의 취향 유도 질문 선택지에서 공통으로 사용하는
/// 2열 대형 직사각형 클레이 카드 위젯.
class ClayRectChoiceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget visual;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? badgeTint;

  const ClayRectChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.visual,
    required this.isSelected,
    required this.onTap,
    this.badgeTint,
  });

  @override
  State<ClayRectChoiceCard> createState() => _ClayRectChoiceCardState();
}

class _ClayRectChoiceCardState extends State<ClayRectChoiceCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final tint = widget.badgeTint ?? AppColors.clayOrangeSoftBg;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : (isSelected ? 1.02 : 1.0),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: ClayContainer(
          variant: isSelected
              ? ClaySurfaceVariant.accent
              : ClaySurfaceVariant.card,
          borderRadius: AppRadii.cardChip,
          isPressed: _isPressed,
          padding: const EdgeInsets.all(14),
          border: isSelected
              ? Border.all(color: Colors.white.withAlpha(210), width: 2)
              : Border.all(
                  color: AppColors.rimBorderWhite,
                  width: 1.2,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단: 클레이 일러스트/픽토그램 스테이지 (남은 높이 자동 채움)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withAlpha(55)
                        : tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: [
                      Center(child: widget.visual),
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: AppColors.clayOrange,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              // 하단: 굵직한 타이틀 + 서브 설명 (오버플로우 방지 자연 크기)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textEspresso,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: isSelected
                          ? Colors.white.withAlpha(230)
                          : AppColors.textTaupe,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
