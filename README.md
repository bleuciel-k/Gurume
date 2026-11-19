# オレグル (Oreguru)

Android · iOS · Web을 지원하는 **클레이모피즘(Claymorphism)** 기반 맛집 탐색 및 **턱시도 고양이 '구루냥'** 추천 모바일 앱입니다.

## 주요 기능

- **클레이모피즘 디자인 시스템 (`#F1E6D2` / `#FC7D4E` / `#2D241E`)**
  - Figma Claymorphism UI 기반 다중 Drop Shadow + Inset Shadow(`ClayInnerShadowPainter`) 및 각진 점토 모서리(`12px`~`26px`)를 iOS/Android/Web에서 동일하게 렌더링합니다.
- **2D 커스텀 맵 + 3D 클레이 마커 비트맵 캐시 (`MarkerBitmapCache`)**
  - Google Places API 클라이언트 호출 없이 자체 캐시/Firestore 데이터만으로 저채도 2D 지도 위에 3D 클레이 건물 마커(`BitmapDescriptor.bytes`)를 렌더링합니다.
- **가게·메뉴 실시간 검색 & 원탭 필터**
  - 상단 실시간 검색바 및 4종의 원탭 상황별 필터(`지금 영업중`, `혼밥 가능`, `웨이팅 없음`, `내 주변 500m`).
  - 마커 클릭 시 바텀 시트에서 `[🛒 후보 장바구니 담기]` 지원 (담기 전엔 하단 시야 100% 확보, 담기 후 우측 1열 세로 장바구니 도크 노출).
- **턱시도 고양이 '구루냥' 2-Track 결정 모달**
  - 2열 대형 직사각형 인원/성별 카드 선택.
  - **트랙 A (취향 유도 Q&A):** 분위기·맛 포인트 2열 선택지 기반 맞춤 추천.
  - **트랙 B (온전히 맡기기):** 백그라운드 실시간 날씨·계절(UI 비노출)과 대표 메뉴를 조합해 입맛 다시며 추천(근거 부족 시 랜덤 폴백).
  - 거절(`여긴 안 땡겨!`) 시 해당 가게를 재추천 목록에서 영구 제외.
- **Cloud Firestore 실연동 & 증분 동기화 (`Delta Sync`)**
  - 로컬 영구 캐시 우선 로드 후 `updatedAt > lastSyncMillis` 변경분만 병합해 읽기 비용을 최소화합니다.
  - [firestore.rules](firestore.rules) 및 [firestore.indexes.json](firestore.indexes.json) 포함.

## 실행 방법

```bash
flutter pub get
flutter test
flutter run -d chrome
```

### API 키 컴파일 타임 주입 (선택)

```bash
flutter run -d chrome \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_MAPS_KEY \
  --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY \
  --dart-define=FIREBASE_APP_ID=YOUR_FIREBASE_APP_ID \
  --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID
```

## 브라우저 즉시 미리보기

Flutter 없이도 [preview/index.html](preview/index.html)을 브라우저에서 열어 인터랙티브 프로토타입을 확인할 수 있습니다.
