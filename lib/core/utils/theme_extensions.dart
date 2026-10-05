import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

extension ThemeExtensions on BuildContext {
  Color get scaffoldBg =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.background
          : const Color(0xFFF8F9FA);

  Color get cardBg =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.surface
          : Colors.white;

  Color get inputBg =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.surface
          : Colors.white;

  Color get divider =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.border
          : const Color(0xFFE0E0E0);

  Color get textOnBg =>
      Theme.of(this).brightness == Brightness.dark
          ? Colors.white
          : const Color(0xFF1A1A2E);

  Color get textMuted =>
      Theme.of(this).brightness == Brightness.dark
          ? Colors.grey
          : const Color(0xFF6B7280);

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Superficie de cabeceras (barras, encabezados de tabla).
  Color get surfaceHeader =>
      isDarkMode ? const Color(0xFF171B26) : Colors.white;

  /// Superficie base algo más oscura/clara que el fondo.
  Color get surfaceDeep =>
      isDarkMode ? const Color(0xFF141824) : const Color(0xFFF1F3F7);

  /// Relleno de campos de texto.
  Color get surfaceInput =>
      isDarkMode ? const Color(0xFF181D2D) : Colors.white;

  /// Bordes sutiles para separadores y contornos.
  Color get borderSubtle =>
      isDarkMode ? const Color(0xFF222738) : const Color(0xFFDDDDDD);
}
