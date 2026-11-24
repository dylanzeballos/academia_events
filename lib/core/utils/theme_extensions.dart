import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

extension ThemeExtensions on BuildContext {
  Color get scaffoldBg => Theme.of(this).scaffoldBackgroundColor;

  Color get cardBg => Theme.of(this).cardColor;

  Color get inputBg =>
      Theme.of(this).inputDecorationTheme.fillColor ??
      Theme.of(this).colorScheme.surface;

  Color get divider => Theme.of(this).dividerColor;

  Color get textOnBg => Theme.of(this).colorScheme.onSurface;

  Color get textMuted => Theme.of(this).colorScheme.onSurfaceVariant;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Superficie de cabeceras (barras, encabezados de tabla).
  Color get surfaceHeader =>
      isDarkMode ? AppColors.darkSurface : AppColors.surface;

  /// Superficie base algo más oscura/clara que el fondo.
  Color get surfaceDeep =>
      isDarkMode ? AppColors.darkBackground : AppColors.background;

  /// Relleno de campos de texto.
  Color get surfaceInput =>
      Theme.of(this).inputDecorationTheme.fillColor ??
      Theme.of(this).colorScheme.surface;

  /// Bordes sutiles para separadores y contornos.
  Color get borderSubtle => Theme.of(this).colorScheme.outline;
}
