import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Colores globales
// ─────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF00BFA6); // Teal / aqua
  static const Color secondary = Color(0xFF7C4DFF); // Violeta acento
  static const Color background = Color(0xFF0F0F1A);
  static const Color surface = Color(0xFF1B1B2F);
  static const Color border = Color(0xFF2E2E4E);
  static const Color error = Color(0xFFFF4D4D);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFFACC15);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.grey;

  static const Color levelBeginner = Color(0xFF22C55E);
  static const Color levelIntermediate = Color(0xFFFACC15);
  static const Color levelAdvanced = Color(0xFFEF4444);

  static const List<Color> calendarEventColors = [
    Color(0xFF00BFA6),
    Color(0xFF7C4DFF),
    Color(0xFF2563EB),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
  ];
}

// ─────────────────────────────────────────────
// Rutas nombradas (GoRouter)
// ─────────────────────────────────────────────
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String updatePassword = '/update-password';

  static const String studentHome = '/student';
  static const String studentCalendar = '/student/calendar';
  static const String studentClasses = '/student/classes';
  static const String studentProfile = '/student/profile';

  static const String academyDashboard = '/academy';
  static const String academyEvents = '/academy/events';
  static const String academyClasses = '/academy/classes';
  static const String academyTeachers = '/academy/teachers';
  static const String academyTickets = '/academy/tickets';
  static const String academyProfile = '/academy/profile';

  static const String organizations = '/organizations';
  static const String organizationsCreate = '/organizations/create';
  static const String organizationsDetail = '/organizations/detail';
  static const String myInvitations = '/invitations';

  static const String classList = '/classes';
  static const String classCreate = '/classes/create';
  static const String classDetail = '/classes/detail';
}

// ─────────────────────────────────────────────
// Dimensiones y durations comunes
// ─────────────────────────────────────────────
class AppSizes {
  AppSizes._();

  static const double paddingSmall = 8;
  static const double paddingMedium = 16;
  static const double paddingLarge = 24;
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 20;
  static const double radiusXl = 30;
  static const double buttonHeight = 48;
  static const double calendarHourHeight = 60.0;
  static const double calendarEventMinWidth = 100.0;
}

class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}
