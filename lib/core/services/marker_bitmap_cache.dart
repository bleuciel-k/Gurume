import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/services/clay_miniature_renderer.dart';
import 'package:oreguru/data/models/restaurant_model.dart';

/// Google Maps SDK 위에서 3D 클레이모피즘 맛집 건물 마커를
/// 고성능으로 렌더링하기 위해 오프스크린 Canvas -> PNG 바이트 -> BitmapDescriptor로
/// 변환 및 메모리 캐싱하는 서비스.
class MarkerBitmapCache {
  final Map<String, BitmapDescriptor> _cache = {};

  static const double _logicalWidth = 112.0;
  static const double _logicalHeight = 96.0;
  static const double _pixelRatio = 2.5;

  String _cacheKey(
    String restaurantId, {
    required bool isSelected,
    required bool isCandidate,
  }) =>
      '${restaurantId}_sel:${isSelected ? 1 : 0}_cand:${isCandidate ? 1 : 0}';

  /// 캐시된 마커 비트맵을 반환하거나 최초 1회 합성 후 캐시에 보관
  Future<BitmapDescriptor> getMarkerBitmap(
    RestaurantModel restaurant, {
    required bool isSelected,
    required bool isCandidate,
  }) async {
    final key = _cacheKey(
      restaurant.id,
      isSelected: isSelected,
      isCandidate: isCandidate,
    );
    final existing = _cache[key];
    if (existing != null) return existing;

    final bytes = await renderMarkerPngBytes(
      restaurant,
      isSelected: isSelected,
      isCandidate: isCandidate,
    );

    final descriptor = BitmapDescriptor.bytes(
      bytes,
      imagePixelRatio: _pixelRatio,
      width: _logicalWidth,
      height: _logicalHeight,
    );
    _cache[key] = descriptor;
    return descriptor;
  }

  /// 여러 맛집 마커 비트맵을 일괄 생성하여 ID별 맵으로 반환
  Future<Map<String, BitmapDescriptor>> buildMarkersMap(
    List<RestaurantModel> restaurants, {
    required String? selectedId,
    required Set<String> candidateIds,
  }) async {
    final entries = await Future.wait(
      restaurants.map((r) async {
        final descriptor = await getMarkerBitmap(
          r,
          isSelected: r.id == selectedId,
          isCandidate: candidateIds.contains(r.id),
        );
        return MapEntry(r.id, descriptor);
      }),
    );
    return Map<String, BitmapDescriptor>.fromEntries(entries);
  }

  /// 오프스크린 Canvas로 3D 클레이 건물/아이콘 마커 PNG 바이트 생성
  Future<Uint8List> renderMarkerPngBytes(
    RestaurantModel restaurant, {
    required bool isSelected,
    required bool isCandidate,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_pixelRatio, _pixelRatio);

    const double cx = _logicalWidth / 2;
    const double cardW = 58.0;
    const double cardH = 54.0;
    const double cardLeft = cx - cardW / 2;
    const double cardTop = 8.0;
    const double cardRadius = 14.0;

    final cardRect = Rect.fromLTWH(cardLeft, cardTop, cardW, cardH);
    final cardRRect = RRect.fromRectAndRadius(
      cardRect,
      const Radius.circular(cardRadius),
    );

    // 1. Figma 수직 하방 Drop Shadow
    canvas.drawRRect(
      cardRRect.shift(const Offset(0, 6)),
      Paint()
        ..color = (isSelected
                ? AppColors.clayOrange
                : AppColors.shadowLightClay)
            .withAlpha(115)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // 2. 클레이 건물 외곽 그라데이션 본체
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cardLeft + cardW * 0.7, cardTop + cardH),
        Offset(cardLeft + cardW * 0.3, cardTop),
        isSelected
            ? const [
                AppColors.clayOrangeDark,
                AppColors.clayOrange,
                AppColors.clayOrangeLight,
              ]
            : const [
                AppColors.clayCreamLightStop,
                Color(0xFFFFFFFF),
              ],
        isSelected ? const [0.0, 0.55, 1.0] : const [0.0, 1.0],
      );
    canvas.drawRRect(cardRRect, bodyPaint);

