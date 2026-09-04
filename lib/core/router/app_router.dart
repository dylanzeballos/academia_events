import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../constants/app_constants.dart';
import '../utils/theme_extensions.dart';
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
import '../../features/enrollment/views/attendance_management_view.dart';

import '../../features/events/views/events_list_view.dart';
import '../../features/events/views/event_create_view.dart';
import '../../features/events/views/event_detail_view.dart';

import '../../features/public/views/public_events_view.dart';
import '../../features/public/views/public_event_detail_view.dart';
import '../../features/public/views/public_calendar_view.dart';
import '../../features/public/widgets/organization_carousel.dart';

import '../../providers/auth_provider.dart';
import '../../providers/layout_mode_provider.dart';

class _StudentShell extends ConsumerStatefulWidget {
  const _StudentShell({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<_StudentShell> {
  bool _carouselCollapsed = false;

  static const _activeIcons = [
    Icons.calendar_month_rounded,
    Icons.confirmation_number_rounded,
    Icons.collections_bookmark_rounded,
    Icons.person_rounded,
  ];
  static const _inactiveIcons = [
    Icons.calendar_month_outlined,
    Icons.confirmation_number_outlined,
    Icons.collections_bookmark_outlined,
    Icons.person_outline_rounded,
  ];
  static const _labels = ['Horario', 'Tickets', 'Clases', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = AppColors.primary;
    final unselectedColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: shell),
          _carouselCollapsed
              ? _CollapsedCarouselBar(
                  onExpand: () =>
                      setState(() => _carouselCollapsed = false),
                )
              : OrganizationCarousel(
                  height: 80,
                  autoPlayInterval: const Duration(seconds: 5),
                  showTitle: false,
                  onCollapse: () =>
                      setState(() => _carouselCollapsed = true),
                ),
        ],
      ),
      bottomNavigationBar: _InstagramNavBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        activeIcons: _activeIcons,
        inactiveIcons: _inactiveIcons,
        labels: _labels,
        selectedColor: selectedColor,
        unselectedColor: unselectedColor,
      ),
    );
  }
}

/// Bottom navigation bar estilo Instagram: sutil, sin labels grandes,
/// íconos outlined/filled y una línea superior discreta.
class _InstagramNavBar extends StatelessWidget {
  const _InstagramNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.activeIcons,
    required this.inactiveIcons,
    required this.labels,
    required this.selectedColor,
    required this.unselectedColor,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;
  final List<String> labels;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.background : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(activeIcons.length, (i) {
              final isSelected = i == selectedIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onDestinationSelected(i),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? activeIcons[i] : inactiveIcons[i],
                        size: 24,
                        color: isSelected ? selectedColor : unselectedColor,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? selectedColor : unselectedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Franja reducida que se muestra cuando el carrusel está colapsado.
class _CollapsedCarouselBar extends StatelessWidget {
  const _CollapsedCarouselBar({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onExpand,
      child: Container(
        height: 32,
        color: context.cardBg,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.expand_less,
              size: 18,
              color: context.textOnBg.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Organizaciones',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textOnBg.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademyShell extends StatelessWidget {
  const _AcademyShell({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _activeIcons = [
    Icons.dashboard_rounded,
    Icons.event_rounded,
    Icons.school_rounded,
    Icons.people_rounded,
    Icons.person_rounded,
  ];
  static const _inactiveIcons = [
    Icons.dashboard_outlined,
    Icons.event_outlined,
    Icons.school_outlined,
    Icons.people_outline_rounded,
    Icons.person_outline_rounded,
  ];
  static const _labels = ['Panel', 'Eventos', 'Clases', 'Profes', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = AppColors.primary;
    final unselectedColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _InstagramNavBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        activeIcons: _activeIcons,
        inactiveIcons: _inactiveIcons,
        labels: _labels,
        selectedColor: selectedColor,
        unselectedColor: unselectedColor,
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
        final mode = ref.read(effectiveLayoutModeProvider);
        return mode == AppLayoutMode.academy
            ? AppRoutes.academyDashboard
            : AppRoutes.studentHome;
      }

      final roleAsync = ref.read(currentUserRoleProvider);
      if (roleAsync.isLoading) return null;

      final mode = ref.read(effectiveLayoutModeProvider);
      final onStudentShell = state.matchedLocation.startsWith('/student');
      final onAcademyShell = state.matchedLocation.startsWith('/academy');
      if (mode == AppLayoutMode.academy && onStudentShell) {
        return AppRoutes.academyDashboard;
      }
      if (mode == AppLayoutMode.student && onAcademyShell) {
        return AppRoutes.studentHome;
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
      GoRoute(
        path: AppRoutes.myInvitations,
        builder: (_, _) => const MyInvitationsView(),
      ),

      // Clases routes
      GoRoute(
        path: AppRoutes.classList,
        builder: (_, _) => const ClassListView(),
      ),
      GoRoute(
        path: AppRoutes.classCreate,
        builder: (_, _) => const ClassCreateView(),
      ),
      GoRoute(
        path: AppRoutes.classDetail,
        builder: (_, _) => const ClassDetailView(),
      ),



      // Eventos routes
      GoRoute(
        path: AppRoutes.eventsList,
        builder: (_, _) => const EventsListView(),
      ),
      GoRoute(
        path: AppRoutes.eventCreate,
        builder: (_, _) => const EventCreateView(),
      ),
GoRoute(
        path: AppRoutes.eventDetail,
        builder: (context, state) {
          final eventId = state.extra as String;
          return EventDetailView(eventId: eventId);
        },
      ),

      // Public event discovery routes
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
        path: AppRoutes.publicCalendar,
        builder: (_, _) => const PublicCalendarView(),
      ),

      // Asistencia (academia: owner / admin / instructor)
      GoRoute(
        path: AppRoutes.academyAttendance,
        builder: (_, _) => const AttendanceManagementView(),
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
              path: '/student/tickets',
              builder: (_, _) => const _PlaceholderPage(title: 'Tickets'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.studentClasses,
              builder: (_, _) => const MyClassesView(),
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
              builder: (_, _) => const AcademyDashboardView(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.academyEvents,
              builder: (_, _) => const AcademyEventsView(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.academyClasses,
              builder: (_, _) => const AcademyClassesView(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.academyTeachers,
              builder: (_, _) => const AcademyTeachersView(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.academyProfile,
              builder: (_, _) => const ProfileView(),
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

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentUserRoleProvider, (_, _) => notifyListeners());
    ref.listen(layoutModeProvider, (_, _) => notifyListeners());
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
          context.go(mode == AppLayoutMode.academy
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
