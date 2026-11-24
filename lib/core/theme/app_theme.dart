import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    },
  );

  // Solo cambian los colores; lo demás se define una vez.
  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffold,
  }) {
    final radius = BorderRadius.circular(AppSizes.radiusMedium);

    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      cardColor: scheme.surface,
      dividerColor: scheme.outline,
      pageTransitionsTheme: _pageTransitions,
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: outline(scheme.outline),
        enabledBorder: outline(scheme.outline),
        focusedBorder: outline(scheme.primary, 2),
        errorBorder: outline(scheme.error),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          side: BorderSide(color: scheme.outline),
        ),
      ),
    );
  }

  static ThemeData get dark => _build(
    scaffold: AppColors.darkBackground,
    scheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.darkSurface,
      error: AppColors.error,
      onPrimary: AppColors.onPrimary,
      onSecondary: AppColors.onSecondary,
      onSurface: AppColors.darkText,
      onSurfaceVariant: AppColors.darkMuted,
      outline: AppColors.darkBorder,
    ),
  );

  static ThemeData get light => _build(
    scaffold: AppColors.background,
    scheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: AppColors.onPrimary,
      onSecondary: AppColors.onSecondary,
      onSurface: AppColors.lightText,
      onSurfaceVariant: AppColors.lightMuted,
      outline: AppColors.border,
    ),
  );
}
