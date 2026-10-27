// lib/core/router/app_nav_shells.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

class StudentShell extends ConsumerWidget {
  const StudentShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

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
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && navigationShell.currentIndex != 0) {
          // Si no está en Horario, regresa a la primera pestaña antes de cerrar la app
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: navigationShell,
        bottomNavigationBar: InstagramNavBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: navigationShell.goBranch,
          activeIcons: _activeIcons,
          inactiveIcons: _inactiveIcons,
          labels: _labels,
        ),
      ),
    );
  }
}

class AcademyShell extends StatelessWidget {
  const AcademyShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

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
  Widget build(BuildContext context) {
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && navigationShell.currentIndex != 0) {
          // Si no está en el Panel, regresa a la primera pestaña antes de salir
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: navigationShell,
        bottomNavigationBar: InstagramNavBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: navigationShell.goBranch,
          activeIcons: _activeIcons,
          inactiveIcons: _inactiveIcons,
          labels: _labels,
        ),
      ),
    );
  }
}

class InstagramNavBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(top: BorderSide(color: context.divider, width: 0.5)),
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
                        color: isSelected ? AppColors.primary : context.textMuted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? AppColors.primary : context.textMuted,
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