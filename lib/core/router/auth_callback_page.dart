// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/data/models/profile_model.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/providers/layout_mode_provider.dart';

import 'app_nav_shells.dart';

// ── Rutas exactas a las vistas del sistema anterior
import '../../features/auth/views/forgot_password_view.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/register_view.dart';
import '../../features/auth/views/update_password_view.dart';
import '../../features/calendar/week_calendar_view.dart';
import '../../features/profile/profile_view.dart';
import '../../features/organization/views/organization_list_view.dart';
import '../../features/organization/views/organization_detail_view.dart';
import '../../features/organization/views/organization_create_view.dart';
import '../../features/organization/views/my_invitations_view.dart';

import '../../features/academy/views/academy_dashboard_view.dart';
import '../../features/academy/views/academy_events_view.dart';
import '../../features/academy/views/academy_classes_view.dart';
import '../../features/academy/views/academy_teachers_view.dart';

import '../../features/classes/views/class_list_view.dart';
import '../../features/classes/views/class_create_view.dart';
import '../../features/classes/views/class_detail_view.dart';
import '../../features/enrollment/views/my_classes_view.dart';
import '../../features/enrollment/views/my_class_detail_view.dart';
import '../../features/enrollment/views/class_enroll_detail_view.dart';

import '../../features/events/views/events_list_view.dart';
import '../../features/events/views/event_create_view.dart';
import '../../features/events/views/event_detail_view.dart';

import '../../features/public/views/public_events_view.dart';
import '../../features/public/views/public_event_detail_view.dart';
import '../../features/public/views/organization_detail_view.dart';

