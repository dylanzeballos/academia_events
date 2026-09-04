import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_model.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/organization_classes_carousel.dart';
import 'class_enroll_detail_view.dart';

/// Exploración de clases por organización: carrusel de organizaciones con
/// clases publicadas → listado de clases publicadas de la seleccionada →
/// botón "Inscribirme".
class ExploreClassesView extends ConsumerStatefulWidget {
  const ExploreClassesView({super.key});

  @override
  ConsumerState<ExploreClassesView> createState() => _ExploreClassesViewState();
}

class _ExploreClassesViewState extends ConsumerState<ExploreClassesView> {
  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(organizationsWithPublishedClassesProvider);
    final selectedOrgId = ref.watch(selectedExploreOrgIdProvider);
    final classesAsync =
        ref.watch(exploreOrgPublishedClassesProvider);

    // Hallar la organización seleccionada para mostrarla en el encabezado.
    final selectedOrg = orgsAsync.value?.where((o) => o.id == selectedOrgId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Explorar clases')),
      body: orgsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orgs) {
          // Si no hay una org seleccionada y ya hay orgs, preseleccionar la
          // primera (incluye orgs sin logo).
          final orgId = ref.read(selectedExploreOrgIdProvider);
          if (orgId == null && orgs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final current = ref.read(selectedExploreOrgIdProvider);
              if (current == null) {
                ref
                    .read(selectedExploreOrgIdProvider.notifier)
                    .select(orgs.first.id);
              }
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Carrusel de organizaciones
              _SectionHeader(
                icon: Icons.business_outlined,
                title: 'Organizaciones',
              ),
              const SizedBox(height: 8),
              OrganizationClassesCarousel(),
              const SizedBox(height: 24),

              // Listado de clases de la seleccionada
              _SectionHeader(
                icon: Icons.school_outlined,
                title: selectedOrg != null
                    ? 'Clases de ${selectedOrg.name}'
                    : 'Clases',
              ),
              const SizedBox(height: 8),
              classesAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (classes) {
                  if (selectedOrgId == null) {
                    return Text(
                      'Selecciona una organización para ver sus clases.',
                      style: TextStyle(color: context.textMuted, fontSize: 14),
                    );
                  }
                  if (classes.isEmpty) {
                    return Text(
                      'Esta organización aún no tiene clases publicadas.',
                      style: TextStyle(color: context.textMuted, fontSize: 14),
                    );
                  }
                  return Column(
                    children: [
                      for (final danceClass in classes)
                        _ExploreClassTile(
                          danceClass: danceClass,
                          onTap: () => _onClassTap(danceClass),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _onClassTap(ClassModel danceClass) {
    // Marcar clase seleccionada y navegar al detalle de inscripción.
    ref.read(selectedEnrollClassIdProvider.notifier).select(danceClass.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClassEnrollDetailView()),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ExploreClassTile extends StatelessWidget {
  const _ExploreClassTile({required this.danceClass, required this.onTap});

  final ClassModel danceClass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  danceClass.title.isNotEmpty
                      ? danceClass.title[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      danceClass.title,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (danceClass.instructorName != null) ...[
                      Icon(Icons.person_outline,
                          size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        danceClass.instructorName!,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}