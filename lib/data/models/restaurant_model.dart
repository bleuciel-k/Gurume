import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/data/models/party_and_preference_model.dart';

/// 2D 지도 위에 3D 점토 질감으로 렌더링되는 맛집 건물/아이콘 마커 타입
enum ClayMarkerType {
  ramenHouse('🍜', '라멘집', Color(0xFFFF8E5E)),
  izakayaRoof('🍶', '주막/이자카야', Color(0xFF7B61FF)),
  riceBowlShop('🍛', '덮밥/가정식', Color(0xFFFFB830)),
  grillHouse('🥩', '구이/고기집', Color(0xFFE85D75)),
  pastaTerrace('🍕', '브런치/양식', Color(0xFF4ECDC4)),
  pokeSalad('🥗', '포케/소바', Color(0xFF4ECDC4)),
  spicyPot('🍲', '전골/얼큰요리', Color(0xFFFC7D4E));

  final String emoji;
  final String label;
  final Color roofColor;

  const ClayMarkerType(this.emoji, this.label, this.roofColor);
}

/// 현재 시각 기준 매장 실시간 영업 상태
enum OpenStatus {
  open('영업중'),
  breakTime('브레이크타임'),
  closed('영업종료');

  final String label;

  const OpenStatus(this.label);
}

/// 매장의 구조화된 영업시간/브레이크타임/정기휴무일 스케줄
@immutable
class OpeningHoursSchedule {
  final String openTime;
  final String closeTime;
  final String? breakStart;
  final String? breakEnd;

  /// `DateTime.monday` (1) ~ `DateTime.sunday` (7)
  final List<int> closedWeekdays;

  const OpeningHoursSchedule({
    required this.openTime,
    required this.closeTime,
    this.breakStart,
    this.breakEnd,
    this.closedWeekdays = const [],
  });

  /// 지정된 시각(기본: 현재 시각)에 대해 실시간 영업 상태 판별
  OpenStatus evaluateStatus([DateTime? now]) {
    final target = now ?? DateTime.now();
    final openMinutes = _parseMinutes(openTime);
    final closeMinutes = _parseMinutes(closeTime);
    if (openMinutes == null || closeMinutes == null) {
      return OpenStatus.open;
    }

    final nowMinutes = target.hour * 60 + target.minute;
    final isOvernight = closeMinutes <= openMinutes;

    if (isOvernight) {
      // 자정을 넘긴 심야 영업 시간대(예: 17:00 - 01:00, 현재 00:30)
      if (nowMinutes < closeMinutes) {
        final yesterdayWeekday =
            target.weekday == DateTime.monday ? DateTime.sunday : target.weekday - 1;
        if (closedWeekdays.contains(yesterdayWeekday)) {
          return OpenStatus.closed;
        }
        return _isWithinBreakTime(nowMinutes)
            ? OpenStatus.breakTime
            : OpenStatus.open;
      }

      if (closedWeekdays.contains(target.weekday)) {
        return OpenStatus.closed;
      }
      if (nowMinutes >= openMinutes) {
        return _isWithinBreakTime(nowMinutes)
            ? OpenStatus.breakTime
            : OpenStatus.open;
      }
      return OpenStatus.closed;
    }

    if (closedWeekdays.contains(target.weekday)) {
      return OpenStatus.closed;
    }

    if (nowMinutes < openMinutes || nowMinutes >= closeMinutes) {
      return OpenStatus.closed;
    }

    if (_isWithinBreakTime(nowMinutes)) {
      return OpenStatus.breakTime;
    }

    return OpenStatus.open;
  }

  bool _isWithinBreakTime(int nowMinutes) {
    final startRaw = breakStart;
    final endRaw = breakEnd;
    if (startRaw == null || endRaw == null) return false;
    final start = _parseMinutes(startRaw);
    final end = _parseMinutes(endRaw);
    if (start == null || end == null || end <= start) return false;
    return nowMinutes >= start && nowMinutes < end;
  }

