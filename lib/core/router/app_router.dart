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

// Vistas
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
import '../../features/academy/views/academy_archived_events_view.dart';
import '../../features/academy/views/academy_classes_view.dart';
import '../../features/academy/views/academy_teachers_view.dart';

import '../../features/classes/views/class_list_view.dart';
import '../../features/classes/views/class_create_view.dart';
import '../../features/classes/views/class_detail_view.dart';
import '../../features/enrollment/views/my_classes_view.dart';
import '../../features/enrollment/views/my_class_detail_view.dart';

// ── IMPORT CORREGIDO AL NUEVO FEATURE PURCHASES ──
import '../../features/purchases/views/class_enroll_detail_view.dart';

import '../../features/events/views/events_list_view.dart';
import '../../features/events/views/event_create_view.dart';
import '../../features/events/views/event_detail_view.dart';

import '../../features/public/views/public_events_view.dart';
import '../../features/public/views/public_event_detail_view.dart';
import '../../features/public/views/organization_detail_view.dart';

import '../../features/tickets/views/student_tickets_view.dart';
import '../../features/checkin/views/checkin_screen.dart';
import '../../features/admin/views/admin_dashboard_view.dart';
import '../../features/notification/views/notifications_view.dart';

// Llave para pantallas completas que tapan el BottomNavBar
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthStateNotifier(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: notifier,
    initialLocation: AppRoutes.studentHome,
    redirect: (context, state) => _handleRedirect(ref, state),
    routes: [
      // ─────────────────────────────────────────────
      // 1. RUTAS GLOBALES Y AUTENTICACIÓN
      // ─────────────────────────────────────────────
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.login,
        builder: (_, _) => const LoginView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.register,
        builder: (_, _) => const RegisterView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.updatePassword,
        builder: (_, _) => const UpdatePasswordView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.platformAdmin,
        builder: (_, _) => const AdminDashboardView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.authCallback,
        builder: (_, _) => const _AuthCallbackPage(),
      ),

      // ─────────────────────────────────────────────
      // 2. RUTAS SECUNDARIAS (PANTALLAS COMPLETAS)
      // ─────────────────────────────────────────────
      // Profesores (Se abre desde el Dashboard)
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.academyTeachers,
        builder: (_, _) => const AcademyTeachersView(),
      ),

      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.academyClassesView,
        builder: (context, state) => Scaffold(
          backgroundColor: context.scaffoldBg,
          appBar: AppBar(
            backgroundColor: context.cardBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: context.textOnBg,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Clases y Actividades',
              style: TextStyle(
                color: context.textOnBg,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          body: const AcademyClassesView(),
        ),
      ),

      // Organizaciones
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.organizations,
        builder: (_, _) => const OrganizationListView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.organizationsCreate,
        builder: (_, _) => const OrganizationCreateView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.organizationsDetailPattern,
        builder: (context, state) =>
            OrganizationDetailView(organizationId: state.pathParameters['id']),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.myInvitations,
        builder: (_, _) => const MyInvitationsView(),
      ),

      // Clases
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.classList,
        builder: (_, _) => const ClassListView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.classCreate,
        builder: (_, _) => const ClassCreateView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.classDetailPattern,
        builder: (context, state) =>
            ClassDetailView(classId: state.pathParameters['id']),
      ),

      // Eventos
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.eventsList,
        builder: (_, _) => const EventsListView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.eventCreate,
        builder: (_, _) => const EventCreateView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.eventDetailPattern,
        builder: (context, state) {
          final eventId =
              state.pathParameters['id'] ?? state.extra as String? ?? '';
          return EventDetailView(eventId: eventId);
        },
      ),

      // Eventos Archivados Academia
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/academy/events/archived',
        builder: (_, _) => const AcademyArchivedEventsView(),
      ),

      // Públicas
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.publicEvents,
        builder: (_, _) => const PublicEventsView(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.publicEventDetail,
        builder: (context, state) {
          final eventId = state.pathParameters['id'] ?? '';
          return PublicEventDetailView(eventId: eventId);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.organizationPublicDetail,
        builder: (context, state) {
          final organizationId = state.pathParameters['id'] ?? '';
          return PublicOrganizationDetailView(
            organizationId: organizationId,
            organizationName: state.extra as String?,
          );
        },
      ),

      // Inscripciones y Check-in
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.academyCheckin,
        builder: (_, _) => const CheckinScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.myClassDetailPattern,
        builder: (context, state) =>
            MyClassDetailView(enrollmentId: state.pathParameters['id']),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.enrollClassDetailPattern,
        builder: (context, state) =>
            ClassEnrollDetailView(classId: state.pathParameters['id']),
      ),

      // ─────────────────────────────────────────────
      // 3. SHELL ESTUDIANTE (5 PESTAÑAS)
      // ─────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => StudentShell(navigationShell: shell),
        branches: [
          // 0: Horario
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentHome,
                builder: (_, _) => const WeekCalendarView(),
              ),
            ],
          ),
          // 1: Tickets
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentTickets,
                builder: (_, _) => const StudentTicketsView(),
              ),
            ],
          ),
          // 2: Clases
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentClasses,
                builder: (_, _) => const MyClassesView(),
              ),
            ],
          ),
          // 3: Notificaciones
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentNotifications,
                builder: (_, _) => const NotificationsView(),
              ),
            ],
          ),
          // 4: Perfil
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

      // ─────────────────────────────────────────────
      // 4. SHELL ACADEMIA (5 PESTAÑAS)
      // ─────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AcademyShell(navigationShell: shell),
        branches: [
          // 0: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academyDashboard,
                builder: (_, _) => const AcademyDashboardView(),
              ),
            ],
          ),
          // 1: Eventos
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academyEvents,
                builder: (_, _) => const AcademyEventsView(),
              ),
            ],
          ),
          // 2: Clases
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academyClasses,
                builder: (_, _) => const AcademyClassesView(),
              ),
            ],
          ),
          // 3: Notificaciones
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academyNotifications,
                builder: (_, _) => const NotificationsView(),
              ),
            ],
          ),
          // 4: Perfil
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
  final onAuthRoute =
      loc.startsWith('/login') ||
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
    if (loc.startsWith(AppRoutes.platformAdmin) &&
        role != UserRole.platformAdmin) {
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