import '../../features/tickets/views/student_tickets_view.dart';
import '../../features/checkin/views/checkin_screen.dart';
import '../../features/admin/views/admin_dashboard_view.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthStateNotifier(ref);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: AppRoutes.studentHome,
    redirect: (context, state) => _handleRedirect(ref, state),
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginView()),
      GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterView()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (_, _) => const ForgotPasswordView()),
      GoRoute(path: AppRoutes.updatePassword, builder: (_, _) => const UpdatePasswordView()),
      GoRoute(path: AppRoutes.platformAdmin, builder: (_, _) => const AdminDashboardView()),

      // Callback OAuth (Google Login)
      GoRoute(
        path: '/auth/callback',
        builder: (_, _) => const _AuthCallbackPage(),
      ),

      // Organizaciones
      GoRoute(
        path: AppRoutes.organizations,
        builder: (_, _) => const OrganizationListView(),
      ),
      GoRoute(
        path: AppRoutes.organizationsCreate,
        builder: (_, _) => const OrganizationCreateView(),
      ),
      GoRoute(
        path: AppRoutes.organizationsDetailPattern,
        builder: (context, state) => OrganizationDetailView(
          organizationId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.myInvitations,
        builder: (_, _) => const MyInvitationsView(),
      ),

      // Clases
      GoRoute(
        path: AppRoutes.classList,
        builder: (_, _) => const ClassListView(),
      ),
      GoRoute(
        path: AppRoutes.classCreate,
        builder: (_, _) => const ClassCreateView(),
      ),
      GoRoute(
        path: AppRoutes.classDetailPattern,
        builder: (context, state) => ClassDetailView(
          classId: state.pathParameters['id'],
        ),
      ),

      // Eventos
      GoRoute(
        path: AppRoutes.eventsList,
        builder: (_, _) => const EventsListView(),
      ),
      GoRoute(
        path: AppRoutes.eventCreate,
        builder: (_, _) => const EventCreateView(),
      ),
      GoRoute(
        path: AppRoutes.eventDetailPattern,
        builder: (context, state) {
          final eventId = state.pathParameters['id'] ?? state.extra as String? ?? '';
          return EventDetailView(eventId: eventId);
        },
      ),

      // Public event discovery
      GoRoute(
        path: AppRoutes.publicEvents,
        builder: (_, _) => const PublicEventsView(),
      ),
      GoRoute(
        path: AppRoutes.publicEventDetail,
        builder: (context, state) {
          final eventId = state.pathParameters['id'] ?? '';
          return PublicEventDetailView(eventId: eventId);
        },
      ),
      GoRoute(
        path: AppRoutes.organizationPublicDetail,
        builder: (context, state) {
          final organizationId = state.pathParameters['id'] ?? '';
          return PublicOrganizationDetailView(
            organizationId: organizationId,
            organizationName: state.extra as String?,
          );
        },
      ),

      // Check-in QR
      GoRoute(
        path: AppRoutes.academyCheckin,
        builder: (_, _) => const CheckinScreen(),
      ),

      // Detalle e inscripción clases
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

      // Shell Estudiante
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => StudentShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentHome,
                builder: (_, _) => const WeekCalendarView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/tickets',
                builder: (_, _) => const StudentTicketsView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentClasses,
                builder: (_, _) => const MyClassesView(),
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

      // Shell Academia
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
                builder: (_, _) => const AcademyEventsView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academyClasses,
                builder: (_, _) => const AcademyClassesView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academyTeachers,
                builder: (_, _) => const AcademyTeachersView(),
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

  final loc = state.matchedLocation;
  final onAuthRoute = loc.startsWith('/login') ||
      loc.startsWith('/register') ||
      loc.startsWith('/forgot-password') ||
      loc.startsWith('/auth/callback');

  final isPasswordRecovery =
      authState.value?.event == sb.AuthChangeEvent.passwordRecovery;
  if (isPasswordRecovery) {
    return loc == AppRoutes.updatePassword ? null : AppRoutes.updatePassword;
  }

  final currentSession = sb.Supabase.instance.client.auth.currentSession;
  final currentUser = sb.Supabase.instance.client.auth.currentUser;
  final isAuthenticated = currentSession != null || currentUser != null;

  if (!isAuthenticated) {
    return onAuthRoute ? null : AppRoutes.login;
  }

  final mode = ref.read(effectiveLayoutModeProvider);

  if (onAuthRoute) {
    final role = ref.read(currentUserRoleProvider).asData?.value;
    if (role == UserRole.platformAdmin) return AppRoutes.platformAdmin;
    return mode == AppLayoutMode.academy
        ? AppRoutes.academyDashboard
        : AppRoutes.studentHome;
  }

  final roleAsync = ref.read(currentUserRoleProvider);
  final role = roleAsync.asData?.value;

  if (role != null) {
    if (loc.startsWith(AppRoutes.platformAdmin) && role != UserRole.platformAdmin) {
      return AppRoutes.studentHome;
    }
    if (role == UserRole.platformAdmin &&
        (loc.startsWith('/student') || loc.startsWith('/academy'))) {
      return AppRoutes.platformAdmin;
    }
  }

  final onStudentShell = loc.startsWith('/student');
  final onAcademyShell = loc.startsWith('/academy');

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
    // Filtro para ignorar tokenRefreshed y errores transitorios evitando el error 429
    ref.listen(authStateProvider, (prev, next) {
      if (next.hasError) return;

      final event = next.value?.event;
      if (event == sb.AuthChangeEvent.signedIn ||
          event == sb.AuthChangeEvent.signedOut ||
          event == sb.AuthChangeEvent.userUpdated ||
          event == sb.AuthChangeEvent.passwordRecovery) {
        notifyListeners();
      }
    });

    ref.listen(currentUserRoleProvider, (prev, next) {
      if (prev?.asData?.value != next.asData?.value) {
        notifyListeners();
      }
    });

    ref.listen(layoutModeProvider, (prev, next) {
      if (prev != next) {
        notifyListeners();
      }
    });
  }
}

class _AuthCallbackPage extends ConsumerWidget {
  const _AuthCallbackPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (prev, next) {
      next.whenData((state) {
        if (state.event == sb.AuthChangeEvent.signedIn ||
            state.event == sb.AuthChangeEvent.tokenRefreshed) {
          final mode = ref.read(effectiveLayoutModeProvider);
          context.go(
            mode == AppLayoutMode.academy
                ? AppRoutes.academyDashboard
                : AppRoutes.studentHome,
          );
        }
      });
    });

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}