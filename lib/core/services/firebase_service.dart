import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/core/constants/api_config.dart';
import 'package:oreguru/core/services/maps_platform_bridge.dart';

class FirebaseRuntimeConfig {
  final String apiKey;
  final String appId;
  final String projectId;
  final String messagingSenderId;
  final String authDomain;
  final String storageBucket;
  final String databaseId;

  const FirebaseRuntimeConfig({
    required this.apiKey,
    required this.appId,
    required this.projectId,
    this.messagingSenderId = '',
    this.authDomain = '',
    this.storageBucket = '',
    this.databaseId = '(default)',
  });

  bool get isValid =>
      apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty;

  FirebaseOptions toFirebaseOptions() {
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId:
          messagingSenderId.isNotEmpty ? messagingSenderId : '000000000000',
      projectId: projectId,
      authDomain: authDomain.isNotEmpty
          ? authDomain
          : '$projectId.firebaseapp.com',
      storageBucket: storageBucket.isNotEmpty
          ? storageBucket
          : '$projectId.firebasestorage.app',
    );
  }

  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'appId': appId,
        'projectId': projectId,
        'messagingSenderId': messagingSenderId,
        'authDomain': authDomain,
        'storageBucket': storageBucket,
        'databaseId': databaseId,
      };

  factory FirebaseRuntimeConfig.fromJson(Map<String, dynamic> json) {
    return FirebaseRuntimeConfig(
      apiKey: json['apiKey'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      messagingSenderId: json['messagingSenderId'] as String? ?? '',
      authDomain: json['authDomain'] as String? ?? '',
      storageBucket: json['storageBucket'] as String? ?? '',
      databaseId: (json['databaseId'] as String?)?.isNotEmpty == true
          ? json['databaseId'] as String
          : '(default)',
    );
  }
}

/// Firebase Core 초기화 및 Cloud Firestore(Standard / Enterprise databaseId) 관리 서비스.
/// - 설정값이 없으면 앱 시작을 막지 않고 로컬 캐시 모드로 동작합니다.
/// - 설정값이 있으면 오프라인 퍼시스턴스를 켠 채 Firestore 인스턴스를 제공합니다.
class FirebaseService {
  static const String _storedConfigKey = 'oreguru_firebase_config_v1';

  FirebaseApp? _app;
  FirebaseFirestore? _firestore;
  String _activeProjectId = '';
  String _activeDatabaseId = '(default)';

  bool get isConnected => _firestore != null;
  String get activeProjectId => _activeProjectId;
  String get activeDatabaseId => _activeDatabaseId;
  FirebaseFirestore? get firestore => _firestore;

  /// 앱 부팅 시 `--dart-define` 또는 로컬에 저장된 Firebase 설정으로 자동 초기화
  Future<bool> initializeIfConfigured() async {
    if (_firestore != null) return true;

    FirebaseRuntimeConfig? config;
    if (ApiConfig.hasCompileTimeFirebaseConfig) {
      config = const FirebaseRuntimeConfig(
        apiKey: ApiConfig.firebaseApiKey,
        appId: ApiConfig.firebaseAppId,
        projectId: ApiConfig.firebaseProjectId,
        messagingSenderId: ApiConfig.firebaseMessagingSenderId,
        authDomain: ApiConfig.firebaseAuthDomain,
        storageBucket: ApiConfig.firebaseStorageBucket,
        databaseId: ApiConfig.firestoreDatabaseId,
      );
    } else {
      final raw = await readPersistentValue(_storedConfigKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final parsed = FirebaseRuntimeConfig.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          if (parsed.isValid) {
            config = parsed;
          }
        } catch (_) {
          // 손상된 로컬 설정 무시
        }
      }
    }

    if (config == null || !config.isValid) {
      return false;
    }

    return connectRuntime(config, persistConfig: false);
  }

  /// 런타임에 Firebase 프로젝트 설정을 받아 연결하고 영구 저장
  Future<bool> connectRuntime(
    FirebaseRuntimeConfig config, {
    bool persistConfig = true,
  }) async {
    if (!config.isValid) return false;

    try {
      final appName = 'oreguru_${config.projectId}';
      FirebaseApp app;
      try {
        app = Firebase.app(appName);
      } catch (_) {
        app = await Firebase.initializeApp(
          name: appName,
          options: config.toFirebaseOptions(),
        );
      }

      final dbId =
          config.databaseId.trim().isEmpty ? '(default)' : config.databaseId.trim();

      final db = dbId == '(default)'
          ? FirebaseFirestore.instanceFor(app: app)
          : FirebaseFirestore.instanceFor(app: app, databaseId: dbId);

      db.settings = const Settings(persistenceEnabled: true);

      _app = app;
      _firestore = db;
      _activeProjectId = config.projectId;
      _activeDatabaseId = dbId;

      if (persistConfig) {
        await writePersistentValue(
          _storedConfigKey,
          jsonEncode(config.toJson()),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnectRuntime() async {
    _firestore = null;
    _app = null;
    _activeProjectId = '';
    _activeDatabaseId = '(default)';
    await removePersistentValue(_storedConfigKey);
  }

  FirebaseApp? get app => _app;
}

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});
