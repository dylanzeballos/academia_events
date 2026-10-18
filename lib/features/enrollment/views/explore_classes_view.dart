// lib/features/enrollment/views/explore_classes_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_model.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../widgets/organization_classes_carousel.dart';

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
    final classesAsync = ref.watch(exploreOrgPublishedClassesProvider);

    final selectedOrg = orgsAsync.value?.where((o) => o.id == selectedOrgId).firstOrNull;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          'Explorar clases',
          style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold),
        ),
      ),
      body: orgsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: Text(friendlyError(e), style: TextStyle(color: context.textMuted)),
        ),
        data: (orgs) {
          final orgId = ref.read(selectedExploreOrgIdProvider);
          if (orgId == null && orgs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final current = ref.read(selectedExploreOrgIdProvider);
              if (current == null) {
                ref.read(selectedExploreOrgIdProvider.notifier).select(orgs.first.id);
              }
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionHeader(
                icon: Icons.business_outlined,
                title: 'Organizaciones',
              ),
              const SizedBox(height: 8),
              const OrganizationClassesCarousel(),
              const SizedBox(height: 24),
              _SectionHeader(
                icon: Icons.school_outlined,
                title: selectedOrg != null
                    ? 'Clases de ${selectedOrg.name}'
                    : 'Clases',
              ),
              const SizedBox(height: 8),
              classesAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => Center(
                  child: Text(friendlyError(e), style: TextStyle(color: context.textMuted)),
                ),
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
    context.push('${AppRoutes.enrollClassDetail}/${danceClass.id}');
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
                  danceClass.title.isNotEmpty ? danceClass.title[0].toUpperCase() : '?',
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
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 12, color: context.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            danceClass.instructorName!,
                            style: TextStyle(color: context.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: context.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}