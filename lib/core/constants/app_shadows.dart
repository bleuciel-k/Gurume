import 'package:flutter/material.dart';
import 'package:oreguru/core/constants/app_colors.dart';

/// 단일 내부 그림자(CSS `inset dx dy blur color`) 명세
@immutable
class ClayInsetShadow {
  final Offset offset;
  final double blurRadius;
  final Color color;

  const ClayInsetShadow({
    required this.offset,
    required this.blurRadius,
    required this.color,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ClayInsetShadow &&
            other.offset == offset &&
            other.blurRadius == blurRadius &&
            other.color == color;
  }

  @override
  int get hashCode => Object.hash(offset, blurRadius, color);
}

/// Figma Claymorphism UI (`node-id=0-1`)에서 추출한 다중 Drop Shadow & Inset Shadow 토큰
abstract final class AppShadows {
  /// 1. Modal / Bottom Sheet / Panel (`node 2:140` + `Drop Shadow 1`)
  /// - Drop: `0 30px 60px` + `0 1px 3px rgba(0,0,0,0.05)`
  static List<BoxShadow> cardDrop({bool isPressed = false}) {
    if (isPressed) {
      return [
        BoxShadow(
          color: AppColors.shadowModalWarm.withAlpha(64),
          offset: const Offset(0, 6),
          blurRadius: 14,
          spreadRadius: 0,
        ),
      ];
    }
    return [
      BoxShadow(
        color: AppColors.shadowModalWarm.withAlpha(115), // 45%
        offset: const Offset(0, 30),
        blurRadius: 60,
        spreadRadius: 0,
      ),
      const BoxShadow(
        color: Color(0x0D000000), // Drop Shadow 1: #0000000D
        offset: Offset(0, 1),
        blurRadius: 3,
        spreadRadius: 0,
      ),
    ];
  }

  /// - Inset (`node 2:140`): `inset -10 -10 20` + `inset 0 15 30`
  static const List<ClayInsetShadow> cardInsets = [
    ClayInsetShadow(
      offset: Offset(-10, -10),
      blurRadius: 20,
      color: Color(0x8CD4C3A8), // rgba(212,195,168,0.55)
    ),
    ClayInsetShadow(
      offset: Offset(0, 15),
      blurRadius: 30,
      color: Color(0xA6FFFFFF), // rgba(255,255,255,0.65)
    ),
  ];

