import 'package:flutter/material.dart';
import 'package:oreguru/core/constants/app_colors.dart';

/// 구루냥 성격(페르소나) 모드 3종
enum CatPersona {
  classic(
    label: '기본 구루냥',
    emoji: '😼',
    description: '능글맞은 미식가 · 취향 & 날씨 밸런스',
  ),
  pickyButler(
    label: '깐깐한 집사냥',
    emoji: '🧐',
    description: '가성비 · 웨이팅 없음 · 높은 평점 최우선',
  ),
  adventurer(
    label: '모험가냥',
    emoji: '🤠',
    description: '감성 · 화끈한 맛 · 이색 메뉴 편애',
  );

  final String label;
  final String emoji;
  final String description;

  const CatPersona({
    required this.label,
    required this.emoji,
    required this.description,
  });
}

/// 저녁 시간대 + 2인 이상 모임일 때 동적으로 추가되는 반주/음주 의향 선택 카드
enum DrinkPreference {
  yesDrink(
    title: '가볍게 한잔 곁들이기',
    subtitle: '전골·구이·주점 위주로 텐션 업',
    emoji: '🍺🍶',
    cardTint: Color(0xFFFFEFE8),
  ),
  noDrink(
    title: '식사 위주로 깔끔하게',
    subtitle: '부담 없이 든든한 한 끼 집중',
    emoji: '🚫🍵',
    cardTint: Color(0xFFEAF7F6),
  );

  final String title;
  final String subtitle;
  final String emoji;
  final Color cardTint;

  const DrinkPreference({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.cardTint,
  });
}

/// 이미지 기반 인원 및 성별 구성 카드 6종
enum PartyType {
  soloMale(
    title: '혼자 야무지게 (남)',
    subtitle: '혼밥하기 딱 좋은 카운터석',
    emoji: '🎧🍜',
    badgeLabel: '혼자 남',
    cardTint: Color(0xFFFFEFE8),
    assetPath: 'assets/images/clay/party_solo_male.png',
  ),
  soloFemale(
    title: '혼자 여유롭게 (여)',
    subtitle: '깔끔하고 아늑한 1인 미식',
    emoji: '✨🥗',
    badgeLabel: '혼자 여',
    cardTint: Color(0xFFFFF3DF),
    assetPath: 'assets/images/clay/party_solo_female.png',
  ),
  coupleMF(
    title: '설레는 둘이서 (남녀)',
    subtitle: '분위기 좋은 데이트 스팟',
    emoji: '💑🕯️',
    badgeLabel: '커플 2인',
    cardTint: Color(0xFFFFEBF0),
    assetPath: 'assets/images/clay/party_couple_mf.png',
  ),
  duoSame(
    title: '단짝이랑 둘이 (2인)',
    subtitle: '수다 떨며 맛있는 거 먹기',
    emoji: '👯‍♀️🍕',
    badgeLabel: '단짝 2인',
    cardTint: Color(0xFFEAF7F6),
    assetPath: 'assets/images/clay/party_duo_same.png',
  ),
  friends34(
    title: '친구들이랑 (3~4인)',
    subtitle: '여럿이 시켜 나눠먹기 좋은 곳',
    emoji: '🍻🥘',
    badgeLabel: '친구 3~4인',
    cardTint: Color(0xFFF3EEFF),
    assetPath: 'assets/images/clay/party_friends_34.png',
  ),
  group5Plus(
    title: '왁자지껄 단체 (5인+)',
    subtitle: '넓은 자리 완비! 회식·모임',
    emoji: '🎉🥩',
    badgeLabel: '단체 5인+',
    cardTint: Color(0xFFE9F4FB),
    assetPath: 'assets/images/clay/party_group_5plus.png',
  );

  final String title;
  final String subtitle;
  final String emoji;
  final String badgeLabel;
  final Color cardTint;
  final String assetPath;

  const PartyType({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.badgeLabel,
    required this.cardTint,
    required this.assetPath,
  });

  bool get isSolo => this == PartyType.soloMale || this == PartyType.soloFemale;
}

