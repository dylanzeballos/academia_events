// lib/features/academy/views/academy_dashboard_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'dashboard/upcoming_sessions_list.dart';

class AcademyDashboardView extends ConsumerStatefulWidget {
  const AcademyDashboardView({super.key});

  @override
  ConsumerState<AcademyDashboardView> createState() => _AcademyDashboardViewState();
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
          if (orgs.isNotEmpty && ref.read(selectedOrganizationIdProvider) == null) {
            ref
                .read(selectedOrganizationIdProvider.notifier)
                .select(orgs.first.organization.id);
          }
        });
      });
    });

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
            return Scaffold(
              backgroundColor: context.scaffoldBg,
              body: const Center(child: DashboardEmptyOrgs()),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && ref.read(selectedOrganizationIdProvider) == null) {
              ref
                  .read(selectedOrganizationIdProvider.notifier)
                  .select(orgs.first.organization.id);
            }
          });
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
          style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold),
        ),
      ),
      body: orgsAsync.when(
        loading: () => const LoadingIndicator(),
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
            color: AppColors.primary,
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
                    loading: () =>
                        const Center(child: CircularProgressIndicator(color: AppColors.primary)),
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