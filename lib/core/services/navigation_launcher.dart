import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 사용자가 선택할 수 있는 외부 길찾기 지도 앱 목록
enum MapNavApp {
  naver(
    label: '네이버 지도',
    subtitle: '국내 도보·대중교통 길찾기 추천',
    badgeEmoji: '🟢',
    accentColor: Color(0xFF03C75A),
  ),
  kakao(
    label: '카카오맵',
    subtitle: '실시간 빠른 도보/경로 안내',
    badgeEmoji: '🟡',
    accentColor: Color(0xFFFFCD00),
  ),
  google(
    label: 'Google Maps',
    subtitle: '도보 내비게이션 & 장소 리뷰 확인',
    badgeEmoji: '🔵',
    accentColor: Color(0xFF4285F4),
  ),
  apple(
    label: 'Apple Maps',
    subtitle: 'iPhone / Mac 기본 지도에서 열기',
    badgeEmoji: '⚪️',
    accentColor: Color(0xFF2D241E),
  );

  final String label;
  final String subtitle;
  final String badgeEmoji;
  final Color accentColor;

  const MapNavApp({
    required this.label,
    required this.subtitle,
    required this.badgeEmoji,
    required this.accentColor,
  });
}

/// 외부 지도 앱 딥링크 및 웹 폴백 URL 생성기 / 실행기
class NavigationLauncher {
  /// 앱 딥링크(네이티브 전용) URI 생성; 웹 전용 앱은 웹 URI 반환
  static Uri buildAppUri(
    MapNavApp app, {
    required double latitude,
    required double longitude,
    required String name,
  }) {
    final encodedName = Uri.encodeComponent(name);
    switch (app) {
      case MapNavApp.naver:
        return Uri.parse(
          'nmap://route/walk?dlat=$latitude&dlng=$longitude'
          '&dname=$encodedName&appname=com.oreguru.app',
        );
      case MapNavApp.kakao:
        return Uri.parse('kakaomap://route?ep=$latitude,$longitude&by=FOOT');
      case MapNavApp.google:
      case MapNavApp.apple:
        return buildWebFallbackUri(
          app,
          latitude: latitude,
          longitude: longitude,
          name: name,
        );
    }
  }

  /// 앱 미설치 환경 및 웹 브라우저용 HTTPS 폴백 URL 생성
  static Uri buildWebFallbackUri(
    MapNavApp app, {
    required double latitude,
    required double longitude,
    required String name,
  }) {
    final encodedName = Uri.encodeComponent(name);
    switch (app) {
      case MapNavApp.naver:
        return Uri.parse('https://map.naver.com/p/search/$encodedName');
      case MapNavApp.kakao:
        return Uri.parse(
          'https://map.kakao.com/link/to/$encodedName,$latitude,$longitude',
        );
      case MapNavApp.google:
        return Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&destination=$latitude,$longitude&travelmode=walking',
        );
      case MapNavApp.apple:
        return Uri.parse(
          'https://maps.apple.com/?daddr=$latitude,$longitude'
          '&q=$encodedName&dirflg=w',
        );
    }
  }

  /// 지정된 지도 앱으로 길찾기 실행 (네이티브 앱 미설치 시 웹 URL로 폴백)
  static Future<bool> launchNavigation({
    required MapNavApp app,
    required double latitude,
    required double longitude,
    required String name,
  }) async {
    final webUri = buildWebFallbackUri(
      app,
      latitude: latitude,
      longitude: longitude,
      name: name,
    );

    try {
      if (!kIsWeb && (app == MapNavApp.naver || app == MapNavApp.kakao)) {
        final appUri = buildAppUri(
          app,
          latitude: latitude,
          longitude: longitude,
          name: name,
        );
        if (await canLaunchUrl(appUri)) {
          final launched = await launchUrl(
            appUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      }

      return await launchUrl(
        webUri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
