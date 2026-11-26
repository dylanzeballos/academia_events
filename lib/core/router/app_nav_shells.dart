// lib/core/router/app_nav_shells.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/screen_orientation.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/providers/notification_provider.dart';

class StudentShell extends ConsumerStatefulWidget {
  const StudentShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  static const _activeIcons = [
    Icons.calendar_month_rounded,
    Icons.confirmation_number_rounded,
    Icons.collections_bookmark_rounded,
    Icons.notifications_rounded,
    Icons.person_rounded,
  ];
  static const _inactiveIcons = [
    Icons.calendar_month_outlined,
    Icons.confirmation_number_outlined,
    Icons.collections_bookmark_outlined,
    Icons.notifications_outlined,
    Icons.person_outline_rounded,
  ];
  static const _labels = ['Horario', 'Tickets', 'Clases', 'Avisos', 'Perfil'];

  @override
  void initState() {
    super.initState();
    ScreenOrientation.lockPortrait();
  }

  @override
  Widget build(BuildContext context) {
    return _BackButtonExitGuard(
      isAtRoot: widget.navigationShell.currentIndex == 0,
      onBackToRoot: () => widget.navigationShell.goBranch(0),
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: widget.navigationShell,
        bottomNavigationBar: InstagramNavBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: widget.navigationShell.goBranch,
          activeIcons: _activeIcons,
          inactiveIcons: _inactiveIcons,
          labels: _labels,
        ),
      ),
    );
  }
}

class AcademyShell extends StatefulWidget {
  const AcademyShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<AcademyShell> createState() => _AcademyShellState();
}

class _AcademyShellState extends State<AcademyShell> {
  static const int _classesTabIndex = 2;

  static const _activeIcons = [
    Icons.dashboard_rounded,
    Icons.event_rounded,
    Icons.school_rounded,
    Icons.notifications_rounded,
    Icons.person_rounded,
  ];
  static const _inactiveIcons = [
    Icons.dashboard_outlined,
    Icons.event_outlined,
    Icons.school_outlined,
    Icons.notifications_outlined,
    Icons.person_outline_rounded,
  ];
  static const _labels = ['Panel', 'Eventos', 'Clases', 'Avisos', 'Perfil'];

  @override
  void initState() {
    super.initState();
    if (widget.navigationShell.currentIndex != _classesTabIndex) {
      _resetToPortrait();
    }
  }

  @override
  void didUpdateWidget(covariant AcademyShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
            widget.navigationShell.currentIndex &&
        widget.navigationShell.currentIndex != _classesTabIndex) {
      _resetToPortrait();
    }
  }

  @override
  void dispose() {
    _resetToPortrait();
    super.dispose();
  }

  Future<void> _resetToPortrait() async {
    await ScreenOrientation.lockPortrait();
  }

  Future<void> _onSelectBranch(int index) async {
    if (index != _classesTabIndex) {
      await _resetToPortrait();
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    // En horizontal el horario necesita todo el alto posible: ocultamos la
    // barra inferior. Solo se puede llegar a horizontal desde "Clases".
    final hideNav =
        isLandscape && widget.navigationShell.currentIndex == _classesTabIndex;

    return _BackButtonExitGuard(
      isAtRoot: widget.navigationShell.currentIndex == 0,
      onBackToRoot: () => _onSelectBranch(0),
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: widget.navigationShell,
        bottomNavigationBar: hideNav
            ? null
            : InstagramNavBar(
                selectedIndex: widget.navigationShell.currentIndex,
                onDestinationSelected: _onSelectBranch,
                activeIcons: _activeIcons,
                inactiveIcons: _inactiveIcons,
                labels: _labels,
              ),
      ),
    );
  }
}

class _BackButtonExitGuard extends StatefulWidget {
  const _BackButtonExitGuard({
    required this.isAtRoot,
    required this.onBackToRoot,
    required this.child,
  });

  final bool isAtRoot;
  final VoidCallback onBackToRoot;
  final Widget child;

  @override
  State<_BackButtonExitGuard> createState() => _BackButtonExitGuardState();
}

class _BackButtonExitGuardState extends State<_BackButtonExitGuard> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (!widget.isAtRoot) {
          _lastBackPress = null;
          widget.onBackToRoot();
          return;
        }

        final now = DateTime.now();
        final lastPress = _lastBackPress;
        if (lastPress != null &&
            now.difference(lastPress) <= const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }

        _lastBackPress = now;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Presiona otra vez para salir'),
              duration: Duration(seconds: 2),
            ),
          );
      },
      child: widget.child,
    );
  }
}

class InstagramNavBar extends ConsumerWidget {
  const InstagramNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.activeIcons,
    required this.inactiveIcons,
    required this.labels,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;
  final List<String> labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(top: BorderSide(color: context.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(activeIcons.length, (i) {
              final isSelected = i == selectedIndex;
              final isNotificationTab = i == 3;

              Widget iconWidget = Icon(
                isSelected ? activeIcons[i] : inactiveIcons[i],
                size: 24,
                color: isSelected ? AppColors.primary : context.textMuted,
              );

              if (isNotificationTab && unreadCount > 0) {
                iconWidget = Badge(
                  backgroundColor: AppColors.error,
                  textColor: Colors.white,
                  smallSize: 8,
                  label: unreadCount > 99
                      ? const Text(
                          '99+',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Text(
                          '$unreadCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  child: iconWidget,
                );
              }

              return Expanded(
                child: InkWell(
                  onTap: () => onDestinationSelected(i),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconWidget,
                      const SizedBox(height: 3),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.primary
                              : context.textMuted,
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