/// 구루냥 취향 유도 질문 1: 오늘의 분위기/텐션 (2열 직사각형 카드용)
enum VibePreference {
  lively(
    title: '시끌벅적 신나게',
    subtitle: '활기찬 에너지 & 한잔 분위기',
    emoji: '🔥🍻',
    cardTint: Color(0xFFFFEFE8),
    assetPath: 'assets/images/clay/vibe_lively.png',
  ),
  cozy(
    title: '조용하고 아늑하게',
    subtitle: '도란도란 대화하기 좋은 곳',
    emoji: '🕯️☕',
    cardTint: Color(0xFFFFF4E0),
    assetPath: 'assets/images/clay/vibe_cozy.png',
  ),
  aesthetic(
    title: '감성 한 스푼 예쁜 곳',
    subtitle: '사진 찍기 좋고 인테리어 맛집',
    emoji: '📸🌷',
    cardTint: Color(0xFFFFEBF0),
    assetPath: 'assets/images/clay/vibe_aesthetic.png',
  ),
  heartyFast(
    title: '배고파! 푸짐·빠르게',
    subtitle: '기다림 적고 양으로 승부',
    emoji: '⚡🍖',
    cardTint: Color(0xFFEAF7F6),
    assetPath: 'assets/images/clay/vibe_hearty_fast.png',
  );

  final String title;
  final String subtitle;
  final String emoji;
  final Color cardTint;
  final String assetPath;

  const VibePreference({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.cardTint,
    required this.assetPath,
  });
}

/// 구루냥 취향 유도 질문 2: 지금 끌리는 맛 포인트 (2열 직사각형 카드용)
enum TastePreference {
  warmSoup(
    title: '뜨끈하고 깊은 국물',
    subtitle: '속까지 확 풀리는 전골·라멘',
    emoji: '🍲💨',
    cardTint: Color(0xFFFFEFE8),
    assetPath: 'assets/images/clay/taste_warm_soup.png',
  ),
  savoryGrilled(
    title: '고소·바삭 육즙 폭발',
    subtitle: '노릇한 구이·튀김·파전류',
    emoji: '🥩🍤',
    cardTint: Color(0xFFFFF4E0),
    assetPath: 'assets/images/clay/taste_savory_grilled.png',
  ),
  spicyKick(
    title: '스트레스 풀리는 매콤',
    subtitle: '입맛 돋우는 화끈한 감칠맛',
    emoji: '🌶️🔥',
    cardTint: Color(0xFFFFEBF0),
    assetPath: 'assets/images/clay/taste_spicy_kick.png',
  ),
  lightClean(
    title: '깔끔하고 담백한 한 끼',
    subtitle: '부담 없이 산뜻한 샐러드·소바',
    emoji: '🥗🍋',
    cardTint: Color(0xFFEAF7F6),
    assetPath: 'assets/images/clay/taste_light_clean.png',
  );

  final String title;
  final String subtitle;
  final String emoji;
  final Color cardTint;
  final String assetPath;

  const TastePreference({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.cardTint,
    required this.assetPath,
  });
}

/// 오늘의 날씨 컨텍스트 (구루냥에게 온전히 맡기기용)
enum WeatherCondition {
  rainy(
    label: '비 오는 날',
    emoji: '☔',
    headlinePrefix: '오늘은 비가 오니까',
    chipColor: AppColors.claySky,
  ),
  sunny(
    label: '화창한 날',
    emoji: '☀️',
    headlinePrefix: '오늘처럼 화창한 날엔',
    chipColor: AppColors.clayButter,
  ),
  chilly(
    label: '쌀쌀한 날',
    emoji: '❄️',
    headlinePrefix: '바람이 쌀쌀한 날엔',
    chipColor: Color(0xFF8E9AAF),
  ),
  hot(
    label: '무더운 날',
    emoji: '🌴',
    headlinePrefix: '날이 꽤 후덥지근하니까',
    chipColor: AppColors.clayOrange,
  );

  final String label;
  final String emoji;
  final String headlinePrefix;
  final Color chipColor;

  const WeatherCondition({
    required this.label,
    required this.emoji,
    required this.headlinePrefix,
    required this.chipColor,
  });
}

/// 현재 계절 컨텍스트
enum SeasonType {
  spring('봄', '🌸'),
  summer('여름', '🏖️'),
  autumn('가을', '🍂'),
  winter('겨울', '⛄');

  final String label;
  final String emoji;

  const SeasonType(this.label, this.emoji);
}
