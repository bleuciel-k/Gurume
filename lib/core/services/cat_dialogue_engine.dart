import 'package:oreguru/data/models/party_and_preference_model.dart';
import 'package:oreguru/data/models/restaurant_model.dart';

/// 요일 · 시간대 · 페르소나 · 반주/날씨 컨텍스트에 맞춰
/// 구루냥의 대사를 생성하고 동적 질문 분기 조건을 판단하는 순수 Dart 엔진.
class CatDialogueEngine {
  /// 현재 요일/시간대에 어울리는 짧은 상황 태그 배지 반환
  static String resolveSituationTag(DateTime now) {
    final hour = now.hour;
    final weekday = now.weekday;

    if (weekday == DateTime.friday && hour >= 17 && hour < 22) {
      return '🔥 불금 저녁';
    }
    if (weekday == DateTime.monday && hour >= 11 && hour < 14) {
      return '💥 헬요일 점심';
    }
    if (hour >= 22 || hour < 4) {
      return '🌙 심야 야식 타임';
    }
    if ((weekday == DateTime.saturday || weekday == DateTime.sunday) &&
        hour >= 10 &&
        hour < 15) {
      return '☀️ 주말 브런치';
    }
    if (hour >= 11 && hour < 14) {
      return '🍱 평일 점심 피크';
    }
    if (hour >= 17 && hour < 22) {
      return '🌆 저녁 골든타임';
    }
    return '';
  }

  /// 저녁 시간대(17시 이후 ~ 새벽 4시 미만) + 2인 이상 모임일 때만 한잔 질문 자동 추가
  static bool shouldAskDrinkQuestion({
    required PartyType? party,
    required DateTime now,
  }) {
    if (party == null || party.isSolo) return false;
    return now.hour >= 17 || now.hour < 4;
  }

  /// 페르소나 & 시간대/요일 반영 첫 인사말 생성
  static String buildOpeningDialogue({
    required CatPersona persona,
    required DateTime now,
  }) {
    final tag = resolveSituationTag(now);
    final timeHook = switch (tag) {
      '🔥 불금 저녁' => '드디어 불금 저녁이구나! 오늘 기름칠 제대로 할 준비 됐냥?',
      '💥 헬요일 점심' => '월요일 점심은 든든하고 맛있는 걸로 헬요일을 혼내주자냥!',
      '🌙 심야 야식 타임' => '야식은 원래 0칼로리라냥~ 밤공기 맡으며 갈 곳을 골라보자!',
      '☀️ 주말 브런치' => '여유로운 주말 낮이구나! 느긋하게 미식 산책 떠나볼까냥?',
      _ => '후보지는 잘 담아왔군!',
    };

    return switch (persona) {
      CatPersona.classic => '$timeHook 오늘 누구랑 가는 모임인지 골라보라냥~ 😼',
      CatPersona.pickyButler =>
        '흠, 내가 직접 웨이팅·가성비·평점까지 다 따져볼 테니 동행부터 알려달라냥! 🧐',
      CatPersona.adventurer =>
        '$timeHook 짜릿하고 색다른 한 끼 찾아 떠나보자! 누구랑 가는지 골라봐! 🤠',
    };
  }

  /// 최종 추천 결과에 대한 페르소나 + 시간/날씨/반주 맞춤형 결정 대사 생성
  static String buildPickedDialogue({
    required RestaurantModel picked,
    required CatPersona persona,
    required bool isWeatherPick,
    required WeatherCondition weather,
    required SeasonType season,
    required DateTime now,
    required bool hasClearWeatherEvidence,
    DrinkPreference? drinkPreference,
  }) {
    final tag = resolveSituationTag(now);

    if (isWeatherPick) {
      final base = picked.buildWeatherCatComment(
        weather,
        season,
        hasClearWeatherEvidence: hasClearWeatherEvidence,
      );
      if (tag == '🌙 심야 야식 타임') {
        return '이 밤에 ${picked.signatureDish} 한 입이면 완전 반칙이지! $base';
      }
      if (tag == '🔥 불금 저녁') {
        return '불금엔 고민 길게 하지 말라냥! $base';
      }
      return base;
    }

    if (drinkPreference == DrinkPreference.yesDrink &&
        (picked.clayMarkerType == ClayMarkerType.izakayaRoof ||
            picked.clayMarkerType == ClayMarkerType.grillHouse ||
            picked.clayMarkerType == ClayMarkerType.spicyPot)) {
      return '오늘 밤 가볍게 한잔 곁들이기에 "${picked.signatureDish}" 조합이 그야말로 완벽하다냥! 🍺🐾';
    }

    return switch (persona) {
      CatPersona.pickyButler =>
        '평점 ⭐${picked.rating.toStringAsFixed(1)}에 가격(${picked.priceRangeText})까지 합리적! '
            '${picked.hasNoWaiting ? "웨이팅도 적어서 " : ""}'
            '실패 확률 제로의 정석 픽이라냥! 🧐',
      CatPersona.adventurer =>
        '모험가냥의 촉이 왔다! "${picked.signatureDish}" 먹으러 지금 바로 출동하자냥~ 🤠🔥',
      CatPersona.classic => switch (tag) {
          '🔥 불금 저녁' =>
            '불금 저녁 텐션엔 역시 "${picked.signatureDish}"가 정답이지! 후회 없다냥~ 😼🔥',
          '💥 헬요일 점심' =>
            '헬요일 스트레스는 ${picked.name}에서 ${picked.signatureDish}(으)로 날려버리자냥! 💥',
          '🌙 심야 야식 타임' =>
            '야심한 시각엔 역시 "${picked.signatureDish}"! 구루냥의 밤 픽이라냥~ 🌙🐾',
          _ => picked.defaultTasteComment,
        },
    };
  }
}
