// lib/core/constants/app_constants.dart

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
  static const String academyCheckin = '/academy/checkin';
  static const String studentProfile = '/student/profile';
  static const String myClassDetail = '/mi-clase';
  static const String myClassDetailPattern = '/mi-clase/:id';
  static const String enrollClassDetail = '/inscribir';
  static const String enrollClassDetailPattern = '/inscribir/:id';

  static const String academyDashboard = '/academy';
  static const String academyEvents = '/academy/events';
  static const String academyClasses = '/academy/classes';
  static const String academyTeachers = '/academy/teachers';
  static const String academyTickets = '/academy/tickets';
  static const String academyProfile = '/academy/profile';
  static const String platformAdmin = '/admin';

  static const String organizations = '/organizations';
  static const String organizationsCreate = '/organizations/create';
  static const String organizationsDetail = '/organizations/detail';
  static const String organizationsDetailPattern = '/organizations/detail/:id';
  static const String myInvitations = '/invitations';

  static const String classList = '/classes';
  static const String classCreate = '/classes/create';
  static const String classDetail = '/classes/detail';
  static const String classDetailPattern = '/classes/detail/:id';

  static const String eventsList = '/events';
  static const String eventCreate = '/events/create';
  static const String eventDetail = '/events/detail';
  static const String eventDetailPattern = '/events/detail/:id';

  static const String publicEvents = '/eventos';
  static const String publicEventDetail = '/eventos/detalle/:id';
  static const String publicEventDetailBase = '/eventos/detalle';
  static const String publicCalendar = '/calendario';

  static const String organizationPublicDetail = '/organizaciones/:id';
  static const String organizationPublicDetailBase = '/organizaciones';
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
  static const double calendarHourHeight = 70.0;
  static const double calendarEventMinWidth = 100.0;
}

class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}