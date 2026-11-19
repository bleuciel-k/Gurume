import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oreguru/app.dart';
import 'package:oreguru/core/services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 상태바와 내비게이션 바를 따뜻한 아이보리 톤에 맞춰 세팅
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF1E6D2),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Firebase 설정(`--dart-define` 또는 로컬 저장 설정)이 있으면 자동 초기화,
  // 미설정 시에도 로컬 캐시 모드로 즉시 시작합니다.
  final firebaseService = FirebaseService();
  await firebaseService.initializeIfConfigured();

  runApp(
    ProviderScope(
      overrides: [
        firebaseServiceProvider.overrideWithValue(firebaseService),
      ],
      child: const OreguruApp(),
    ),
  );
}
