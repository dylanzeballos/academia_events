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
}
