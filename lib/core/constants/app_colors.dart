import 'package:flutter/material.dart';

/// オレグル(Oreguru) 클레이모피즘 디자인 시스템 컬러 토큰
/// (Figma Claymorphism UI `node-id=0-1` 수치 추출 기반 + #F1E6D2 아이보리 / #FC7D4E 오렌지 팔레트 매핑)
abstract final class AppColors {
  // Background & Surface Tokens (#F1E6D2 아이보리 테마)
  static const Color bgIvory = Color(0xFFF1E6D2);
  static const Color bgWarmSand = Color(0xFFE6D8BE);
  static const Color clayCream = Color(0xFFFAF3E6);
  static const Color clayCreamSoft = Color(0xFFFBF5EA);
  static const Color clayCreamLightStop = Color(0xFFEADBC3);
  static const Color clayCardBottomStop = Color(0xFFEFE2CA);

  // Primary Orange Accent (#FC7D4E 기반 3단 점토 그라데이션)
  static const Color clayOrange = Color(0xFFFC7D4E);
  static const Color clayOrangeLight = Color(0xFFFFA07A);
  static const Color clayOrangeDark = Color(0xFFD95222);
  static const Color clayOrangeSoftBg = Color(0xFFFFEFE8);

  // Text & Contrast
  static const Color textEspresso = Color(0xFF2D241E);
  static const Color textTaupe = Color(0xFF6E5D53);
  static const Color textMuted = Color(0xFFA8988E);

  // Semantic & Status Accents
  static const Color clayMint = Color(0xFF4ECDC4);
  static const Color clayMintDark = Color(0xFF33A39B);
  static const Color clayButter = Color(0xFFFFB830);
  static const Color clayButterDark = Color(0xFFD99516);
  static const Color clayBerry = Color(0xFFE85D75);
  static const Color claySky = Color(0xFF5FA8D3);

  // Figma Rim Borders & Input Strokes
  static const Color rimBorderWhite = Color(0xA6FFFFFF); // rgba(255,255,255,0.65)
  static const Color inputStroke = Color(0xFFDECBB0);

  // Figma Drop Shadow & Inset Shadow Base Colors
  static const Color shadowModalWarm = Color(0xFFB8A386); // node 2:140 대응
  static const Color shadowLightClay = Color(0xFFC6B295); // node 2:5 대응
  static const Color shadowWarmBeige = Color(0xFFC8B69B);
  static const Color shadowInnerBeige = Color(0xFFD6C6AD);
  static const Color shadowRecessed = Color(0xFFC4B298);

  // Tuxedo Cat (구루냥) Colors
  static const Color catFurBlack = Color(0xFF2B2624);
  static const Color catFurHighlight = Color(0xFF473E3B);
  static const Color catFurWhite = Color(0xFFFFFCF8);
  static const Color catEyeGold = Color(0xFFFFC947);
  static const Color catNosePink = Color(0xFFFF8A8A);
}

/// Figma `Claymorphism-UI` 기반 + 더 각진 클레이모피즘 모서리 곡률 디자인 토큰
abstract final class AppRadii {
  /// 내부 뱃지, 작은 태그, 캡슐 라벨
  static const double badge = 8.0;

  /// Input 필드 및 기본/보조 액션 버튼 (더 단단하고 각진 12px)
  static const double buttonInput = 12.0;

  /// 원탭 필터 칩, 2열 선택 카드, 말풍선, 마커 (14px)
  static const double cardChip = 14.0;

  /// 바텀 시트, 구루냥 결과 카드, 우측 장바구니 도크 (20px)
  static const double sheetPanel = 20.0;

  /// 구루냥 모달 시트 상단 컨테이너 (26px)
  static const double heroContainer = 26.0;
}

/// Figma `Claymorphism-UI` 배경 그라데이션 디자인 토큰
abstract final class AppGradients {
  /// `node 2:140` Modal/Card: 146.92deg, white -> translucent cream -> warm sand
  static const LinearGradient cardModalSurface = LinearGradient(
    begin: Alignment(-0.55, -0.84),
    end: Alignment(0.55, 0.84),
    stops: [0.01, 0.52, 1.0],
    colors: [
      Color(0xFFFFFFFF),
      AppColors.clayCreamSoft,
      AppColors.clayCardBottomStop,
    ],
  );

  /// `node 2:5` Light Clay Button/Chip: -17.05deg, warm cream bottom -> pure white top
  static const LinearGradient lightClayButton = LinearGradient(
    begin: Alignment(0.29, 0.96),
    end: Alignment(-0.29, -0.96),
    stops: [0.075, 1.0],
    colors: [
      AppColors.clayCreamLightStop,
      Color(0xFFFFFFFF),
    ],
  );

  /// `node 2:1151` / `2:149` Primary Accent Button: -20.78deg, deep orange -> #FC7D4E -> peach highlight
  static const LinearGradient orangeAccentButton = LinearGradient(
    begin: Alignment(0.35, 0.93),
    end: Alignment(-0.35, -0.93),
    stops: [0.0, 0.55, 1.0],
    colors: [
      AppColors.clayOrangeDark,
      AppColors.clayOrange,
      AppColors.clayOrangeLight,
    ],
  );

  /// Mint Accent Variant (장바구니 담김 상태)
  static const LinearGradient mintAccentButton = LinearGradient(
    begin: Alignment(0.35, 0.93),
    end: Alignment(-0.35, -0.93),
    colors: [
      AppColors.clayMintDark,
      AppColors.clayMint,
      Color(0xFF7BE7DF),
    ],
  );

  /// `node 2:144` / `2:147` Recessed Input & Slot
  static const LinearGradient recessedInput = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE9DCC5),
      AppColors.clayCreamSoft,
    ],
  );
}
