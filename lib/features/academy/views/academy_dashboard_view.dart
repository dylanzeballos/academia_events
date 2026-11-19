// lib/features/academy/views/academy_dashboard_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/repositories/organization_repository.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';

import 'dashboard/dashboard_empty_orgs.dart';
import 'dashboard/dashboard_org_selector.dart';
import 'dashboard/dashboard_quick_actions.dart';
import 'dashboard/dashboard_stats_grid.dart';
import 'dashboard/views_recent_activity_card.dart';

class AcademyDashboardView extends ConsumerStatefulWidget {
  const AcademyDashboardView({super.key});

  @override
  ConsumerState<AcademyDashboardView> createState() =>
      _AcademyDashboardViewState();
}

class _AcademyDashboardViewState extends ConsumerState<AcademyDashboardView> {
  @override
  Widget build(BuildContext context) {
    final selectedOrgId = ref.watch(selectedOrganizationIdProvider);
    final orgsAsync = ref.watch(myOrganizationsProvider);

    // Garantiza una academia seleccionada (o válida) sin depender de que el
    // provider de organizaciones vuelva a emitir.
    final orgs = orgsAsync.value;
    if (orgs != null && orgs.isNotEmpty) {
      final isValid = orgs.any((o) => o.organization.id == selectedOrgId);
      if (!isValid) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final list = ref.read(myOrganizationsProvider).value;
          if (list == null || list.isEmpty) return;
          final current = ref.read(selectedOrganizationIdProvider);
          if (list.any((o) => o.organization.id == current)) return;
          ref
              .read(selectedOrganizationIdProvider.notifier)
              .select(list.first.organization.id);
        });
      }
    }

    if (selectedOrgId == null) {
      return orgsAsync.when(
        loading: () => Scaffold(
          backgroundColor: context.scaffoldBg,
          body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (e, _) => Scaffold(
          backgroundColor: context.scaffoldBg,
          body: AppErrorState(message: friendlyError(e)),
        ),
        data: (orgs) {
          if (orgs.isEmpty) {
            return const Scaffold(body: Center(child: DashboardEmptyOrgs()));
          }
          return Scaffold(
            backgroundColor: context.scaffoldBg,
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        },
      );
    }

    final statsAsync = ref.watch(orgStatsProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageMembers ?? false;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          'Panel',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: orgsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorState(message: friendlyError(e)),
        data: (orgs) {
          if (orgs.isEmpty) return const DashboardEmptyOrgs();

          OrganizationWithRole? currentOrgWithRole;
          for (final o in orgs) {
            if (o.organization.id == selectedOrgId) {
              currentOrgWithRole = o;
              break;
            }
          }
          currentOrgWithRole ??= orgs.first;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(orgStatsProvider);
              ref.invalidate(orgClassesProvider);
              ref.invalidate(orgWeeklyScheduleEntriesProvider);
              ref.invalidate(organizationRecentActivityProvider(selectedOrgId));
              ref.invalidate(organizationViewsStatsProvider(selectedOrgId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Selector de Organización
                  DashboardOrgSelector(
                    orgs: orgs,
                    selectedOrgId: selectedOrgId,
                    currentRole: currentOrgWithRole.role,
                    onSelected: (orgId) {
                      ref
                          .read(selectedOrganizationIdProvider.notifier)
                          .select(orgId);
                    },
                  ),
                  const SizedBox(height: 14),

                  // 2. Banner del Día
                  _TodayBanner(statsAsync: statsAsync),
                  const SizedBox(height: 18),

                  // 3. Acciones Rápidas
                  DashboardQuickActions(canManage: canManage),
                  const SizedBox(height: 20),

                  // 4. Estadísticas (Grid)
                  statsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                    error: (e, _) => Text(
                      friendlyError(e),
                      style: TextStyle(color: context.textMuted),
                    ),
                    data: (stats) => DashboardStatsGrid(
                      stats: stats,
                      organization: currentOrgWithRole!.organization,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. Actividad Reciente
                  Text(
                    'Actividad reciente',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ViewsRecentActivityCard(organizationId: selectedOrgId),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Banner Operativo del Día
// ─────────────────────────────────────────────
class _TodayBanner extends StatelessWidget {
  const _TodayBanner({required this.statsAsync});
  final AsyncValue<Map<String, dynamic>> statsAsync;

  @override
  Widget build(BuildContext context) {
    final activeCount = statsAsync.maybeWhen(
      data: (s) => s['upcomingSessions'] ?? s['activeClasses'] ?? 0,
      orElse: () => 0,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.flash_on_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operación de Hoy',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hoy tienes $activeCount sesiones • Check-in QR activo',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Banner Operativo del Día
// ─────────────────────────────────────────────
