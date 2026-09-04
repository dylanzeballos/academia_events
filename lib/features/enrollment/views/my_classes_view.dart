import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_enrollment_model.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import 'my_class_detail_view.dart';
import 'explore_classes_view.dart';

/// "Mis Clases": lista las inscripciones del estudiante y permite explorar
/// nuevas clases.
class MyClassesView extends ConsumerWidget {
  const MyClassesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(myEnrollmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Clases')),
      body: enrollmentsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(myEnrollmentsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (enrollments) {
          // Solo mostrar inscripciones que aún importan (activas o canceladas).
          final relevant = enrollments
              .where((e) => e.status != 'rejected')
              .toList();
          if (relevant.isEmpty) {
            return _EmptyState(onExplore: () => _openExplore(context));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myEnrollmentsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: relevant.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final enrollment = relevant[index];
                return _EnrollmentCard(
                  enrollment: enrollment,
                  onTap: () {
                    ref
                        .read(selectedEnrolledClassIdProvider.notifier)
                        .select(enrollment.id);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MyClassDetailView(),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openExplore(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.explore_outlined, color: Colors.white),
        label: const Text('Explorar', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _openExplore(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExploreClassesView()),
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({required this.enrollment, required this.onTap});

  final ClassEnrollmentModel enrollment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCancelled = enrollment.isCancelled;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      enrollment.classTitle != null &&
                              enrollment.classTitle!.isNotEmpty
                          ? enrollment.classTitle![0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
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
                          enrollment.classTitle ?? 'Clase',
                          style: TextStyle(
                            color: context.textOnBg,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (enrollment.organizationName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            enrollment.organizationName!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? AppColors.error.withValues(alpha: 0.15)
                          : AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      enrollment.statusDisplayName,
                      style: TextStyle(
                        color: isCancelled ? AppColors.error : AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (enrollment.instructorName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      enrollment.instructorName!,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
              if (enrollment.enrolledAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Inscrito: ${_formatDate(enrollment.enrolledAt!)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Aún no estás inscrito a ninguna clase',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Explora organizaciones y encuentra tu próxima clase.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: onExplore,
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Explorar clases'),
            ),
          ],
        ),
      ),
    );
  }
}