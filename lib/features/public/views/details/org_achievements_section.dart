import 'package:flutter/material.dart';

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
            const Icon(Icons.emoji_events_outlined, color: Color(0xFFF59E0B), size: 24),
          ],
        ),
        const SizedBox(height: 14),
        const _AchievementCard(
          icon: Icons.emoji_events,
          iconColor: Color(0xFFF59E0B),
          title: 'Campeones Nacionales Salsa Rueda Casino 2025',
          subtitle: 'Torneo Abierto de Baile Latino • Categoría Elenco Profesional',
        ),
        const SizedBox(height: 10),
        const _AchievementCard(
          icon: Icons.military_tech,
          iconColor: Color(0xFF38BDF8),
          title: 'Subcampeones Bachata Sensual Open 2024',
          subtitle: 'Circuito Latinoamericano de Parejas Master',
        ),
        const SizedBox(height: 10),
        const _AchievementCard(
          icon: Icons.stars,
          iconColor: Color(0xFFE85D04),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
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