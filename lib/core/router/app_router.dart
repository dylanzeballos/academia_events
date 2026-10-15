import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../constants/app_constants.dart';
import '../theme/theme_extensions.dart';
import 'app_nav_shells.dart';
import 'auth_callback_page.dart';

import '../../data/models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/layout_mode_provider.dart';

// Vistas de Autenticación
import '../../features/auth/views/forgot_password_view.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/register_view.dart';
import '../../features/auth/views/update_password_view.dart';

// Vistas Principales y Estudiante
import '../../features/calendar/week_calendar_view.dart';
import '../../features/profile/profile_view.dart';
import '../../features/tickets/views/student_tickets_view.dart';
import '../../features/enrollment/views/my_classes_view.dart';
import '../../features/enrollment/views/my_class_detail_view.dart';
import '../../features/enrollment/views/class_enroll_detail_view.dart';

// Vistas de Academia y Admin
import '../../feature/organization/dashboard/views/academy_dashboard_view.dart';
import '../../features/academy/views/academy_events_view.dart';
import '../../features/academy/views/academy_classes_view.dart';
import '../../features/academy/views/academy_teachers_view.dart';
import '../../features/checkin/views/checkin_screen.dart';
import '../../features/admin/views/admin_dashboard_view.dart';

// Vistas de Organizaciones, Clases y Eventos
import '../../features/organization/views/organization_list_view.dart';
import '../../features/organization/views/organization_detail_view.dart';
import '../../features/organization/views/organization_create_view.dart';
import '../../features/organization/views/my_invitations_view.dart';
import '../../features/classes/views/class_list_view.dart';
import '../../features/classes/views/class_create_view.dart';
import '../../features/classes/views/class_detail_view.dart';
import '../../features/events/views/events_list_view.dart';
import '../../features/events/views/event_create_view.dart';
import '../../features/events/views/event_detail_view.dart';
import '../../features/public/views/public_events_view.dart';
import '../../features/public/views/public_event_detail_view.dart';
import '../../features/public/views/organization_detail_view.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthStateNotifier(ref);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: AppRoutes.studentHome,
    redirect: (context, state) => _handleRedirect(ref, state),
    routes: [
      // ── Auth & Admin ──────────────────────────────────────────────────
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginView()),
      GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterView()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (_, _) => const ForgotPasswordView()),
      GoRoute(path: AppRoutes.updatePassword, builder: (_, _) => const UpdatePasswordView()),
      GoRoute(path: AppRoutes.platformAdmin, builder: (_, _) => const AdminDashboardView()),
      GoRoute(path: '/auth/callback', builder: (_, _) => const AuthCallbackPage()),

      // ── Organizaciones ────────────────────────────────────────────────
      GoRoute(path: AppRoutes.organizations, builder: (_, _) => const OrganizationListView()),
      GoRoute(path: AppRoutes.organizationsCreate, builder: (_, _) => const OrganizationCreateView()),
      GoRoute(
        path: AppRoutes.organizationsDetailPattern,
        builder: (context, state) => OrganizationDetailView(
          organizationId: state.pathParameters['id'],
        ),
      ),
      GoRoute(path: AppRoutes.myInvitations, builder: (_, _) => const MyInvitationsView()),

      // ── Clases ────────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.classList, builder: (_, _) => const ClassListView()),
      GoRoute(path: AppRoutes.classCreate, builder: (_, _) => const ClassCreateView()),
      GoRoute(
        path: AppRoutes.classDetailPattern,
        builder: (context, state) => ClassDetailView(
          classId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.myClassDetailPattern,
        builder: (context, state) => MyClassDetailView(
          enrollmentId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.enrollClassDetailPattern,
        builder: (context, state) => ClassEnrollDetailView(
          classId: state.pathParameters['id'],
        ),
      ),

      // ── Eventos ───────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.eventsList, builder: (_, _) => const EventsListView()),
      GoRoute(path: AppRoutes.eventCreate, builder: (_, _) => const EventCreateView()),
      GoRoute(
        path: AppRoutes.eventDetailPattern,
        builder: (context, state) => EventDetailView(
          eventId: state.pathParameters['id'] ?? state.extra as String? ?? '',
        ),
      ),

      // ── Públicas ──────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.publicEvents, builder: (_, _) => const PublicEventsView()),
      GoRoute(
        path: AppRoutes.publicEventDetail,
        builder: (context, state) => PublicEventDetailView(
          eventId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.organizationPublicDetail,
        builder: (context, state) => PublicOrganizationDetailView(
          organizationId: state.pathParameters['id'] ?? '',
          organizationName: state.extra as String?,
        ),
      ),
      GoRoute(path: AppRoutes.academyCheckin, builder: (_, _) => const CheckinScreen()),

      // ── Shell Estudiante ──────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => StudentShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.studentHome, builder: (_, _) => const WeekCalendarView()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/student/tickets', builder: (_, _) => const StudentTicketsView()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.studentClasses, builder: (_, _) => const MyClassesView()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.studentProfile, builder: (_, _) => const ProfileView()),
          ]),
        ],
      ),

      // ── Shell Academia ────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AcademyShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.academyDashboard, builder: (_, _) => const AcademyDashboardView()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.academyEvents, builder: (_, _) => const AcademyEventsView()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.academyClasses, builder: (_, _) => const AcademyClassesView()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.academyTeachers, builder: (_, _) => const AcademyTeachersView()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.academyProfile, builder: (_, _) => const ProfileView()),
          ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Ruta no encontrada: ${state.error}',
          style: TextStyle(color: context.textMuted),
        ),
      ),
    ),
  );
});

String? _handleRedirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authStateProvider);
  if (authState.isLoading) return null;

  final isAuthenticated = ref.read(authRepositoryProvider).isAuthenticated;
  final isPasswordRecovery = authState.value?.event == sb.AuthChangeEvent.passwordRecovery;

  final onAuthRoute = state.matchedLocation.startsWith('/login') ||
      state.matchedLocation.startsWith('/register') ||
      state.matchedLocation.startsWith('/forgot-password');

  if (isPasswordRecovery) {
    return state.matchedLocation == AppRoutes.updatePassword ? null : AppRoutes.updatePassword;
  }

  if (!isAuthenticated) {
    return onAuthRoute ? null : AppRoutes.login;
  }

  final roleAsync = ref.read(currentUserRoleProvider);
  if (roleAsync.isLoading) return null;

  final role = roleAsync.whenOrNull(data: (r) => r);
  final mode = ref.read(effectiveLayoutModeProvider);

  if (onAuthRoute) {
    if (role == UserRole.platformAdmin) return AppRoutes.platformAdmin;
    return mode == AppLayoutMode.academy ? AppRoutes.academyDashboard : AppRoutes.studentHome;
  }

  if (state.matchedLocation.startsWith(AppRoutes.platformAdmin) && role != UserRole.platformAdmin) {
    return AppRoutes.studentHome;
  }

  if (role == UserRole.platformAdmin &&
      (state.matchedLocation.startsWith('/student') || state.matchedLocation.startsWith('/academy'))) {
    return AppRoutes.platformAdmin;
  }

  final onStudentShell = state.matchedLocation.startsWith('/student');
  final onAcademyShell = state.matchedLocation.startsWith('/academy');

  if (mode == AppLayoutMode.academy && onStudentShell) {
    return AppRoutes.academyDashboard;
  }
  if (mode == AppLayoutMode.student && onAcademyShell) {
    return AppRoutes.studentHome;
  }

  return null;
}

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentUserRoleProvider, (_, _) => notifyListeners());
    ref.listen(layoutModeProvider, (_, _) => notifyListeners());
  }
}