import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../organization/views/organization_detail_view.dart';

class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({super.key, required this.stats});

  final Map stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InteractiveStatCard(
                icon: Icons.school_outlined,
                label: 'Clases',
                value: '${stats['totalClasses'] ?? 0}',
                color: AppColors.primary,
                onTap: () => context.go(AppRoutes.academyClasses),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InteractiveStatCard(
                icon: Icons.calendar_today,
                label: 'Próximas',
                value: '${stats['upcomingSessions'] ?? 0}',
                color: AppColors.secondary,
                onTap: () => context.go(AppRoutes.academyClasses),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InteractiveStatCard(
                icon: Icons.check_circle_outline,
                label: 'Activas',
                value: '${stats['activeClasses'] ?? 0}',
                color: AppColors.success,
                onTap: () => context.go(AppRoutes.academyClasses),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InteractiveStatCard(
                icon: Icons.people_outline,
                label: 'Miembros',
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
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
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