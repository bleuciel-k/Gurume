import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:oreguru/data/models/party_and_preference_model.dart';

/// 화면에 표시하지 않고 백그라운드에서 현재 위치 기준 실시간 날씨와 계절을
/// 조회하여 구루냥 추천 엔진에만 제공하는 서비스.
class WeatherService {
  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  /// 현재 월 기준 계절 계산
  SeasonType resolveCurrentSeason([DateTime? now]) {
    final month = (now ?? DateTime.now()).month;
    return switch (month) {
      >= 3 && <= 5 => SeasonType.spring,
      >= 6 && <= 8 => SeasonType.summer,
      >= 9 && <= 11 => SeasonType.autumn,
      _ => SeasonType.winter,
    };
  }

  /// Open-Meteo 무인증 실시간 기상 API 조회 (실패/오프라인 시 현재 계절 기반 기본값 폴백)
  Future<WeatherCondition> fetchCurrentWeather({
    double latitude = 37.5612,
    double longitude = 126.9255,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude&longitude=$longitude'
        '&current=weather_code,temperature_2m',
      );
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        return _fallbackBySeason(resolveCurrentSeason());
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>?;
      if (current == null) {
        return _fallbackBySeason(resolveCurrentSeason());
      }

      final code = (current['weather_code'] as num?)?.toInt() ?? 0;
      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 18.0;
      return mapWmoToWeatherCondition(weatherCode: code, temperatureC: temp);
    } catch (_) {
      return _fallbackBySeason(resolveCurrentSeason());
    }
  }

  /// WMO 기상 코드 + 기온을 구루냥 날씨 컨디션으로 변환
  static WeatherCondition mapWmoToWeatherCondition({
    required int weatherCode,
    required double temperatureC,
  }) {
    // 비 / 이슬비 / 소나기 / 뇌우 (WMO 51~67, 80~82, 95~99)
    final isRain = (weatherCode >= 51 && weatherCode <= 67) ||
        (weatherCode >= 80 && weatherCode <= 82) ||
        (weatherCode >= 95 && weatherCode <= 99);
    if (isRain) return WeatherCondition.rainy;

    // 눈 (71~77, 85~86) 또는 쌀쌀한 기온
    final isSnow = (weatherCode >= 71 && weatherCode <= 77) ||
        (weatherCode >= 85 && weatherCode <= 86);
    if (isSnow || temperatureC <= 9.0) return WeatherCondition.chilly;

    if (temperatureC >= 27.0) return WeatherCondition.hot;
    return WeatherCondition.sunny;
  }

  WeatherCondition _fallbackBySeason(SeasonType season) {
    return switch (season) {
      SeasonType.winter => WeatherCondition.chilly,
      SeasonType.summer => WeatherCondition.hot,
      SeasonType.spring || SeasonType.autumn => WeatherCondition.sunny,
    };
  }
}

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});
