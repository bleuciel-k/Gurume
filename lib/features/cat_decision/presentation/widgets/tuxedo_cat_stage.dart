import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/widgets/clay_container.dart';
import 'package:oreguru/data/models/party_and_preference_model.dart';
import 'package:oreguru/features/cat_decision/providers/cat_decision_provider.dart';

/// 클래식 카툰(부치 캣 스타일)의 능글맞은 턱시도 고양이 '구루냥(グルニャン)' 스테이지.
///
/// 실서비스에서 Rive 상태 머신 에셋('assets/rive/gurunyan.riv')이 준비되면
/// _TuxedoCatCharacter 위젯 내부를 RiveAnimation으로 바로 교체할 수 있도록
/// CatMoodPose 상태와 분리 설계되었습니다.
class TuxedoCatStage extends StatefulWidget {
  final CatMoodPose pose;
  final String dialogue;
  final String? badgeText;
  final CatPersona persona;
  final String? situationTag;

  const TuxedoCatStage({
    super.key,
    required this.pose,
    required this.dialogue,
    this.badgeText,
    this.persona = CatPersona.classic,
    this.situationTag,
  });

  @override
  State<TuxedoCatStage> createState() => _TuxedoCatStageState();
}

class _TuxedoCatStageState extends State<TuxedoCatStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 턱시도 고양이 캐릭터 + 배경 장식
        SizedBox(
          height: 132,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final bobY = math.sin(t * math.pi) *
                  (widget.pose == CatMoodPose.pokingCards ? 6.0 : 3.5);
              final tilt = widget.pose == CatMoodPose.curiousAsk
                  ? -0.07 + (t * 0.04)
                  : (widget.pose == CatMoodPose.pokingCards
                      ? (t - 0.5) * 0.14
                      : 0.0);

              return Stack(
                alignment: Alignment.center,
                children: [
                  // 따뜻한 햇살 아우라
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.pose == CatMoodPose.lickingLips
                          ? AppColors.clayOrangeSoftBg
                          : AppColors.bgWarmSand,
                    ),
                  ),

                  // 입맛 다시기 / 픽 완료 시 반짝이는 별
                  if (widget.pose == CatMoodPose.lickingLips ||
                      widget.pose == CatMoodPose.triumphantPick) ...[
                    Positioned(
                      left: 52,
                      top: 12 + (t * 6),
                      child: const Text('✨', style: TextStyle(fontSize: 18)),
                    ),
                    Positioned(
                      right: 52,
                      top: 18 - (t * 6),
                      child: const Text('🐾', style: TextStyle(fontSize: 16)),
                    ),
                  ],

                  // 능글맞은 턱시도 고양이 본체
                  Transform.translate(
                    offset: Offset(0, -bobY),
                    child: Transform.rotate(
                      angle: tilt,
                      child: CustomPaint(
                        size: const Size(124, 118),
                        painter: _TuxedoCatPainter(
                          pose: widget.pose,
                          persona: widget.persona,
                          animProgress: t,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // 구루냥 말풍선 (Figma 모달 카드 스타일 + 시간/요일 상황 태그 + 추천 배지)
        ClayContainer(
          variant: ClaySurfaceVariant.card,
          borderRadius: AppRadii.cardChip,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: Border.all(
            color: widget.pose == CatMoodPose.lickingLips
                ? AppColors.clayOrange.withAlpha(160)
                : AppColors.rimBorderWhite,
            width: 1.2,
          ),
          child: Column(
            children: [
              if ((widget.badgeText != null && widget.badgeText!.isNotEmpty) ||
                  (widget.situationTag != null &&
                      widget.situationTag!.isNotEmpty)) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    if (widget.situationTag != null &&
                        widget.situationTag!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgWarmSand,
                          borderRadius: BorderRadius.circular(AppRadii.badge),
                        ),
                        child: Text(
                          widget.situationTag!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTaupe,
                          ),
                        ),
                      ),
                    if (widget.badgeText != null && widget.badgeText!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.clayOrangeSoftBg,
                          borderRadius: BorderRadius.circular(AppRadii.badge),
                        ),
                        child: Text(
                          widget.badgeText!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.clayOrangeDark,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                widget.dialogue,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: AppColors.textEspresso,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 부치 캣 스타일 턱시도 고양이 커스텀 페인터 (능글 미소 / 툭툭 건드리기 / 혀 날름 / 페르소나 액세서리)
class _TuxedoCatPainter extends CustomPainter {
  final CatMoodPose pose;
  final CatPersona persona;
  final double animProgress;

  const _TuxedoCatPainter({
    required this.pose,
    required this.persona,
    required this.animProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 4;

    final blackPaint = Paint()..color = AppColors.catFurBlack;
    final highlightPaint = Paint()..color = AppColors.catFurHighlight;
    final whitePaint = Paint()..color = AppColors.catFurWhite;
    final pinkPaint = Paint()..color = AppColors.catNosePink;
    final linePaint = Paint()
      ..color = AppColors.textEspresso
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    // 1. 꼬리 (살랑살랑)
    final tailSwing = math.sin(animProgress * math.pi * 2) * 8;
    final tailPath = Path()
      ..moveTo(cx + 26, cy + 32)
      ..quadraticBezierTo(
        cx + 56,
        cy + 20 + tailSwing,
        cx + 48,
        cy - 4 + tailSwing,
      );
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = AppColors.catFurBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );

    // 2. 턱시도 몸통 + 하얀 턱시도 가슴(Bib)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 28), width: 62, height: 48),
      blackPaint,
    );
    final bibPath = Path()
      ..moveTo(cx - 14, cy + 12)
      ..quadraticBezierTo(cx, cy + 44, cx + 14, cy + 12)
      ..close();
    canvas.drawPath(bibPath, whitePaint);

    // 3. 뾰족한 고양이 귀 (왼쪽 / 오른쪽)
    final leftEar = Path()
      ..moveTo(cx - 32, cy - 12)
      ..lineTo(cx - 38, cy - 42)
      ..lineTo(cx - 12, cy - 28)
      ..close();
    final rightEar = Path()
      ..moveTo(cx + 32, cy - 12)
      ..lineTo(cx + 38, cy - 42)
      ..lineTo(cx + 12, cy - 28)
      ..close();
    canvas.drawPath(leftEar, blackPaint);
    canvas.drawPath(rightEar, blackPaint);

    // 귀 안쪽 핑크
    final leftInnerEar = Path()
      ..moveTo(cx - 29, cy - 17)
      ..lineTo(cx - 33, cy - 35)
      ..lineTo(cx - 17, cy - 26)
      ..close();
    final rightInnerEar = Path()
      ..moveTo(cx + 29, cy - 17)
      ..lineTo(cx + 33, cy - 35)
      ..lineTo(cx + 17, cy - 26)
      ..close();
    canvas.drawPath(leftInnerEar, pinkPaint);
    canvas.drawPath(rightInnerEar, pinkPaint);

    // 4. 머리 본체 (둥글고 통통한 점토 느낌)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 8), width: 72, height: 58),
      blackPaint,
    );
    // 정수리 점토 하이라이트
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 10, cy - 24), width: 28, height: 12),
      highlightPaint,
    );

    // 5. 턱시도 고양이 특유의 하얀 입 주변 마스크 (Muzzle)
    final muzzlePath = Path()
      ..moveTo(cx, cy - 6)
      ..quadraticBezierTo(cx - 28, cy - 2, cx - 26, cy + 14)
      ..quadraticBezierTo(cx, cy + 24, cx + 26, cy + 14)
      ..quadraticBezierTo(cx + 28, cy - 2, cx, cy - 6)
      ..close();
    canvas.drawPath(muzzlePath, whitePaint);

    // 6. 눈 (상태별 표정 변화)
    final eyePaint = Paint()..color = AppColors.catEyeGold;
    final pupilPaint = Paint()..color = AppColors.textEspresso;

    if (pose == CatMoodPose.triumphantPick) {
      // 왼쪽 눈은 윙크, 오른쪽 눈은 반짝!
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx - 14, cy - 10), width: 14, height: 10),
        math.pi,
        math.pi,
        false,
        linePaint..color = Colors.white,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 14, cy - 11), width: 13, height: 15),
        eyePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 14, cy - 11), width: 6, height: 10),
        pupilPaint,
      );
    } else if (pose == CatMoodPose.sulkySad) {
      // 시무룩한 눈
      canvas.drawLine(
        Offset(cx - 20, cy - 12),
        Offset(cx - 8, cy - 8),
        linePaint..color = Colors.white,
      );
      canvas.drawLine(
        Offset(cx + 20, cy - 12),
        Offset(cx + 8, cy - 8),
        linePaint..color = Colors.white,
      );
    } else {
      // 능글맞은 반달 눈썹 + 금빛 눈동자
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 14, cy - 11), width: 13, height: 14),
        eyePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 14, cy - 11), width: 13, height: 14),
        eyePaint,
      );
      final gazeShift = pose == CatMoodPose.pokingCards
          ? (animProgress - 0.5) * 4
          : 1.5;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx - 14 + gazeShift, cy - 11),
          width: 5.5,
          height: 9.5,
        ),
        pupilPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + 14 + gazeShift, cy - 11),
          width: 5.5,
          height: 9.5,
        ),
        pupilPaint,
      );
      // 눈 하이라이트
      canvas.drawCircle(Offset(cx - 16, cy - 14), 2, whitePaint);
      canvas.drawCircle(Offset(cx + 12, cy - 14), 2, whitePaint);

      // 능글맞게 까딱이는 눈꺼풀
      final lidPaint = Paint()..color = AppColors.catFurBlack;
      canvas.drawRect(
        Rect.fromLTWH(cx - 22, cy - 20, 16, 6),
        lidPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(cx + 6, cy - 21, 16, 4),
        lidPaint,
      );
    }

    // 7. 핑크 삼각 코 & 입
    final nosePath = Path()
      ..moveTo(cx - 4.5, cy - 1)
      ..lineTo(cx + 4.5, cy - 1)
      ..lineTo(cx, cy + 4)
      ..close();
    canvas.drawPath(nosePath, pinkPaint);

    // ω 모양 능글맞은 고양이 입
    linePaint.color = AppColors.textEspresso;
    final mouthPath = Path()
      ..moveTo(cx - 10, cy + 7)
      ..quadraticBezierTo(cx - 5, cy + 12, cx, cy + 7)
      ..quadraticBezierTo(cx + 5, cy + 12, cx + 10, cy + 7);
    canvas.drawPath(mouthPath, linePaint);

    // ★ 입맛 다시기(lickingLips) 상태일 때 귀여운 핑크 혀 날름 애니메이션!
    if (pose == CatMoodPose.lickingLips) {
      final tongueSlide = math.sin(animProgress * math.pi) * 3;
      final tonguePath = Path()
        ..moveTo(cx + 3, cy + 8)
        ..quadraticBezierTo(
          cx + 14 + tongueSlide,
          cy + 4,
          cx + 12 + tongueSlide,
          cy + 14,
        )
        ..quadraticBezierTo(cx + 6, cy + 17, cx + 3, cy + 8)
        ..close();
      canvas.drawPath(
        tonguePath,
        Paint()..color = const Color(0xFFFF6B8B),
      );
    }

    // 8. 양옆 수염 2가닥씩
    final whiskerPaint = Paint()
      ..color = AppColors.textTaupe
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 22, cy + 3), Offset(cx - 42, cy - 1), whiskerPaint);
    canvas.drawLine(Offset(cx - 22, cy + 8), Offset(cx - 42, cy + 10), whiskerPaint);
    canvas.drawLine(Offset(cx + 22, cy + 3), Offset(cx + 42, cy - 1), whiskerPaint);
    canvas.drawLine(Offset(cx + 22, cy + 8), Offset(cx + 42, cy + 10), whiskerPaint);

    // 9. 흰 양말 앞발 (Poking 상태일 때 좌우로 교차하며 툭툭 건드림!)
    final leftPawY = pose == CatMoodPose.pokingCards
        ? cy + 34 - (animProgress * 12)
        : cy + 38;
    final rightPawY = pose == CatMoodPose.pokingCards
        ? cy + 22 + (animProgress * 12)
        : cy + 38;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 20, leftPawY), width: 17, height: 14),
      whitePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 20, rightPawY), width: 17, height: 14),
      whitePaint,
    );

    // 10. 페르소나별 클레이 소품 (깐깐한 집사냥 = 모노클 & 나비넥타이 / 모험가냥 = 탐험가 모자 & 반다나)
    if (persona == CatPersona.pickyButler) {
      // 황금 모노클 (오른쪽 눈) + 체인
      canvas.drawCircle(
        Offset(cx + 14, cy - 11),
        10.5,
        Paint()
          ..color = AppColors.clayButter
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawLine(
        Offset(cx + 24, cy - 8),
        Offset(cx + 27, cy + 12),
        Paint()
          ..color = AppColors.clayButterDark
          ..strokeWidth = 1.4,
      );
      // 빨간 나비넥타이 (흰 턱시도 가슴 위)
      final bowPaint = Paint()..color = AppColors.clayBerry;
      final leftBow = Path()
        ..moveTo(cx, cy + 20)
        ..lineTo(cx - 10, cy + 15)
        ..lineTo(cx - 10, cy + 25)
        ..close();
      final rightBow = Path()
        ..moveTo(cx, cy + 20)
        ..lineTo(cx + 10, cy + 15)
        ..lineTo(cx + 10, cy + 25)
        ..close();
      canvas.drawPath(leftBow, bowPaint);
      canvas.drawPath(rightBow, bowPaint);
      canvas.drawCircle(Offset(cx, cy + 20), 3.2, Paint()..color = Colors.white);
    } else if (persona == CatPersona.adventurer) {
      // 모험가냥 오렌지 스카프 + 탐험가 페도라 햇
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy + 18), width: 32, height: 14),
        0.15,
        math.pi - 0.3,
        true,
        Paint()..color = AppColors.clayOrange,
      );
      canvas.save();
      canvas.translate(cx - 2, cy - 35);
      canvas.rotate(-0.14);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-26, 2, 52, 7),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFB56A3B),
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTWH(-16, -11, 32, 14),
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
        ),
        Paint()..color = const Color(0xFFD6884F),
      );
      canvas.drawRect(
        const Rect.fromLTWH(-16, -2, 32, 4),
        Paint()..color = AppColors.clayOrange,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _TuxedoCatPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.persona != persona ||
        oldDelegate.animProgress != animProgress;
  }
}