  static int? _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 24 || minute < 0 || minute > 59) return null;
    if (hour == 24 && minute > 0) return null;
    return hour * 60 + minute;
  }

  Map<String, dynamic> toMap() {
    return {
      'openTime': openTime,
      'closeTime': closeTime,
      if (breakStart != null && breakStart!.isNotEmpty) 'breakStart': breakStart,
      if (breakEnd != null && breakEnd!.isNotEmpty) 'breakEnd': breakEnd,
      if (closedWeekdays.isNotEmpty) 'closedWeekdays': closedWeekdays,
    };
  }

  factory OpeningHoursSchedule.fromMap(Map<String, dynamic> map) {
    final rawClosed = (map['closedWeekdays'] as List?) ?? const [];
    final closed = rawClosed
        .map((e) => e is int ? e : (e as num?)?.toInt())
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toList();

    return OpeningHoursSchedule(
      openTime: map['openTime'] as String? ?? '11:30',
      closeTime: map['closeTime'] as String? ?? '22:00',
      breakStart: map['breakStart'] as String?,
      breakEnd: map['breakEnd'] as String?,
      closedWeekdays: closed,
    );
  }
}

/// 자체 DB(Cloud Firestore + 로컬 캐시)에 저장되는 맛집 모델.
/// Google Places API를 앱 실행마다 호출하지 않기 위해 모든 탐색/추천 메타데이터를 내장합니다.
@immutable
class RestaurantModel {
  final String id;
  final String name;
  final String category;
  final String oneLineReview;
  final double latitude;
  final double longitude;
  final String geohash;
  final ClayMarkerType clayMarkerType;
  final Color heroColor;
  final double rating;
  final int distanceMeters;

  // 원탭 필터 & 상세 카드 즉각 대응 필드
  final bool isOpenNow;
  final bool hasNoWaiting;
  final bool isSoloFriendly;
  final String openHoursText;
  final String? thumbnailUrl;
  final String priceRangeText;
  final OpeningHoursSchedule? openingHours;

  // Firestore 증분 동기화 삭제(Tombstone) 플래그
  final bool isDeleted;

  // 구루냥(턱시도 고양이) 매칭용 태그
  final List<PartyType> suitableParties;
  final List<VibePreference> vibeTags;
  final List<TastePreference> tasteTags;
  final List<WeatherCondition> weatherTags;
  final List<SeasonType> seasonTags;

  // 구루냥 입맛 다시기용 대표 메뉴 & 날씨/취향 대사
  final String signatureDish;
  final Map<WeatherCondition, String> weatherComments;
  final String defaultTasteComment;

