// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark
  static const darkBackground = Color(0xFF0F0F1A);
  static const darkSurface = Color(0xFF1B1B2F);
  static const darkBorder = Color(0xFF2E2E4E);
  static const darkText = Color(0xFFF8FAFC);
  static const darkMuted = Color(0xFFB6B8C5);

  // Light
  static const lightText = Color(0xFF1A1A2E);
  static const lightMuted = Color(0xFF6B7280);

  // Marca principal
  static const primary = Color(0xFF6C5CE7);
  static const secondary = Color(0xFF00E5D4);

  // Estados semánticos
  static const error = Color(0xFFE63946);
  static const success = Color(0xFF2ECC71);
  static const warning = Color(0xFFFFA726);

  // Superficies, fondos y bordes
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE0E0E0);

  // Elementos fijos sobre fondos de color
  static const onPrimary = Colors.white;
  static const onSecondary = Colors.white;
  static const onError = Colors.white;

  // Niveles
  static const levelBeginner = Color(0xFF22C55E);
  static const levelIntermediate = Color(0xFFFACC15);
  static const levelAdvanced = Color(0xFFEF4444);

  // Calendario
  static const List<Color> calendarEventColors = [
    Color(0xFF6C5CE7),
    Color(0xFF00E5D4),
    Color(0xFF2563EB),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
  ];

  // Paleta de organizaciones determinística por id
  static const List<Color> organizationColors = [
    Color(0xFFD32F2F),
    Color(0xFFBF360C),
    Color(0xFFFF6F00),
    Color(0xFF388E3C),
    Color(0xFF00796B),
    Color(0xFF0097A7),
    Color(0xFF0277BD),
    Color(0xFF1976D2),
    Color(0xFF303F9F),
    Color(0xFF5E35B1),
    Color(0xFFC2185B),
    Color(0xFF6A1B9A),
  ];

  static Color colorForOrganization(String? organizationId) {
    if (organizationId == null || organizationId.isEmpty) return primary;
    return organizationColors[organizationId.hashCode.abs() %
        organizationColors.length];
  }
}
