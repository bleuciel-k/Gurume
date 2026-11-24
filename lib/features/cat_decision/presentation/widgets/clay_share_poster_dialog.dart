import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/core/services/poster_share_bridge.dart';
import 'package:oreguru/core/widgets/clay_button.dart';
import 'package:oreguru/core/widgets/clay_container.dart';
import 'package:oreguru/core/widgets/restaurant_thumbnail.dart';
import 'package:oreguru/data/models/party_and_preference_model.dart';
import 'package:oreguru/data/models/restaurant_model.dart';

/// 구루냥이 점지한 최종 맛집을 클레이 포스터 이미지(PNG) 저장 또는 메신저 텍스트로 공유하는 다이얼로그
Future<void> showClaySharePosterDialog(
  BuildContext context, {
  required RestaurantModel restaurant,
  required CatPersona persona,
  required String catDialogue,
  required String distanceLabel,
  required String openStatusLabel,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ClaySharePosterDialog(
      restaurant: restaurant,
      persona: persona,
      catDialogue: catDialogue,
      distanceLabel: distanceLabel,
      openStatusLabel: openStatusLabel,
    ),
  );
}

class _ClaySharePosterDialog extends StatefulWidget {
  final RestaurantModel restaurant;
  final CatPersona persona;
  final String catDialogue;
  final String distanceLabel;
  final String openStatusLabel;

  const _ClaySharePosterDialog({
    required this.restaurant,
    required this.persona,
    required this.catDialogue,
    required this.distanceLabel,
    required this.openStatusLabel,
  });

  @override
  State<_ClaySharePosterDialog> createState() => _ClaySharePosterDialogState();
}

class _ClaySharePosterDialogState extends State<_ClaySharePosterDialog> {
  final GlobalKey _posterKey = GlobalKey();
  bool _isSaving = false;
  String? _feedbackMessage;

  String get _shareText {
    final r = widget.restaurant;
    return '오늘 ${widget.persona.label}이 점지한 곳: ${r.name} '
        '(${r.signatureDish} · ${r.priceRangeText} · ${widget.distanceLabel}) '
        '— 이의 제기 불가 🐾\n"${widget.catDialogue}"';
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    setState(() => _feedbackMessage = message);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.textEspresso,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.buttonInput),
        ),
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _savePosterPng() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    String? savedLocation;
    try {
      final renderObj = _posterKey.currentContext?.findRenderObject();
      if (renderObj is RenderRepaintBoundary) {
        final image = await renderObj.toImage(pixelRatio: 2.5);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          savedLocation = await exportClayPosterPng(
            byteData.buffer.asUint8List(),
            fileName: 'oreguru_${widget.restaurant.id}.png',
            shareText: _shareText,
          );
        }
      }
    } catch (_) {
      savedLocation = null;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    _showFeedback(
      savedLocation != null
          ? '🖼️ 클레이 포스터 이미지를 저장/공유했어요!'
          : '🖼️ 포스터 저장이 완료되지 않았어요. 문구 복사를 이용해 주세요.',
    );
  }

  Future<void> _copyShareText() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: _shareText),
      ).timeout(const Duration(seconds: 1));
    } catch (_) {
      // 클립보드 채널 미지원/타임아웃 환경 무시
    }
    _showFeedback('📋 카톡/메신저 공유 문구를 클립보드에 복사했어요! 🐾');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 캡처 대상 클레이 포스터 카드
            RepaintBoundary(
              key: _posterKey,
              child: ClayContainer(
                variant: ClaySurfaceVariant.card,
                borderRadius: AppRadii.heroContainer,
                padding: const EdgeInsets.all(20),
                border: Border.all(
                  color: AppColors.clayOrange.withAlpha(185),
                  width: 2.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 상단 브랜드 + 페르소나 스탬프
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.clayOrangeSoftBg,
                            borderRadius: BorderRadius.circular(AppRadii.badge),
                          ),
                          child: const Text(
                            '😼 オレグル · 오늘의 픽',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.clayOrangeDark,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.persona.emoji} ${widget.persona.label}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTaupe,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 구루냥 메달리온 + 맛집 3D 썸네일 나란히 배치
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClayContainer(
                          variant: ClaySurfaceVariant.recessed,
                          borderRadius: AppRadii.cardChip,
                          width: 78,
                          height: 78,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.cardChip),
                            child: Image.asset(
                              'assets/images/clay/gurunyan_mascot.png',
                              width: 78,
                              height: 78,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.clayOrangeSoftBg,
                                alignment: Alignment.center,
                                child: Text(
                                  widget.persona.emoji,
                                  style: const TextStyle(fontSize: 34),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '🐾 ➜',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.clayOrange,
                            ),
                          ),
                        ),
                        RestaurantThumbnail(
                          restaurant: r,
                          size: 78,
                          emojiSize: 36,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      r.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textEspresso,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.category} · ⭐ ${r.rating} · ${widget.distanceLabel} · ${widget.openStatusLabel}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTaupe,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 가격대 + 대표 메뉴 캡슐
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.clayOrangeSoftBg,
                            borderRadius: BorderRadius.circular(AppRadii.badge),
                          ),
                          child: Text(
                            '🍽️ ${r.signatureDish}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.clayOrangeDark,
                            ),
                          ),
                        ),
                        if (r.priceRangeText.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgWarmSand,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.badge),
                            ),
                            child: Text(
                              '💰 ${r.priceRangeText}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textTaupe,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 포스터 선언문 배너
                    ClayContainer(
                      variant: ClaySurfaceVariant.recessed,
                      borderRadius: AppRadii.buttonInput,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            '"오늘 구루냥이 점지한 곳: ${r.name} — 이의 제기 불가 🐾"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.clayOrangeDark,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.catDialogue,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textEspresso,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_feedbackMessage != null) ...[
              const SizedBox(height: 10),
              ClayContainer(
                variant: ClaySurfaceVariant.mint,
                borderRadius: AppRadii.buttonInput,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  _feedbackMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // 포스터 저장 / 공유 + 문구 복사 + 닫기 버튼
            Row(
              children: [
                Expanded(
                  child: ClayButton(
                    key: const Key('save_poster_png_button'),
                    variant: ClaySurfaceVariant.accent,
                    borderRadius: AppRadii.buttonInput,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onPressed: _isSaving ? null : _savePosterPng,
                    child: Text(
                      _isSaving ? '생성 중...' : '🖼️ 포스터 PNG 저장',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClayButton(
                    key: const Key('copy_poster_text_button'),
                    variant: ClaySurfaceVariant.raised,
                    borderRadius: AppRadii.buttonInput,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onPressed: _copyShareText,
                    child: const Text(
                      '📋 문구 복사',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textEspresso,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClayButton(
              variant: ClaySurfaceVariant.raised,
              borderRadius: AppRadii.buttonInput,
              padding: const EdgeInsets.symmetric(vertical: 11),
              onPressed: () => Navigator.of(context).pop(),
              child: const Center(
                child: Text(
                  '닫기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTaupe,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
