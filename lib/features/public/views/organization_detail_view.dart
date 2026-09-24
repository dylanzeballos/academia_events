import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/public_event_data.dart';
import '../../../../providers/public_events_provider.dart';
import './details/org_achievements_section.dart';
import './details/org_gallery_section.dart';
import './details/org_hero_header.dart';
import './details/org_location_section.dart';
import './details/org_teachers_section.dart';
import './details/public_schedule_view.dart';

class PublicOrganizationDetailView extends ConsumerWidget {
  const PublicOrganizationDetailView({
    super.key,
    required this.organizationId,
    this.organizationName,
  });

  final String organizationId;
  final String? organizationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(organizationsWithEventsProvider);

    OrganizationWithEventCount? org;
    for (final o in orgsAsync.value ?? const []) {
      if (o.id == organizationId) {
        org = o;
        break;
      }
    }
    final name = org?.name ?? organizationName ?? 'Academia de Baile';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D14),
        elevation: 0,
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Portada, Avatar, Rating & Botones
            OrgHeroHeader(
              name: name,
              logoUrl: org?.logoUrl,
              onShare: () {},
            ),

            const SizedBox(height: 16),

            // ── BOTÓN DIRECTO: HORARIO SOLO LECTURA ──
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
                border: Border.all(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicScheduleView(
                          organizationId: organizationId,
                          organizationName: name,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFF06B6D4),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Horario Semanal de Clases',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ver días, horas y profesores disponibles',
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.55),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF06B6D4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 2. Instalaciones y Galería Oficial
            const OrgGallerySection(),

            const SizedBox(height: 28),

            // 3. Logros & Trayectoria
            const OrgAchievementsSection(),

            const SizedBox(height: 28),

            // 4. Plantel de Maestros
            const OrgTeachersSection(),

            const SizedBox(height: 28),

            // 5. Ubicación en Mapa & Servicios de Sede
            const OrgLocationSection(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}