  final int updatedAtMillis;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.category,
    required this.oneLineReview,
    required this.latitude,
    required this.longitude,
    required this.geohash,
    required this.clayMarkerType,
    required this.heroColor,
    required this.rating,
    required this.distanceMeters,
    required this.isOpenNow,
    required this.hasNoWaiting,
    required this.isSoloFriendly,
    required this.openHoursText,
    this.thumbnailUrl,
    this.priceRangeText = '1만원대',
    this.openingHours,
    this.isDeleted = false,
    required this.suitableParties,
    required this.vibeTags,
    required this.tasteTags,
    required this.weatherTags,
    required this.seasonTags,
    required this.signatureDish,
    required this.weatherComments,
    required this.defaultTasteComment,
    required this.updatedAtMillis,
  });

  /// 구조화된 `openingHours`가 있으면 현재 시각 기준으로 실시간 판별하고, 없으면 저장된 `isOpenNow` 폴백
  OpenStatus evaluateOpenStatus([DateTime? now]) {
    if (openingHours != null) {
      return openingHours!.evaluateStatus(now);
    }
    return isOpenNow ? OpenStatus.open : OpenStatus.closed;
  }

  bool isCurrentlyOpen([DateTime? now]) {
    return evaluateOpenStatus(now) == OpenStatus.open;
  }

  /// 현재 날씨 조건에 맞는 구루냥의 입맛 다시기 대사 반환
  String buildWeatherCatComment(
    WeatherCondition weather,
    SeasonType season, {
    required bool hasClearWeatherEvidence,
  }) {
    if (!hasClearWeatherEvidence) {
      return '날씨나 계절로 딱 가르긴 어렵지만~ 내 고양이 육감으론 '
          '$signatureDish(이)가 있는 이 가게가 제일 맛있어 보이는구나! 츄릅~ 🐾';
    }

    final custom = weatherComments[weather];
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }

    return '${weather.headlinePrefix} '
        '$signatureDish(이)가 있는 이 가게가 유독 맛있어 보이는구나! 츄릅~ 🐾';
  }

  RestaurantModel copyWith({
    String? id,
    String? name,
    String? category,
    String? oneLineReview,
    double? latitude,
    double? longitude,
    String? geohash,
    ClayMarkerType? clayMarkerType,
    Color? heroColor,
    double? rating,
    int? distanceMeters,
    bool? isOpenNow,
    bool? hasNoWaiting,
    bool? isSoloFriendly,
    String? openHoursText,
    String? thumbnailUrl,
    String? priceRangeText,
    OpeningHoursSchedule? openingHours,
    bool? isDeleted,
    List<PartyType>? suitableParties,
    List<VibePreference>? vibeTags,
    List<TastePreference>? tasteTags,
    List<WeatherCondition>? weatherTags,
    List<SeasonType>? seasonTags,
    String? signatureDish,
    Map<WeatherCondition, String>? weatherComments,
    String? defaultTasteComment,
    int? updatedAtMillis,
  }) {
    return RestaurantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      oneLineReview: oneLineReview ?? this.oneLineReview,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohash: geohash ?? this.geohash,
      clayMarkerType: clayMarkerType ?? this.clayMarkerType,
      heroColor: heroColor ?? this.heroColor,
      rating: rating ?? this.rating,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      isOpenNow: isOpenNow ?? this.isOpenNow,
      hasNoWaiting: hasNoWaiting ?? this.hasNoWaiting,
      isSoloFriendly: isSoloFriendly ?? this.isSoloFriendly,
      openHoursText: openHoursText ?? this.openHoursText,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      priceRangeText: priceRangeText ?? this.priceRangeText,
      openingHours: openingHours ?? this.openingHours,
      isDeleted: isDeleted ?? this.isDeleted,
      suitableParties: suitableParties ?? this.suitableParties,
      vibeTags: vibeTags ?? this.vibeTags,
      tasteTags: tasteTags ?? this.tasteTags,
      weatherTags: weatherTags ?? this.weatherTags,
      seasonTags: seasonTags ?? this.seasonTags,
      signatureDish: signatureDish ?? this.signatureDish,
      weatherComments: weatherComments ?? this.weatherComments,
      defaultTasteComment: defaultTasteComment ?? this.defaultTasteComment,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
    );
  }

  /// Cloud Firestore DocumentSnapshot 역직렬화
  factory RestaurantModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RestaurantModel.fromMap({
      ...data,
      'id': (data['id'] as String?)?.isNotEmpty == true ? data['id'] : doc.id,
    });
  }

  /// Firestore 저장 및 로컬 JSON 캐싱용 Map 직렬화
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'oneLineReview': oneLineReview,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'clayMarkerType': clayMarkerType.name,
      'heroColorValue': heroColor.toARGB32(),
      'rating': rating,
      'distanceMeters': distanceMeters,
      if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
        'thumbnailUrl': thumbnailUrl,
      'priceRangeText': priceRangeText,
      if (openingHours != null) 'openingHours': openingHours!.toMap(),
      if (isDeleted) 'isDeleted': true,
      'status': {
        'isOpenNow': isOpenNow,
        'hasNoWaiting': hasNoWaiting,
        'isSoloFriendly': isSoloFriendly,
        'openHoursText': openHoursText,
      },
      'matchingTags': {
        'partyTypes': suitableParties.map((e) => e.name).toList(),
        'vibeTags': vibeTags.map((e) => e.name).toList(),
        'tasteTags': tasteTags.map((e) => e.name).toList(),
        'weatherTags': weatherTags.map((e) => e.name).toList(),
        'seasonTags': seasonTags.map((e) => e.name).toList(),
      },
      'catComments': {
        'signatureDish': signatureDish,
        if (weatherComments[WeatherCondition.rainy] != null)
          'rainyComment': weatherComments[WeatherCondition.rainy],
        if (weatherComments[WeatherCondition.sunny] != null)
          'sunnyComment': weatherComments[WeatherCondition.sunny],
        if (weatherComments[WeatherCondition.chilly] != null)
          'chillyComment': weatherComments[WeatherCondition.chilly],
        if (weatherComments[WeatherCondition.hot] != null)
          'hotComment': weatherComments[WeatherCondition.hot],
        'defaultTasteComment': defaultTasteComment,
      },
      'updatedAt': updatedAtMillis,
    };
  }

  /// Firestore 문서 저장용 별칭
  Map<String, dynamic> toFirestore() => toMap();

  /// Map(로컬 캐시 JSON 또는 Firestore 문서 데이터) 역직렬화
  factory RestaurantModel.fromMap(Map<String, dynamic> map) {
    final status = (map['status'] as Map<String, dynamic>?) ?? const {};
    final tags = (map['matchingTags'] as Map<String, dynamic>?) ?? const {};
    final comments = (map['catComments'] as Map<String, dynamic>?) ?? const {};

    final heroColorRaw = map['heroColorValue'];
    final heroColor = heroColorRaw is int
        ? Color(heroColorRaw)
        : AppColors.clayOrangeSoftBg;

    final rawUpdatedAt = map['updatedAt'];
    final updatedAtMillis = switch (rawUpdatedAt) {
      int v => v,
      num v => v.toInt(),
      Timestamp ts => ts.millisecondsSinceEpoch,
      _ => 0,
    };

    final rawOpeningHours = map['openingHours'];
    final openingHours = rawOpeningHours is Map
        ? OpeningHoursSchedule.fromMap(Map<String, dynamic>.from(rawOpeningHours))
        : null;

    return RestaurantModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      oneLineReview: map['oneLineReview'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 37.5612,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 126.9258,
      geohash: map['geohash'] as String? ?? '',
      clayMarkerType: _enumByName(ClayMarkerType.values, map['clayMarkerType']) ??
          ClayMarkerType.ramenHouse,
      heroColor: heroColor,
      rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
      distanceMeters: (map['distanceMeters'] as num?)?.toInt() ?? 300,
      isOpenNow: status['isOpenNow'] as bool? ?? true,
      hasNoWaiting: status['hasNoWaiting'] as bool? ?? true,
      isSoloFriendly: status['isSoloFriendly'] as bool? ?? false,
      openHoursText: status['openHoursText'] as String? ?? '11:30 - 22:00',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      priceRangeText: map['priceRangeText'] as String? ?? '1만원대',
      openingHours: openingHours,
      isDeleted: map['isDeleted'] as bool? ?? false,
      suitableParties: ((tags['partyTypes'] as List?) ?? const [])
          .map((id) => _enumByName(PartyType.values, id))
          .whereType<PartyType>()
          .toList(),
      vibeTags: ((tags['vibeTags'] as List?) ?? const [])
          .map((id) => _enumByName(VibePreference.values, id))
          .whereType<VibePreference>()
          .toList(),
      tasteTags: ((tags['tasteTags'] as List?) ?? const [])
          .map((id) => _enumByName(TastePreference.values, id))
          .whereType<TastePreference>()
          .toList(),
      weatherTags: ((tags['weatherTags'] as List?) ?? const [])
          .map((id) => _enumByName(WeatherCondition.values, id))
          .whereType<WeatherCondition>()
          .toList(),
      seasonTags: ((tags['seasonTags'] as List?) ?? const [])
          .map((id) => _enumByName(SeasonType.values, id))
          .whereType<SeasonType>()
          .toList(),
      signatureDish: comments['signatureDish'] as String? ?? '대표 메뉴',
      weatherComments: {
        if (comments['rainyComment'] != null)
          WeatherCondition.rainy: comments['rainyComment'] as String,
        if (comments['sunnyComment'] != null)
          WeatherCondition.sunny: comments['sunnyComment'] as String,
        if (comments['chillyComment'] != null)
          WeatherCondition.chilly: comments['chillyComment'] as String,
        if (comments['hotComment'] != null)
          WeatherCondition.hot: comments['hotComment'] as String,
      },
      defaultTasteComment:
          comments['defaultTasteComment'] as String? ?? '이 집 메뉴가 딱이라구! 😼',
      updatedAtMillis: updatedAtMillis,
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
