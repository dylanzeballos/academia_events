// lib/features/organization/views/details/org_achievements_section.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';

class OrgAchievementsSection extends StatelessWidget {
  const OrgAchievementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nuestros Logros & Trayectoria',
                  style: TextStyle(color: context.textOnBg, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Reconocimientos de la compañía oficial',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
            ),
            const Icon(Icons.emoji_events_outlined, color: AppColors.warning, size: 24),
          ],
        ),
        const SizedBox(height: 14),
        const _AchievementCard(
          icon: Icons.emoji_events,
          iconColor: AppColors.warning,
          title: 'Campeones Nacionales Salsa Rueda Casino 2025',
          subtitle: 'Torneo Abierto de Baile Latino • Categoría Elenco Profesional',
        ),
        const SizedBox(height: 10),
        const _AchievementCard(
          icon: Icons.military_tech,
          iconColor: AppColors.secondary,
          title: 'Subcampeones Bachata Sensual Open 2024',
          subtitle: 'Circuito Latinoamericano de Parejas Master',
        ),
        const SizedBox(height: 10),
        const _AchievementCard(
          icon: Icons.stars,
          iconColor: AppColors.primary,
          title: 'Academia Destacada del Año',
          subtitle: 'Premio Anual de la Federación de Baile Social & Arte Corporal',
        ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}