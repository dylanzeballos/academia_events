import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/repositories/organization_repository.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';

// Componentes modulares
import 'dashboard/dashboard_empty_orgs.dart';
import 'dashboard/dashboard_org_selector.dart';
import 'dashboard/dashboard_quick_actions.dart';
import 'dashboard/dashboard_stats_grid.dart';
import 'dashboard/upcoming_sessions_list.dart';

class AcademyDashboardView extends ConsumerStatefulWidget {
  const AcademyDashboardView({super.key});

  @override
  ConsumerState createState() =>
      _AcademyDashboardViewState();
}

class _AcademyDashboardViewState extends ConsumerState {
  @override
  Widget build(BuildContext context) {
    final selectedOrgId = ref.watch(selectedOrganizationIdProvider);
    final orgsAsync = ref.watch(myOrganizationsProvider);

    ref.listen(myOrganizationsProvider, (prev, next) {
      next.whenData((orgs) {
        if (orgs.isNotEmpty &&
            ref.read(selectedOrganizationIdProvider) == null) {
          ref
              .read(selectedOrganizationIdProvider.notifier)
              .select(orgs.first.organization.id);
        }
      });
    });

    if (selectedOrgId == null) {
      return orgsAsync.when(
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
        data: (orgs) {
          if (orgs.isEmpty) {
            return const Scaffold(body: Center(child: DashboardEmptyOrgs()));
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                ref.read(selectedOrganizationIdProvider) == null) {
              ref
                  .read(selectedOrganizationIdProvider.notifier)
                  .select(orgs.first.organization.id);
            }
          });
          return const Scaffold(
            body: Center(
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
      appBar: AppBar(title: const Text('Panel')),
      body: orgsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orgs) {
          if (orgs.isEmpty) {
            return const DashboardEmptyOrgs();
          }

          // Búsqueda segura: sin firstWhere ni orElse
          OrganizationWithRole? currentOrgWithRole;
          for (final o in orgs) {
            if (o.organization.id == selectedOrgId) {
              currentOrgWithRole = o;
              break;
            }
          }
          currentOrgWithRole ??= orgs.first;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orgStatsProvider);
              ref.invalidate(orgClassesProvider);
              ref.invalidate(orgWeeklyScheduleEntriesProvider);
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
                  const SizedBox(height: 16),

                  // 2. Métricas interactivas
                  statsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text(
                      'Error: $e',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    data: (stats) => DashboardStatsGrid(
                      stats: stats,
                      organization: currentOrgWithRole!.organization,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Acciones Rápidas
                  DashboardQuickActions(canManage: canManage),
                  const SizedBox(height: 24),

                  // 4. Próximas Sesiones del Horario
                  Text(
                    'Horario programado',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const UpcomingSessionsList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}