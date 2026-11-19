import 'package:flutter/material.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/constants/app_shadows.dart';

/// Figma Claymorphism UI (`node-id=0-1`) 기반 표면 스타일 변형
enum ClaySurfaceVariant {
  /// 모달/바텀시트/대형 패널 (`node 2:140`: 146.92deg 그라데이션 + 0 30 60 drop + 2중 inset + 화이트 림 보더)
  card,

  /// 라이트 클레이 버튼/칩/2열 카드 (`node 2:5` + `4:361`: -17.05deg 그라데이션 + 0 20 40 drop + 2중 inset)
  raised,

  /// #FC7D4E 오렌지 액센트 버튼/선택 카드 (`node 2:1151`, `2:149`, `4:363`: -20.78deg + 3중 inset)
  accent,

  /// 움푹 들어간 검색창/인풋/슬롯 (`node 2:144`: 18px + 1px #DECBB0 스트로크 + recessed inset)
  recessed,

  /// 민트 포인트 (장바구니 담김 등)
  mint,
}

/// Figma에서 추출한 다중 Drop Shadow + 다중 Inset Shadow + Specular Rim Border를
/// iOS/Android/Web에서 동일하게 렌더링하는 코어 클레이 컨테이너.
class ClayContainer extends StatelessWidget {
  final Widget child;
  final ClaySurfaceVariant variant;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool isPressed;
  final Border? border;
  final Duration animationDuration;

  const ClayContainer({
    super.key,
    required this.child,
    this.variant = ClaySurfaceVariant.raised,
    this.borderRadius = AppRadii.cardChip,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.isPressed = false,
    this.border,
    this.animationDuration = const Duration(milliseconds: 140),
  });

  @override
  Widget build(BuildContext context) {
    final config = _resolveStyleConfig(variant, isPressed: isPressed);

    return AnimatedContainer(
      duration: animationDuration,
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: config.gradient,
        border: border ?? config.defaultBorder,
        boxShadow: config.dropShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CustomPaint(
          foregroundPainter: ClayInnerShadowPainter(
            borderRadius: borderRadius,
            insetShadows: config.insetShadows,
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }

  _ClayStyleConfig _resolveStyleConfig(
    ClaySurfaceVariant variant, {
    required bool isPressed,
  }) {
    switch (variant) {
      case ClaySurfaceVariant.card:
        return _ClayStyleConfig(
          gradient: AppGradients.cardModalSurface,
          defaultBorder: Border.all(
            color: AppColors.rimBorderWhite,
            width: 1.0,
          ),
          dropShadows: AppShadows.cardDrop(isPressed: isPressed),
          insetShadows:
              isPressed ? AppShadows.pressedInsets : AppShadows.cardInsets,
        );

      case ClaySurfaceVariant.accent:
        return _ClayStyleConfig(
          gradient: AppGradients.orangeAccentButton,
          defaultBorder: null,
          dropShadows: AppShadows.accentDrop(isPressed: isPressed),
          insetShadows:
              isPressed ? AppShadows.pressedInsets : AppShadows.accentInsets,
        );

      case ClaySurfaceVariant.recessed:
        return _ClayStyleConfig(
          gradient: AppGradients.recessedInput,
          defaultBorder: Border.all(
            color: AppColors.inputStroke,
            width: 1.0,
          ),
          dropShadows: AppShadows.recessedDrop(),
          insetShadows: AppShadows.recessedInsets,
        );

      case ClaySurfaceVariant.mint:
        return _ClayStyleConfig(
          gradient: AppGradients.mintAccentButton,
          defaultBorder: null,
          dropShadows: AppShadows.mintDrop(isPressed: isPressed),
          insetShadows:
              isPressed ? AppShadows.pressedInsets : AppShadows.accentInsets,
        );

      case ClaySurfaceVariant.raised:
        return _ClayStyleConfig(
          gradient: AppGradients.lightClayButton,
          defaultBorder: Border.all(
            color: AppColors.rimBorderWhite,
            width: 1.0,
          ),
          dropShadows: AppShadows.raisedDrop(isPressed: isPressed),
          insetShadows:
              isPressed ? AppShadows.pressedInsets : AppShadows.raisedInsets,
        );
    }
  }
}

class _ClayStyleConfig {
  final Gradient gradient;
  final Border? defaultBorder;
  final List<BoxShadow> dropShadows;
  final List<ClayInsetShadow> insetShadows;

  const _ClayStyleConfig({
    required this.gradient,
    required this.defaultBorder,
    required this.dropShadows,
    required this.insetShadows,
  });
}
