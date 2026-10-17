// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

import 'app_nav_shells.dart';
import 'auth_callback_page.dart';

import 'package:academia_events/data/models/profile_model.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/providers/layout_mode_provider.dart';

// ── Auth
import 'package:academia_events/feature/auth/views/forgot_password_view.dart';
import 'package:academia_events/feature/auth/views/login_view.dart';
import 'package:academia_events/feature/auth/views/register_view.dart';
import 'package:academia_events/feature/auth/views/update_password_view.dart';

// ── Features Public / Estudiante
import 'package:academia_events/feature/public/calendar/views/calendar_view.dart';
import 'package:academia_events/feature/public/tickets/views/tickets_view.dart';
import 'package:academia_events/feature/public/classes/views/student_classes_view.dart';
import 'package:academia_events/feature/public/profile/views/profile_view.dart';
import 'package:academia_events/feature/public/profile/views/my_invitations_view.dart';
import 'package:academia_events/feature/public/tickets/views/purchase_tickets_screen.dart';

// ── Features Organization / Academia
import 'package:academia_events/feature/organization/dashboard/views/academy_dashboard_view.dart';
import 'package:academia_events/feature/organization/events/views/events_list_view.dart';
import 'package:academia_events/feature/organization/events/views/event_create_view.dart';
import 'package:academia_events/feature/organization/events/views/event_detail_view.dart';
import 'package:academia_events/feature/organization/classes/views/organization_classes_view.dart';
import 'package:academia_events/feature/organization/classes/views/class_create_view.dart';
import 'package:academia_events/feature/organization/members/views/organization_members_view.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthStateNotifier(ref);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: AppRoutes.studentHome,
    redirect: (context, state) => _handleRedirect(ref, state),
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginView()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterView(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordView(),
      ),
      GoRoute(
        path: AppRoutes.updatePassword,
        builder: (_, _) => const UpdatePasswordView(),
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (_, _) => const AuthCallbackPage(),
      ),

      // ── Acciones Directas e Invitaciones ─────────────────────────────
      GoRoute(
        path: AppRoutes.myInvitations,
        builder: (_, _) => const MyInvitationsView(),
      ),
      GoRoute(
        path: AppRoutes.organizationsCreate,
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('Crear Organización'))),
      ),
      GoRoute(
        path: AppRoutes.classCreate,
        builder: (_, _) => const ClassCreateView(),
      ),
      GoRoute(
        path: AppRoutes.eventCreate,
        builder: (_, _) => const EventCreateView(),
      ),
      GoRoute(
        path: AppRoutes.eventDetailPattern,
        builder: (context, state) => EventDetailView(
          eventId: state.pathParameters['id'] ?? state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: '/events/:id/purchase',
        builder: (context, state) =>
            PurchaseTicketsScreen(eventId: state.pathParameters['id'] ?? ''),
      ),

      // ── Shell Estudiante (4 Pestañas) ─────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => StudentShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentHome,
                builder: (_, _) => const CalendarView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/tickets',
                builder: (_, _) => const TicketsView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentClasses,
                builder: (_, _) => const StudentClassesView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentProfile,
                builder: (_, _) => const ProfileView(),
              ),
            ],
          ),
        ],
      ),

      // ── Shell Academia (5 Pestañas) ───────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AcademyShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academyDashboard,
                builder: (_, _) => const AcademyDashboardView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academyEvents,
                builder: (_, _) => const EventsListView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academyClasses,
                builder: (_, _) => const OrganizationClassesView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academyTeachers,
                builder: (_, _) => const OrganizationMembersView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academyProfile,
                builder: (_, _) => const ProfileView(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: context.scaffoldBg,
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

  final isPasswordRecovery =
      authState.value?.event == sb.AuthChangeEvent.passwordRecovery;

  final loc = state.matchedLocation;
  final onAuthRoute =
      loc.startsWith('/login') ||
      loc.startsWith('/register') ||
      loc.startsWith('/forgot-password');

  if (isPasswordRecovery) {
    return loc == AppRoutes.updatePassword ? null : AppRoutes.updatePassword;
  }

  final isAuthenticated =
      ref.read(authSessionProvider) != null ||
      ref.read(authRepositoryProvider).isAuthenticated ||
      authState.value?.session != null;
  if (!isAuthenticated) {
    return onAuthRoute ? null : AppRoutes.login;
  }

  final mode = ref.read(effectiveLayoutModeProvider);

  // 2. Si ya está autenticado pero sigue en login/register, enviarlo al home
  if (onAuthRoute) {
    final role = ref.read(currentUserRoleProvider).whenOrNull(data: (r) => r);
    if (role == UserRole.platformAdmin) return AppRoutes.platformAdmin;
    return mode == AppLayoutMode.academy
        ? AppRoutes.academyDashboard
        : AppRoutes.studentHome;
  }

  // Esperar el rol antes de aplicar redirecciones dependientes de permisos.
  final roleAsync = ref.read(currentUserRoleProvider);
  if (roleAsync.isLoading) return null;

  final role = roleAsync.whenOrNull(data: (r) => r);
  if (loc.startsWith(AppRoutes.platformAdmin) &&
      role != UserRole.platformAdmin) {
    return AppRoutes.studentHome;
  }
  if (role == UserRole.platformAdmin &&
      (loc.startsWith('/student') || loc.startsWith('/academy'))) {
    return AppRoutes.platformAdmin;
  }

  final onStudentShell = loc.startsWith('/student');
  final onAcademyShell = loc.startsWith('/academy');

  if (mode == AppLayoutMode.academy && onStudentShell) {
    return loc == AppRoutes.studentProfile
        ? AppRoutes.academyProfile
        : AppRoutes.academyDashboard;
  }
  if (mode == AppLayoutMode.student && onAcademyShell) {
    return loc == AppRoutes.academyProfile
        ? AppRoutes.studentProfile
        : AppRoutes.studentHome;
  }

  return null;
}

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(authSessionProvider, (_, _) => notifyListeners());
    ref.listen(currentUserRoleProvider, (_, _) => notifyListeners());
    ref.listen(layoutModeProvider, (_, _) => notifyListeners());
  }
}
