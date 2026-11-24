import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// 2D 위도/경도 좌표 모델
class GeoPoint2D {
  final double latitude;
  final double longitude;

  const GeoPoint2D({
    required this.latitude,
    required this.longitude,
  });

  double distanceMetersTo(GeoPoint2D other) {
    return LocationService.calculateDistanceMeters(
      startLat: latitude,
      startLng: longitude,
      endLat: other.latitude,
      endLng: other.longitude,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GeoPoint2D &&
            other.latitude == latitude &&
            other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// 연남동(홍대입구역 3번 출구 인근) 기본 기준 좌표
const GeoPoint2D kDefaultYeonnamLocation = GeoPoint2D(
  latitude: 37.5612,
  longitude: 126.9255,
);

/// 위치 조회 결과 (실제 GPS 수신 여부 포함)
class LocationFetchResult {
  final GeoPoint2D location;
  final bool isLiveGps;

  const LocationFetchResult({
    required this.location,
    required this.isLiveGps,
  });
}

/// 실제 GPS 조회, Haversine 직선 거리 계산 및 거리 텍스트 포맷팅 서비스
class LocationService {
  static const double _earthRadiusMeters = 6371000.0;

  /// 현재 기기 위치 조회 (권한 거부/비활성/오류 시 연남동 기본 좌표로 안전 폴백)
  Future<LocationFetchResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationFetchResult(
          location: kDefaultYeonnamLocation,
          isLiveGps: false,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationFetchResult(
          location: kDefaultYeonnamLocation,
          isLiveGps: false,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );

      return LocationFetchResult(
        location: GeoPoint2D(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
        isLiveGps: true,
      );
    } catch (_) {
      return const LocationFetchResult(
        location: kDefaultYeonnamLocation,
        isLiveGps: false,
      );
    }
  }

  /// 두 위경도 좌표 사이의 직선 거리(미터) 계산 (Haversine)
  static double calculateDistanceMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final dLat = _degToRad(endLat - startLat);
    final dLng = _degToRad(endLng - startLng);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(startLat)) *
            math.cos(_degToRad(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadiusMeters * c;
  }

  static int roundedDistanceMeters(
    GeoPoint2D origin, {
    required double targetLat,
    required double targetLng,
  }) {
    return calculateDistanceMeters(
      startLat: origin.latitude,
      startLng: origin.longitude,
      endLat: targetLat,
      endLng: targetLng,
    ).round();
  }

  /// 미터 단위 거리를 사용자 친화적 문자열(예: 180m, 1.2km)로 포맷
  static String formatDistance(int meters) {
    if (meters < 0) return '0m';
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  static double _degToRad(double degrees) => degrees * (math.pi / 180.0);
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