    // 3. 클레이 내부 하이라이트 & 음영 (EvenOdd)
    canvas.save();
    canvas.clipRRect(cardRRect);
    final outerBounds = cardRect.inflate(24);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(outerBounds)
        ..addRRect(cardRRect.shift(const Offset(2, 2))),
      Paint()
        ..color = Colors.white.withAlpha(185)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(outerBounds)
        ..addRRect(cardRRect.shift(const Offset(-3, -3))),
      Paint()
        ..color = (isSelected
                ? Colors.black.withAlpha(75)
                : AppColors.shadowInnerBeige.withAlpha(170))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );
    canvas.restore();

    // Specular 림 보더
    canvas.drawRRect(
      cardRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCandidate || isSelected ? 2.0 : 1.2
        ..color = isSelected
            ? Colors.white
            : (isCandidate ? AppColors.clayOrange : AppColors.rimBorderWhite),
    );

    // 4. 3D 점토 지붕(Awning)
    final roofColor = restaurant.clayMarkerType.roofColor;
    final roofRect = Rect.fromLTWH(cardLeft + 5, cardTop + 5, cardW - 10, 11);
    final roofRRect = RRect.fromRectAndCorners(
      roofRect,
      topLeft: const Radius.circular(9),
      topRight: const Radius.circular(9),
      bottomLeft: const Radius.circular(3),
      bottomRight: const Radius.circular(3),
    );
    canvas.drawRRect(
      roofRRect,
      Paint()
        ..shader = ui.Gradient.linear(
          roofRect.topLeft,
          roofRect.bottomRight,
          [Color.lerp(roofColor, Colors.white, 0.28)!, roofColor],
        ),
    );

    // 5. 내부 아이콘 배경 + 3D 점토 미니어처 건물 스프라이트
    final iconBgRect = Rect.fromLTWH(cardLeft + 6, cardTop + 19, cardW - 12, 29);
    canvas.drawRRect(
      RRect.fromRectAndRadius(iconBgRect, const Radius.circular(9)),
      Paint()
        ..color = isSelected
            ? Colors.white.withAlpha(235)
            : restaurant.heroColor,
    );

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(iconBgRect, const Radius.circular(9)),
    );
    ClayMiniatureRenderer.drawClayBuilding(
      canvas,
      iconBgRect.deflate(1.0),
      restaurant.clayMarkerType,
    );
    canvas.restore();

    // 6. 장바구니 담김 배지 (🐾)
    if (isCandidate) {
      const badgeRect = Rect.fromLTWH(cx + 16, 2, 20, 20);
      final badgeRRect = RRect.fromRectAndRadius(
        badgeRect,
        const Radius.circular(7),
      );
      canvas.drawRRect(
        badgeRRect,
        Paint()..color = AppColors.clayOrange,
      );
      canvas.drawRRect(
        badgeRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white,
      );
      final pawPainter = TextPainter(
        text: const TextSpan(
          text: '🐾',
          style: TextStyle(fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      pawPainter.paint(
        canvas,
        Offset(
          badgeRect.center.dx - pawPainter.width / 2,
          badgeRect.center.dy - pawPainter.height / 2,
        ),
      );
    }

    // 7. 하단 가게명 캡슐 라벨
    final labelPainter = TextPainter(
      text: TextSpan(
        text: restaurant.name,
        style: TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.w800,
          color: isSelected ? Colors.white : AppColors.textEspresso,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _logicalWidth - 10);

    final labelW = labelPainter.width + 14;
    final labelH = labelPainter.height + 6;
    final labelRect = Rect.fromLTWH(
      cx - labelW / 2,
      cardTop + cardH + 5,
      labelW,
      labelH,
    );
    final labelRRect = RRect.fromRectAndRadius(
      labelRect,
      const Radius.circular(8),
    );

    canvas.drawRRect(
      labelRRect.shift(const Offset(0, 2)),
      Paint()
        ..color = AppColors.textEspresso.withAlpha(36)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      labelRRect,
      Paint()
        ..color = isSelected
            ? AppColors.clayOrange
            : AppColors.clayCream.withAlpha(245),
    );
    labelPainter.paint(
      canvas,
      Offset(labelRect.left + 7, labelRect.top + 3),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (_logicalWidth * _pixelRatio).round(),
      (_logicalHeight * _pixelRatio).round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void clear() => _cache.clear();
}
