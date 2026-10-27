// lib/features/academy/views/academy_dashboard_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/repositories/organization_repository.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../organization/utils/vip_attendance_exporter.dart';

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
  Future<void> _exportVipReport(String orgId) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Mes del informe VIP',
    );
    if (picked == null || !mounted) return;
    final month = DateTime(picked.year, picked.month, 1);
    try {
      final data = await ref
          .read(attendanceRepositoryProvider)
          .fetchOrgVipAttendance(orgId, month);
      await VipAttendanceExporter.export(data);
    } catch (_) {
      if (mounted) {
        AppFeedback.error(context, 'No se pudo generar el informe VIP.');
      }
    }
  }

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
          style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar informe VIP',
            icon: const Icon(Icons.summarize_outlined, color: AppColors.primary),
            onPressed: () => _exportVipReport(selectedOrgId),
          ),
        ],
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
                      ref.read(selectedOrganizationIdProvider.notifier).select(orgId);
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
                      child: CircularProgressIndicator(color: AppColors.primary),
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

                  // 5. Sesiones de Hoy
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sesiones programadas',
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Ver horario',
                        style: TextStyle(color: AppColors.primary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const UpcomingSessionsList(),
                  const SizedBox(height: 24),

                  // 6. Actividad Reciente (Estática)
                  Text(
                    'Actividad reciente',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _RecentActivityMock(),
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
  final AsyncValue<Map<dynamic, dynamic>> statsAsync;

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
            child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
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
// Actividad Reciente (Estructura visual estática)
// ─────────────────────────────────────────────
class _RecentActivityMock extends StatelessWidget {
  const _RecentActivityMock();

  @override
  Widget build(BuildContext context) {
    final mockActivities = [
      {
        'user': 'Juan Pérez',
        'action': 'registró asistencia en Salsa',
        'time': 'Hace 5 min',
        'icon': Icons.qr_code_2_rounded,
        'color': AppColors.success,
      },
      {
        'user': 'María Gómez',
        'action': 'inscripción confirmada en Bachata',
        'time': 'Hace 45 min',
        'icon': Icons.assignment_turned_in_outlined,
        'color': AppColors.primary,
      },
      {
        'user': 'Carlos Rojas',
        'action': 'asignado como instructor de clase',
        'time': 'Hace 2 horas',
        'icon': Icons.person_outline,
        'color': AppColors.warning,
      },
    ];

    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: Column(
        children: List.generate(mockActivities.length, (index) {
          final item = mockActivities[index];
          final isLast = index == mockActivities.length - 1;
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: (item['color'] as Color).withValues(alpha: 0.15),
                  child: Icon(
                    item['icon'] as IconData,
                    size: 18,
                    color: item['color'] as Color,
                  ),
                ),
                title: RichText(
                  text: TextSpan(
                    style: TextStyle(color: context.textOnBg, fontSize: 13),
                    children: [
                      TextSpan(
                        text: '${item['user']} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: '${item['action']}',
                        style: TextStyle(color: context.textMuted),
                      ),
                    ],
                  ),
                ),
                trailing: Text(
                  '${item['time']}',
                  style: TextStyle(color: context.textMuted, fontSize: 11),
                ),
              ),
              if (!isLast) Divider(height: 1, indent: 60, color: context.divider),
            ],
          );
        }),
      ),
    );
  }
}