import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../providers/dance_class_provider.dart';
import '../../../../providers/organization_provider.dart';
import '../../../../shared/widgets/dancing_loader_app.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_feedback.dart';

// Componentes modulares
import '../widgets/dashboard_empty_orgs.dart';
import '../widgets/dashboard_org_selector.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/dashboard_stats_grid.dart';
import '../widgets/upcoming_sessions_list.dart';

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

    ref.listen(myOrganizationsProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        next.whenData((orgs) {
          if (orgs.isNotEmpty &&
              ref.read(selectedOrganizationIdProvider) == null) {
            ref
                .read(selectedOrganizationIdProvider.notifier)
                .select(orgs.first.organization.id);
          }
        });
      });
    });

    if (selectedOrgId == null) {
      return orgsAsync.when(
        loading: () => const Scaffold(
          body: DancingLoader(),
        ),
        error: (e, _) => Scaffold(
          body: AppErrorState(message: friendlyError(e)),
        ),
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
            body: DancingLoader(),
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
        title: const Text('Panel'),
        backgroundColor: context.scaffoldBg,
      ),
      body: orgsAsync.when(
        loading: () => const DancingLoader(),
        error: (e, _) => AppErrorState(message: friendlyError(e)),
        data: (orgs) {
          if (orgs.isEmpty) {
            return const DashboardEmptyOrgs();
          }

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
                  statsAsync.when(
                    loading: () => const DancingLoader(size: 80),
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
                  DashboardQuickActions(canManage: canManage),
                  const SizedBox(height: 24),
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