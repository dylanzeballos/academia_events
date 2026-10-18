// lib/features/enrollment/views/my_classes_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/dance_class_session_model.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import 'explore_classes_view.dart';

class MyClassesView extends ConsumerWidget {
  const MyClassesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(myEnrollmentsProvider);
    final groupsAsync = ref.watch(myClassesWithSessionsProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          'Mis Clases',
          style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold),
        ),
      ),
      body: groupsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorState(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(myClassesWithSessionsProvider),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            final hasEnrollments = (enrollmentsAsync.value ?? const [])
                .any((e) => e.status != 'rejected');
            return _EmptyState(
              hasEnrollments: hasEnrollments,
              onExplore: () => _openExplore(context),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(myEnrollmentsProvider);
              ref.invalidate(myClassesWithSessionsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _EnrollmentCard(
                  group: group,
                  onTap: () {
                    context.push(
                      '${AppRoutes.myClassDetail}/${group.enrollment.id}',
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
        icon: const Icon(Icons.explore_outlined, color: AppColors.onPrimary),
        label: const Text('Explorar', style: TextStyle(color: AppColors.onPrimary)),
      ),
    );
  }

  void _openExplore(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExploreClassesView()),
    );
  }
}

class _EnrollmentCard extends StatefulWidget {
  const _EnrollmentCard({required this.group, required this.onTap});

  final MyClassGroup group;
  final VoidCallback onTap;

  @override
  State<_EnrollmentCard> createState() => _EnrollmentCardState();
}

class _EnrollmentCardState extends State<_EnrollmentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final enrollment = widget.group.enrollment;
    final isCancelled = enrollment.isCancelled;
    final sessions = widget.group.upcomingSessions;
    final next = sessions.first;
    final more = sessions.skip(1).toList();

    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        onTap: widget.onTap,
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
                      enrollment.classTitle != null && enrollment.classTitle!.isNotEmpty
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
                            style: TextStyle(color: context.textMuted, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? AppColors.error.withValues(alpha: 0.15)
                          : AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
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
                    Icon(Icons.person_outline, size: 14, color: context.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      enrollment.instructorName!,
                      style: TextStyle(color: context.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _NextSessionBanner(session: next),
              if (more.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: Text(
                      _expanded
                          ? 'Ver menos'
                          : 'Ver ${more.length} sesión${more.length == 1 ? '' : 'es'} más',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 4),
                  for (final session in more) _SessionRow(session: session),
                ],
              ],
              if (enrollment.enrolledAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Inscrito: ${_formatDate(enrollment.enrolledAt!)}',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NextSessionBanner extends StatelessWidget {
  const _NextSessionBanner({required this.session});

  final DanceClassSessionModel session;

  @override
  Widget build(BuildContext context) {
    final start = session.startAt.toLocal();
    final end = session.endAt.toLocal();
    final cancelled = session.isCancelled;
    final color = cancelled ? AppColors.error : AppColors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            cancelled ? Icons.event_busy : Icons.schedule,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cancelled ? 'Próxima sesión cancelada' : 'Próxima sesión',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormatter.capitalize(DateFormatter.shortDay(start))}'
                  ' ${DateFormatter.dayMonth(start)}'
                  ' · ${DateFormatter.timeRange(start, end)}',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final DanceClassSessionModel session;

  @override
  Widget build(BuildContext context) {
    final start = session.startAt.toLocal();
    final end = session.endAt.toLocal();
    final cancelled = session.isCancelled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.event,
            size: 14,
            color: cancelled ? AppColors.error : context.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${DateFormatter.capitalize(DateFormatter.shortDay(start))}'
              ' ${DateFormatter.dayMonth(start)}'
              ' · ${DateFormatter.timeRange(start, end)}',
              style: TextStyle(
                color: cancelled ? AppColors.error : context.textOnBg,
                fontSize: 13,
                decoration: cancelled ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (cancelled)
            const Text(
              'Cancelada',
              style: TextStyle(color: AppColors.error, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) {
  final local = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onExplore, this.hasEnrollments = false});

  final VoidCallback onExplore;
  final bool hasEnrollments;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 64, color: context.textMuted),
            const SizedBox(height: 16),
            Text(
              hasEnrollments
                  ? 'No tienes clases próximas por ahora'
                  : 'Aún no estás inscrito a ninguna clase',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasEnrollments
                  ? 'Las clases sin sesiones futuras no se muestran. Explora nuevas clases mientras tanto.'
                  : 'Explora organizaciones y encuentra tu próxima clase.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
              ),
              onPressed: onExplore,
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Explorar clases', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}