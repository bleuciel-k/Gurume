/// Google Maps 및 Firebase 연동 환경설정.
///
/// 실행 시 `--dart-define=GOOGLE_MAPS_API_KEY=...`,
/// `--dart-define=FIREBASE_API_KEY=...`, `--dart-define=FIREBASE_PROJECT_ID=...`
/// 등으로 주입하거나, 웹 실행 중 앱 내 설정 모달을 통해 런타임으로 연결할 수 있습니다.
abstract final class ApiConfig {
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );

  static const String firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '',
  );

  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );

  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static const String firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: '',
  );

  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );

  /// Standard 에디션 기본 DB는 '(default)', Enterprise/네임드 DB는 해당 DB ID 사용
  static const String firestoreDatabaseId = String.fromEnvironment(
    'FIRESTORE_DATABASE_ID',
    defaultValue: '(default)',
  );

  static bool get hasCompileTimeGoogleMapsKey => googleMapsApiKey.isNotEmpty;

  static bool get hasCompileTimeFirebaseConfig =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
