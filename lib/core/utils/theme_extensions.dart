import 'package:flutter/material.dart';

extension ThemeExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  bool get isDarkMode => theme.brightness == Brightness.dark;

  Color get scaffoldBg => theme.scaffoldBackgroundColor;
  Color get cardBg => theme.cardColor;
  Color get inputBg => theme.cardColor;
  Color get divider => theme.dividerColor;

  Color get textOnBg => colorScheme.onSurface;
  Color get textMuted => colorScheme.onSurfaceVariant;

  Color get surfaceHeader =>
      isDarkMode ? const Color(0xFF171B26) : Colors.white;

  Color get surfaceDeep =>
      isDarkMode ? const Color(0xFF141824) : const Color(0xFFF1F3F7);

  Color get surfaceInput =>
      isDarkMode ? const Color(0xFF181D2D) : Colors.white;

  Color get borderSubtle =>
      isDarkMode ? const Color(0xFF222738) : const Color(0xFFDDDDDD);
}