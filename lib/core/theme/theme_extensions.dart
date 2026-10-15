// lib/core/theme/theme_extensions.dart
import 'package:flutter/material.dart';

extension ThemeExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  bool get isDark => theme.brightness == Brightness.dark;

  // Fondos y bordes reactivos
  Color get scaffoldBg => theme.scaffoldBackgroundColor;
  Color get cardBg => theme.cardColor;
  Color get divider => theme.dividerColor;
  Color get borderColor => colorScheme.outline;

  // Textos reactivos
  Color get textOnBg => colorScheme.onSurface;
  Color get textMuted => colorScheme.onSurfaceVariant;
  Color get primaryColor => colorScheme.primary;
}