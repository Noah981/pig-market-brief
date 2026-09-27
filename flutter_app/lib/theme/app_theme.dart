import 'package:flutter/material.dart';

abstract final class AppColors {
  static const coral = Color(0xFFF72F62);
  static const lightCoral = Color(0xFFFFE4EC);
  static const background = Color(0xFFFFF8F9);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF111111);
  static const secondary = Color(0xFF777B85);
  static const blue = Color(0xFF1677E8);
  static const lightBlue = Color(0xFFEDF7FF);
  static const purple = Color(0xFFF1E9FF);
  static const divider = Color(0xFFEEEEF2);
  static const green = Color(0xFF25A56A);
}

abstract final class AppSpacing {
  static const page = 12.0;
  static const section = 10.0;
  static const radius = 20.0;
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.coral),
        fontFamily: 'NotoSansKR',
        textTheme: Typography.material2021(platform: TargetPlatform.android).black.apply(
          fontFamily: 'NotoSansKR',
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
        splashFactory: NoSplash.splashFactory,
      );
}

BoxDecoration appCard({Color color = AppColors.card, double radius = AppSpacing.radius}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 14, offset: Offset(0, 4))],
    );
