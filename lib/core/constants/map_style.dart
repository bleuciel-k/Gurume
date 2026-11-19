/// Google Maps Platform Mobile SDK용 2D 커스텀 맵 스타일 JSON.
/// - 불필요한 기본 상업 POI(병원, 편의점, 타 음식점 핀 등)를 모두 숨겨
///   등록된 맛집의 3D 클레이 마커만 시선을 사로잡도록 설계.
/// - 전체 톤을 따뜻한 아이보리/샌드 계열(#F1E6D2 ~ #E6D8BE)의 저채도 2D로 맞춤.
const String kOreguruMapStyleJson = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#EDE0C8" }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#7D6B5F" }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#F1E6D2" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#E5D6BC" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#DAC9AB" }
    ]
  },
  {
    "featureType": "poi",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      { "visibility": "on" },
      { "color": "#DCE5C9" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      { "color": "#FAF3E6" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#DFD0B5" }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#7E6D62" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      { "color": "#FADFC8" }
    ]
  },
  {
    "featureType": "transit",
    "stylers": [
      { "visibility": "simplified" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#D4E4E9" }
    ]
  }
]
''';
