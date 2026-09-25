import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/organization_model.dart';
import '../../../organization/views/organization_detail_view.dart';

class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({
    super.key,
    required this.stats,
    required this.organization,
  });

  final Map stats;
  final OrganizationModel organization;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // 1. Total de Clases registradas
            Expanded(
              child: _InteractiveStatCard(
                icon: Icons.school_outlined,
                label: 'Clases totales',
                value: '${stats['totalClasses'] ?? 0}',
                color: AppColors.primary,
                onTap: () => context.go(AppRoutes.academyClasses),
              ),
            ),
            const SizedBox(width: 12),
            // 2. Sesiones programadas en la semana
            Expanded(
              child: _InteractiveStatCard(
                icon: Icons.calendar_month_outlined,
                label: 'Horarios activos',
                value: '${stats['upcomingSessions'] ?? stats['activeClasses'] ?? 0}',
                color: AppColors.secondary,
                onTap: () => context.go(AppRoutes.academyClasses),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // 3. Check-ins / Asistencias
            Expanded(
              child: _InteractiveStatCard(
                icon: Icons.qr_code_scanner_outlined,
                label: 'Check-in escáner',
                value: 'QR',
                color: AppColors.success,
                onTap: () => context.push(AppRoutes.academyCheckin),
              ),
            ),
            const SizedBox(width: 12),
            // 4. Directorio de Miembros y Staff
            Expanded(
              child: _InteractiveStatCard(
                icon: Icons.people_outline,
                label: 'Equipo / Miembros',
                value: '${stats['totalMembers'] ?? 0}',
                color: AppColors.warning,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrganizationDetailView(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InteractiveStatCard(
                icon: Icons.visibility_outlined,
                label: 'Visualizaciones',
                value: '${organization.viewsCount}',
                color: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrganizationDetailView(),
                    ),
                  );
                },
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

class _InteractiveStatCard extends StatelessWidget {
  const _InteractiveStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}