  /// 2. Light Clay Button / Chip / Choice Card (`node 2:5` + `node 4:361`)
  /// - Drop: `0 20px 40px` + `0 1px 3px rgba(0,0,0,0.05)`
  static List<BoxShadow> raisedDrop({bool isPressed = false}) {
    if (isPressed) {
      return [
        BoxShadow(
          color: AppColors.shadowLightClay.withAlpha(72),
          offset: const Offset(0, 4),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ];
    }
    return [
      BoxShadow(
        color: AppColors.shadowLightClay.withAlpha(132), // 52%
        offset: const Offset(0, 20),
        blurRadius: 40,
        spreadRadius: 0,
      ),
      const BoxShadow(
        color: Color(0x0D000000),
        offset: Offset(0, 1),
        blurRadius: 3,
        spreadRadius: 0,
      ),
    ];
  }

  /// - Inset (`node 2:5` + `4:361`): `inset 3 3 10` + `inset -4 -4 8`
  static const List<ClayInsetShadow> raisedInsets = [
    ClayInsetShadow(
      offset: Offset(3, 3),
      blurRadius: 10,
      color: Color(0xC7FFFFFF), // rgba(255,255,255,0.78)
    ),
    ClayInsetShadow(
      offset: Offset(-4, -4),
      blurRadius: 8,
      color: Color(0xBFD6C6AD), // rgba(214,198,173,0.75)
    ),
  ];

  /// 3. #FC7D4E Primary Accent Button / Selected Card (`node 2:1151`, `2:149`, `4:363`)
  /// - Drop: `0 20px 40px` + `0 10px 20px`
  static List<BoxShadow> accentDrop({bool isPressed = false}) {
    if (isPressed) {
      return [
        BoxShadow(
          color: AppColors.clayOrange.withAlpha(72),
          offset: const Offset(0, 5),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ];
    }
    return [
      BoxShadow(
        color: AppColors.clayOrange.withAlpha(117), // 46%
        offset: const Offset(0, 20),
        blurRadius: 40,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: AppColors.clayOrangeDark.withAlpha(61), // 24%
        offset: const Offset(0, 10),
        blurRadius: 20,
        spreadRadius: 0,
      ),
    ];
  }

  /// - Inset (`node 2:1151` + `4:363`):
  ///   `inset 0 -3 10 rgba(0,0,0,0.37)` + `inset 3 1 15 rgba(255,255,255,0.52)` + `inset -8 -8 12 rgba(0,0,0,0.18)`
  static const List<ClayInsetShadow> accentInsets = [
    ClayInsetShadow(
      offset: Offset(0, -3),
      blurRadius: 10,
      color: Color(0x5E000000), // rgba(0,0,0,0.37)
    ),
    ClayInsetShadow(
      offset: Offset(3, 1),
      blurRadius: 15,
      color: Color(0x85FFFFFF), // rgba(255,255,255,0.52)
    ),
    ClayInsetShadow(
      offset: Offset(-8, -8),
      blurRadius: 12,
      color: Color(0x2E000000), // rgba(0,0,0,0.18)
    ),
  ];

  /// 4. Mint Accent Variant
  static List<BoxShadow> mintDrop({bool isPressed = false}) {
    if (isPressed) {
      return [
        BoxShadow(
          color: AppColors.clayMint.withAlpha(70),
          offset: const Offset(0, 5),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ];
    }
    return [
      BoxShadow(
        color: AppColors.clayMint.withAlpha(105),
        offset: const Offset(0, 18),
        blurRadius: 36,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: AppColors.clayMintDark.withAlpha(55),
        offset: const Offset(0, 8),
        blurRadius: 16,
        spreadRadius: 0,
      ),
    ];
  }

  /// 5. Recessed Input / Search Field (`node 2:144`)
  static List<BoxShadow> recessedDrop() {
    return const [
      BoxShadow(
        color: Color(0xB3FFFFFF),
        offset: Offset(0, 1),
        blurRadius: 2,
        spreadRadius: 0,
      ),
    ];
  }

  static const List<ClayInsetShadow> recessedInsets = [
    ClayInsetShadow(
      offset: Offset(2, 2),
      blurRadius: 6,
      color: Color(0x73C4B298), // rgba(196,178,152,0.45)
    ),
    ClayInsetShadow(
      offset: Offset(-3, -3),
      blurRadius: 8,
      color: Color(0xB8FFFFFF), // rgba(255,255,255,0.72)
    ),
  ];

  /// Pressed (눌림 상태) 전환용 Inset 그림자
  static const List<ClayInsetShadow> pressedInsets = [
    ClayInsetShadow(
      offset: Offset(3, 4),
      blurRadius: 10,
      color: Color(0x7A8C775C),
    ),
    ClayInsetShadow(
      offset: Offset(-2, -2),
      blurRadius: 6,
      color: Color(0x80FFFFFF),
    ),
  ];
}

/// Figma의 다중 `inset box-shadow` 리스트를 Canvas EvenOdd 클리핑으로
/// iOS/Android/Web에서 동일하게 렌더링하는 CustomPainter
class ClayInnerShadowPainter extends CustomPainter {
  final double borderRadius;
  final List<ClayInsetShadow> insetShadows;

  const ClayInnerShadowPainter({
    required this.borderRadius,
    required this.insetShadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (insetShadows.isEmpty || size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    canvas.save();
    canvas.clipRRect(rrect);

    for (final shadow in insetShadows) {
      // CSS blur-radius ≈ 2 * Gaussian sigma
      final sigma = (shadow.blurRadius * 0.5).clamp(0.5, 40.0);
      final shadowPaint = Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

      final outerRect = rrect.outerRect.inflate(shadow.blurRadius * 2.5);
      final shadowPath = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(outerRect)
        ..addRRect(rrect.shift(shadow.offset));

      canvas.drawPath(shadowPath, shadowPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ClayInnerShadowPainter oldDelegate) {
    if (oldDelegate.borderRadius != borderRadius) return true;
    if (oldDelegate.insetShadows.length != insetShadows.length) return true;
    for (int i = 0; i < insetShadows.length; i++) {
      if (oldDelegate.insetShadows[i] != insetShadows[i]) return true;
    }
    return false;
  }
}
