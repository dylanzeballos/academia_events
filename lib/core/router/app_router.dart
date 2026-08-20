import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../constants/app_constants.dart';
import '../utils/theme_extensions.dart';
import '../../data/models/profile_model.dart';
import '../../features/auth/views/forgot_password_view.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/register_view.dart';
import '../../features/auth/views/update_password_view.dart';
import '../../features/calendar/week_calendar_view.dart';
import '../../features/profile/profile_view.dart';
import '../../features/organization/views/organization_list_view.dart';
import '../../features/organization/views/organization_detail_view.dart';
import '../../features/organization/views/organization_create_view.dart';
import '../../providers/auth_provider.dart';

class _StudentShell extends StatelessWidget {
  const _StudentShell({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.calendar_month),
      label: 'HORARIO',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups),
      label: 'INSTRUCTORES',
    ),
    NavigationDestination(
      icon: Icon(Icons.collections_bookmark),
      label: 'MIS CLASES',
    ),
    NavigationDestination(
      icon: Icon(Icons.person),
      label: 'PERFIL',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Padding(
        padding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 8),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              destinations: _destinations,
            ),
          ),
        ),
      ),
    );
  }
}

class _AcademyShell extends StatelessWidget {
  const _AcademyShell({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      label: 'PANEL',
    ),
    NavigationDestination(
      icon: Icon(Icons.event_outlined),
      label: 'EVENTOS',
    ),
    NavigationDestination(
      icon: Icon(Icons.school_outlined),
      label: 'CLASES',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      label: 'PROFES',
    ),
    NavigationDestination(
      icon: Icon(Icons.confirmation_number_outlined),
      label: 'TICKETS',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Padding(
        padding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 8),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              destinations: _destinations,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          title,
          style: TextStyle(color: context.textOnBg, fontSize: 18),
        ),
      ),
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthStateNotifier(ref);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: AppRoutes.studentHome,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoading = authState.isLoading;

      if (isLoading) return null;

      final supabaseSession = ref.read(authRepositoryProvider).isAuthenticated;
      final isPasswordRecovery =
          authState.value?.event == sb.AuthChangeEvent.passwordRecovery;

      final onAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation.startsWith('/forgot-password');

      if (isPasswordRecovery) {
        return state.matchedLocation == AppRoutes.updatePassword
            ? null
            : AppRoutes.updatePassword;
      }

      if (!supabaseSession) {
        return onAuthRoute ? null : AppRoutes.login;
      }

      if (onAuthRoute) {
        final roleAsync = ref.read(currentUserRoleProvider);
        final role = roleAsync.valueOrNull ?? UserRole.student;
        return role == UserRole.academy
            ? AppRoutes.academyDashboard
            : AppRoutes.studentHome;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginView(),
      ),
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

      // Callback para OAuth en web (Google login)
      GoRoute(
        path: '/auth/callback',
        builder: (_, _) => const _AuthCallbackPage(),
      ),

      GoRoute(
        path: AppRoutes.organizations,
        builder: (_, _) => const OrganizationListView(),
      ),
      GoRoute(
        path: AppRoutes.organizationsCreate,
        builder: (_, _) => const OrganizationCreateView(),
      ),
      GoRoute(
        path: AppRoutes.organizationsDetail,
        builder: (_, _) => const OrganizationDetailView(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _StudentShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.studentHome,
              builder: (_, _) => const WeekCalendarView(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/student/instructors',
              builder: (_, _) =>
                  const _PlaceholderPage(title: 'Instructores'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.studentClasses,
              builder: (_, _) =>
                  const _PlaceholderPage(title: 'Mis Clases'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.studentProfile,
              builder: (_, _) => const ProfileView(),
            ),
          ]),
        ],
      ),

      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _AcademyShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.academyDashboard,
              builder: (_, _) =>
                  const _PlaceholderPage(title: 'Dashboard Academia'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.academyEvents,
              builder: (_, _) =>
                  const _PlaceholderPage(title: 'Eventos Academia'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.academyClasses,
              builder: (_, _) =>
                  const _PlaceholderPage(title: 'Clases Academia'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.academyTeachers,
              builder: (_, _) =>
                  const _PlaceholderPage(title: 'Profesores'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.academyTickets,
              builder: (_, _) => const _PlaceholderPage(title: 'Tickets'),
            ),
          ]),
        ],
      ),
    ],

    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text(
          'Ruta no encontrada: ${state.error}',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    ),
  );
});

extension on AsyncValue<UserRole> {
  Object? get valueOrNull => null;
}

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentUserRoleProvider, (_, _) => notifyListeners());
  }
}

class _AuthCallbackPage extends ConsumerWidget {
  const _AuthCallbackPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Supabase SDK en web maneja el intercambio de código automáticamente.
    // Esta página solo muestra feedback mientras se procesa.
    ref.listen(authStateProvider, (prev, next) {
      next.whenData((state) {
        if (state.event == sb.AuthChangeEvent.signedIn ||
            state.event == sb.AuthChangeEvent.tokenRefreshed) {
          final roleAsync = ref.read(currentUserRoleProvider);
          final role = roleAsync.valueOrNull ?? UserRole.student;
          context.go(role == UserRole.academy
              ? AppRoutes.academyDashboard
              : AppRoutes.studentHome);
        }
      });
    });

    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
