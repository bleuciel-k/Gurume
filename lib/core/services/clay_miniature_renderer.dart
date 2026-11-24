import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/data/models/restaurant_model.dart';

/// 오프스크린 `dart:ui` Canvas를 이용해 3D 클레이모피즘 질감(스튜디오 라디얼 음영,
/// 앰비언트 오클루전 그림자, 스페큘러 하이라이트)을 입힌 미니어처 건물 스프라이트 및
/// 취향 카드 일러스트 PNG를 렌더링합니다.
class ClayMiniatureRenderer {
  /// 매콤 감칠맛(`taste_spicy_kick.png`) 256x256 PNG 바이트 생성
  static Future<Uint8List> renderTasteSpicyKickPng({int size = 256}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final s = size.toDouble();
    canvas.scale(s / 256.0, s / 256.0);

    // 1. 부드러운 블러쉬 스튜디오 배경
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 256, 256),
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(104, 90),
          190,
          const [Color(0xFFFFF7F8), Color(0xFFFFEBF0), Color(0xFFF6D6DD)],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 2. 바닥 접지 그림자
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(128, 202), width: 152, height: 34),
      Paint()
        ..color = const Color(0xFF8B434F).withAlpha(48)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // 3. 매콤 클레이 전골/볶음 그릇 (둥근 세라믹 볼)
    final bowlRect = Rect.fromCenter(center: const Offset(128, 152), width: 142, height: 96);
    canvas.drawOval(
      bowlRect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(80, 108),
          const Offset(172, 198),
          const [Color(0xFFFFFFFF), Color(0xFFF5E6D6), Color(0xFFD6BFA8)],
          const [0.0, 0.45, 1.0],
        ),
    );
    // 그릇 입구 매콤 국물/소스
    final brothRect = Rect.fromCenter(center: const Offset(128, 124), width: 122, height: 50);
    canvas.drawOval(
      brothRect,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(114, 114),
          72,
          const [Color(0xFFFF865E), Color(0xFFE94B3C), Color(0xFFA7241A)],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 4. 불꽃 점토 디테일 (상단)
    _drawClayFlame(canvas, const Offset(102, 74), 0.85, const Color(0xFFFF9A44));
    _drawClayFlame(canvas, const Offset(130, 62), 1.08, const Color(0xFFFF6B47));
    _drawClayFlame(canvas, const Offset(156, 78), 0.78, const Color(0xFFFFB830));

    // 5. 앞쪽 윤기 나는 빨간 점토 고추 2개
    _drawClayChili(canvas, const Offset(82, 174), -0.45);
    _drawClayChili(canvas, const Offset(174, 176), 0.52);

    // 6. 그릇 위 토핑 (대파 & 계란 노른자)
    canvas.drawCircle(
      const Offset(128, 122),
      15,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(122, 116),
          16,
          const [Color(0xFFFFE57F), Color(0xFFFFB830), Color(0xFFD98712)],
          const [0.0, 0.55, 1.0],
        ),
    );
    canvas.drawCircle(
      const Offset(122, 116),
      4.5,
      Paint()..color = Colors.white.withAlpha(185),
    );
    for (final pt in const [Offset(102, 120), Offset(152, 126), Offset(142, 114)]) {
      canvas.drawCircle(pt, 5.5, Paint()..color = const Color(0xFF4EB87A));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// 깔끔하고 담백한 한 끼(`taste_light_clean.png`) 256x256 PNG 바이트 생성
  static Future<Uint8List> renderTasteLightCleanPng({int size = 256}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final s = size.toDouble();
    canvas.scale(s / 256.0, s / 256.0);

    // 1. 산뜻한 민트 스튜디오 배경
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 256, 256),
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(104, 88),
          190,
          const [Color(0xFFF6FCFB), Color(0xFFEAF7F6), Color(0xFFD1EAE7)],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 2. 원형 클레이 우드 트레이 + 그림자
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(128, 198), width: 174, height: 42),
      Paint()
        ..color = const Color(0xFF3E6F6B).withAlpha(42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    final trayRect = Rect.fromCenter(center: const Offset(128, 152), width: 176, height: 112);
    canvas.drawOval(
      trayRect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(70, 100),
          const Offset(180, 206),
          const [Color(0xFFF5DFBF), Color(0xFFDDBB8E), Color(0xFFB89265)],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 3. 소바 & 포케 화이트 세라믹 볼
    final bowlRect = Rect.fromCenter(center: const Offset(120, 134), width: 124, height: 92);
    canvas.drawOval(
      bowlRect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(80, 92),
          const Offset(164, 180),
          const [Color(0xFFFFFFFF), Color(0xFFF7EFE3), Color(0xFFDCD0BE)],
          const [0.0, 0.5, 1.0],
        ),
    );

    // 메밀 소바 면 + 아보카도/채소 점토 토핑
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(120, 124), width: 102, height: 64),
      Paint()..color = const Color(0xFFCBBBA4),
    );
    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(118, 118.0 + i * 7), width: 72, height: 22),
        0.1,
        2.9,
        false,
        Paint()
          ..color = const Color(0xFF9E8D78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // 초록 샐러드 볼(완두콩/아보카도) & 살몬 큐브
    for (final pt in const [
      Offset(92, 116),
      Offset(105, 108),
      Offset(118, 114),
    ]) {
      canvas.drawCircle(
        pt,
        11,
        Paint()
          ..shader = ui.Gradient.radial(
            pt - const Offset(3, 3),
            12,
            const [Color(0xFFA7E88B), Color(0xFF5DC46B), Color(0xFF3A8F4A)],
            const [0.0, 0.55, 1.0],
          ),
      );
    }
    for (final rect in [
      RRect.fromRectAndRadius(const Rect.fromLTWH(132, 108, 18, 16), const Radius.circular(5)),
      RRect.fromRectAndRadius(const Rect.fromLTWH(142, 124, 17, 15), const Radius.circular(5)),
    ]) {
      canvas.drawRRect(rect, Paint()..color = const Color(0xFFFF856D));
    }

    // 4. 우측 앞쪽 둥근 레몬 슬라이스
    canvas.save();
    canvas.translate(174, 168);
    canvas.rotate(-0.22);
    canvas.drawCircle(
      Offset.zero,
      26,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(-6, -6),
          28,
          const [Color(0xFFFFF49C), Color(0xFFFFD53E), Color(0xFFE0A719)],
          const [0.0, 0.55, 1.0],
        ),
    );
    canvas.drawCircle(Offset.zero, 21, Paint()..color = const Color(0xFFFFFBE0));
    canvas.drawCircle(Offset.zero, 17, Paint()..color = const Color(0xFFFFDE59));
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// 미니어처 3D 점토 식당 건물 스프라이트 PNG (`marker_*.png`) 192x192 생성
  static Future<Uint8List> renderClayBuildingPng(
    ClayMarkerType type, {
    int size = 192,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final s = size.toDouble();
    final bounds = Rect.fromLTWH(0, 0, s, s);

    // 따뜻한 크림 스튜디오 배경
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(s * 0.4, s * 0.32),
          s * 0.78,
          const [Color(0xFFFFFCF6), Color(0xFFFAF3E6), Color(0xFFEDE0CB)],
          const [0.0, 0.58, 1.0],
        ),
    );

    drawClayBuilding(canvas, bounds.deflate(s * 0.10), type);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// 지정된 영역(`rect`) 안에 3D 점토 미니어처 가게 건물을 입체 음영과 함께 그립니다.
  static void drawClayBuilding(
    Canvas canvas,
    Rect rect,
    ClayMarkerType type,
  ) {
    final w = rect.width;
    final h = rect.height;
    final l = rect.left;
    final t = rect.top;
    final roofColor = type.roofColor;
    final roofLight = Color.lerp(roofColor, Colors.white, 0.35)!;
    final roofDark = Color.lerp(roofColor, AppColors.textEspresso, 0.25)!;

    // 1. 접지 그림자
    canvas.drawOval(
      Rect.fromLTWH(l + w * 0.14, t + h * 0.80, w * 0.72, h * 0.16),
      Paint()
        ..color = AppColors.shadowModalWarm.withAlpha(110)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
    );

    // 2. 건물 본체(둥근 정면 + 측면 입체 벽면)
    final bodyRect = Rect.fromLTWH(l + w * 0.18, t + h * 0.36, w * 0.64, h * 0.49);
    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: Radius.circular(w * 0.08),
      topRight: Radius.circular(w * 0.08),
      bottomLeft: Radius.circular(w * 0.14),
      bottomRight: Radius.circular(w * 0.14),
    );
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..shader = ui.Gradient.linear(
          bodyRect.topLeft,
          bodyRect.bottomRight,
          const [Color(0xFFFFFFFF), Color(0xFFFAF1E2), Color(0xFFE3D1B6)],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 3. 어닝/지붕 (3D 두툼한 곡선 차양)
    final roofRect = Rect.fromLTWH(l + w * 0.11, t + h * 0.22, w * 0.78, h * 0.22);
    final roofRRect = RRect.fromRectAndCorners(
      roofRect,
      topLeft: Radius.circular(w * 0.16),
      topRight: Radius.circular(w * 0.16),
      bottomLeft: Radius.circular(w * 0.06),
      bottomRight: Radius.circular(w * 0.06),
    );
    canvas.drawRRect(
      roofRRect,
      Paint()
        ..shader = ui.Gradient.linear(
          roofRect.topLeft,
          roofRect.bottomRight,
          [roofLight, roofColor, roofDark],
          const [0.0, 0.58, 1.0],
        ),
    );

    // 지붕 스트라이프 디테일(물결/리브 느낌)
    for (int i = 0; i < 4; i++) {
      final stripeW = roofRect.width * 0.13;
      final sx = roofRect.left + w * 0.07 + i * (roofRect.width * 0.21);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sx, roofRect.top + h * 0.03, stripeW, roofRect.height * 0.76),
          Radius.circular(w * 0.04),
        ),
        Paint()..color = Colors.white.withAlpha(88),
      );
    }

    // 4. 지붕 위 포인트 조형물 (가게 타입별 개성)
    final badgeCenter = Offset(l + w * 0.50, t + h * 0.16);
    switch (type) {
      case ClayMarkerType.ramenHouse:
        // 라멘 그릇 사인
        canvas.drawOval(
          Rect.fromCenter(center: badgeCenter + Offset(0, h * 0.02), width: w * 0.28, height: h * 0.15),
          Paint()..color = const Color(0xFFFFFFFF),
        );
        canvas.drawArc(
          Rect.fromCenter(center: badgeCenter, width: w * 0.24, height: h * 0.12),
          0,
          math.pi,
          false,
          Paint()..color = roofColor,
        );
      case ClayMarkerType.izakayaRoof:
        // 좌우 주홍 초롱불
        canvas.drawCircle(
          Offset(l + w * 0.22, t + h * 0.50),
          w * 0.065,
          Paint()..color = const Color(0xFFFFB830),
        );
        canvas.drawCircle(
          Offset(l + w * 0.78, t + h * 0.50),
          w * 0.065,
          Paint()..color = const Color(0xFFFFB830),
        );
      case ClayMarkerType.grillHouse:
        // 고기집 굴뚝 + 동글 연기
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(l + w * 0.64, t + h * 0.08, w * 0.12, h * 0.16),
            Radius.circular(w * 0.04),
          ),
          Paint()..color = roofDark,
        );
        canvas.drawCircle(
          Offset(l + w * 0.70, t + h * 0.04),
          w * 0.055,
          Paint()..color = Colors.white.withAlpha(220),
        );
      case ClayMarkerType.pastaTerrace:
      case ClayMarkerType.pokeSalad:
      case ClayMarkerType.riceBowlShop:
      case ClayMarkerType.spicyPot:
        // 동글 3D 엠블럼 돔
        canvas.drawCircle(
          badgeCenter,
          w * 0.11,
          Paint()
            ..shader = ui.Gradient.radial(
              badgeCenter - Offset(w * 0.03, h * 0.03),
              w * 0.13,
              [Colors.white, roofLight, roofColor],
              const [0.0, 0.5, 1.0],
            ),
        );
    }

    // 5. 따뜻한 조명 창문 & 둥근 원목 문
    final windowRect = Rect.fromLTWH(l + w * 0.26, t + h * 0.52, w * 0.25, h * 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(windowRect, Radius.circular(w * 0.06)),
      Paint()
        ..shader = ui.Gradient.linear(
          windowRect.topLeft,
          windowRect.bottomRight,
          const [Color(0xFFFFF5C8), Color(0xFFFFD166)],
        ),
    );
    // 창틀
    canvas.drawRRect(
      RRect.fromRectAndRadius(windowRect, Radius.circular(w * 0.06)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025
        ..color = const Color(0xFF9C7A58),
    );

    final doorRect = Rect.fromLTWH(l + w * 0.57, t + h * 0.52, w * 0.17, h * 0.33);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        doorRect,
        topLeft: Radius.circular(w * 0.09),
        topRight: Radius.circular(w * 0.09),
        bottomLeft: Radius.circular(w * 0.03),
        bottomRight: Radius.circular(w * 0.03),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          doorRect.topLeft,
          doorRect.bottomRight,
          const [Color(0xFFA97C56), Color(0xFF7D583A)],
        ),
    );
    // 황동 문고리
    canvas.drawCircle(
      Offset(doorRect.left + doorRect.width * 0.28, doorRect.center.dy),
      w * 0.02,
      Paint()..color = const Color(0xFFFFDF7E),
    );
  }

  static void _drawClayFlame(Canvas canvas, Offset center, double scale, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final path = Path()
      ..moveTo(0, -24)
      ..quadraticBezierTo(18, -2, 12, 14)
      ..quadraticBezierTo(0, 22, -12, 14)
      ..quadraticBezierTo(-18, -2, 0, -24)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -24),
          const Offset(0, 20),
          [const Color(0xFFFFE57F), color],
        ),
    );
    canvas.restore();
  }

  static void _drawClayChili(Canvas canvas, Offset center, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final body = Path()
      ..moveTo(-24, -4)
      ..quadraticBezierTo(-4, -14, 22, 2)
      ..quadraticBezierTo(30, 8, 20, 12)
      ..quadraticBezierTo(-4, 14, -24, 2)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-16, -12),
          const Offset(20, 14),
          const [Color(0xFFFF6E5C), Color(0xFFD62828)],
        ),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-30, -4, 8, 6),
      Paint()..color = const Color(0xFF4EB87A),
    );
    canvas.restore();
  }
}
