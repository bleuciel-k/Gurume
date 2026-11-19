import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:oreguru/core/constants/app_colors.dart';
import 'package:oreguru/features/map_explorer/presentation/map_explorer_screen.dart';

/// Chrome 웹 환경에서도 마우스 드래그로 가로 필터 스크롤이 가능하도록 확장
class _OreguruScrollBehavior extends MaterialScrollBehavior {
  const _OreguruScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

/// オレグル(Oreguru) 루트 애플리케이션 위젯
class OreguruApp extends StatelessWidget {
  const OreguruApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'オレグル (Oreguru)',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _OreguruScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgIvory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.clayOrange,
          surface: AppColors.bgIvory,
          primary: AppColors.clayOrange,
          onPrimary: Colors.white,
          onSurface: AppColors.textEspresso,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            color: AppColors.textEspresso,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          titleMedium: TextStyle(
            color: AppColors.textEspresso,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          bodyMedium: TextStyle(
            color: AppColors.textTaupe,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const MapExplorerScreen(),
    );
  }
}
