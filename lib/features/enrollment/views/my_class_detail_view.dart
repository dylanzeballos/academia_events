// lib/features/enrollment/views/my_class_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/class_enrollment_model.dart';
import '../../../data/models/class_pass_model.dart';
import '../../../data/models/dance_class_session_model.dart';
import '../../../providers/checkin_provider.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../tickets/widgets/class_pass_purchase_sheet.dart';

class MyClassDetailView extends ConsumerStatefulWidget {
  const MyClassDetailView({super.key, this.enrollmentId});

  final String? enrollmentId;

  @override
  ConsumerState<MyClassDetailView> createState() => _MyClassDetailViewState();
}

class _MyClassDetailViewState extends ConsumerState<MyClassDetailView> {
  static const int _pageSize = 15;
  int _sessionsLimit = _pageSize;

  @override
  void initState() {
    super.initState();
    final id = widget.enrollmentId;
    if (id != null && id.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedEnrolledClassIdProvider.notifier).select(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrollmentAsync = ref.watch(selectedMyEnrollmentProvider);
    final attendanceAsync = ref.watch(enrolledClassAttendanceProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          'Mi clase',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: enrollmentAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: Text(
            friendlyError(e),
            style: TextStyle(color: context.textMuted),
          ),
        ),
        data: (enrollment) {
          if (enrollment == null) {
            return Center(
              child: Text(
                'Inscripción no encontrada.',
                style: TextStyle(color: context.textMuted),
              ),
            );
          }
          final sessionsAsync = ref.watch(
            classSessionsPageProvider((
              classId: enrollment.danceClassId,
              limit: _sessionsLimit,
              upcomingOnly: true,
              pastOnly: false,
            )),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(enrollment: enrollment),
              const SizedBox(height: 16),
              _PassSection(enrollment: enrollment),
              const SizedBox(height: 24),
              const _SectionTitle(
                icon: Icons.event_available,
                title: 'Próximas sesiones',
              ),
              const SizedBox(height: 8),
              sessionsAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => Text(
                  friendlyError(e),
                  style: TextStyle(color: context.textMuted),
                ),
                data: (page) {
                  final sessions = page.sessions;
                  if (sessions.isEmpty) {
                    return Text(
                      'No hay sesiones próximas programadas.',
                      style: TextStyle(color: context.textMuted, fontSize: 14),
                    );
                  }
                  final attendanceBySession = <String, AttendanceModel>{
                    for (final a
                        in attendanceAsync.value ?? const <AttendanceModel>[])
                      a.sessionId: a,
                  };
                  return Column(
                    children: [
                      for (final s in sessions)
                        _SessionTile(
                          session: s,
                          attendance: attendanceBySession[s.id],
                        ),
                      if (page.hasMore)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                            ),
                            label: const Text('Ver más sesiones'),
                            onPressed: () =>
                                setState(() => _sessionsLimit += _pageSize),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _PastSessionsSection(
                enrollment: enrollment,
                attendance: attendanceAsync.value ?? const <AttendanceModel>[],
              ),
              const SizedBox(height: 24),
              _CancelButton(enrollment: enrollment),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.enrollment});

  final ClassEnrollmentModel enrollment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          enrollment.classTitle ?? 'Clase',
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (enrollment.organizationName != null) ...[
          const SizedBox(height: 6),
          Text(
            enrollment.organizationName!,
            style: TextStyle(color: context.textMuted, fontSize: 14),
          ),
        ],
        if (enrollment.instructorName != null) ...[
          const SizedBox(height: 6),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: enrollment.isCancelled
                ? AppColors.error.withValues(alpha: 0.15)
                : AppColors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            border: Border.all(
              color: enrollment.isCancelled
                  ? AppColors.error.withValues(alpha: 0.3)
                  : AppColors.success.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            enrollment.statusDisplayName,
            style: TextStyle(
              color: enrollment.isCancelled
                  ? AppColors.error
                  : AppColors.success,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PassSection extends ConsumerWidget {
  const _PassSection({required this.enrollment});

  final ClassEnrollmentModel enrollment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enrollment.isActive) return const SizedBox.shrink();

    final passesAsync = ref.watch(myClassPassesProvider);
    return passesAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (passes) {
        final activePasses = passes
            .where((p) => p.enrollmentId == enrollment.id && p.isActive)
            .toList();
        final activePass = activePasses.firstOrNull;

        if (activePass != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ActivePassCard(pass: activePass),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.textOnBg,
                  side: BorderSide(color: context.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: context.cardBg,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSizes.radiusLarge),
                    ),
                  ),
                  isScrollControlled: true,
                  builder: (_) =>
                      ClassPassPurchaseSheet(enrollment: enrollment),
                ),
                icon: const Icon(Icons.add_card),
                label: const Text('Comprar más sesiones o pase mensual'),
              ),
            ],
          );
        }
        return FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
          ),
          onPressed: () => showModalBottomSheet(
            context: context,
            backgroundColor: context.cardBg,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusLarge),
              ),
            ),
            isScrollControlled: true,
            builder: (_) => ClassPassPurchaseSheet(enrollment: enrollment),
          ),
          icon: const Icon(Icons.add_card),
          label: const Text(
            'Comprar pase',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}

class _ActivePassCard extends StatelessWidget {
  const _ActivePassCard({required this.pass});

  final ClassPassModel pass;

  @override
  Widget build(BuildContext context) {
    final daysLeft = pass.endsAt.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_outlined, color: AppColors.success, size: 20),
              SizedBox(width: 8),
              Text(
                'Pase activo',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            pass.isVip
                ? 'Pase VIP de la organización'
                : pass.isMonthly
                ? 'Pase mensual de la clase'
                : pass.passType == 'session'
                ? 'Pase de 1 sesión'
                : 'Pase de sesiones',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vence el ${_formatDate(pass.endsAt)} · quedan $daysLeft días.',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          if (pass.sessionCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Incluye ${pass.sessionCount} sesiones.',
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

/// Historial paginado: se carga solo si el alumno lo abre.
class _PastSessionsSection extends ConsumerStatefulWidget {
  const _PastSessionsSection({
    required this.enrollment,
    required this.attendance,
  });

  final ClassEnrollmentModel enrollment;
  final List<AttendanceModel> attendance;

  @override
  ConsumerState<_PastSessionsSection> createState() =>
      _PastSessionsSectionState();
}

class _PastSessionsSectionState extends ConsumerState<_PastSessionsSection> {
  static const int _pageSize = 10;
  int _limit = _pageSize;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('Ver sesiones anteriores'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          onPressed: () => setState(() => _expanded = true),
        ),
      );
    }

    final pastAsync = ref.watch(
      classSessionsPageProvider((
        classId: widget.enrollment.danceClassId,
        limit: _limit,
        upcomingOnly: false,
        pastOnly: true,
      )),
    );

    final attendanceBySession = <String, AttendanceModel>{
      for (final a in widget.attendance) a.sessionId: a,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          icon: Icons.history_rounded,
          title: 'Sesiones anteriores',
        ),
        const SizedBox(height: 8),
        pastAsync.when(
          loading: () => const LoadingIndicator(),
          error: (e, _) => Text(
            friendlyError(e),
            style: TextStyle(color: context.textMuted),
          ),
          data: (page) {
            if (page.sessions.isEmpty) {
              return Text(
                'Todavía no hay sesiones anteriores.',
                style: TextStyle(color: context.textMuted, fontSize: 14),
              );
            }
            return Column(
              children: [
                for (final session in page.sessions)
                  _SessionTile(
                    session: session,
                    attendance: attendanceBySession[session.id],
                  ),
                if (page.hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.expand_more_rounded, size: 18),
                      label: const Text('Ver más sesiones anteriores'),
                      onPressed: () => setState(() => _limit += _pageSize),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

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
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.attendance});

  final DanceClassSessionModel session;
  final AttendanceModel? attendance;

  @override
  Widget build(BuildContext context) {
    final att = attendance;
    final statusColor = att == null
        ? context.textMuted
        : att.isLate
        ? AppColors.warning
        : att.isPresent
        ? AppColors.success
        : AppColors.error;

    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              session.isCancelled ? Icons.event_busy : Icons.event,
              color: session.isCancelled ? AppColors.error : AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(session.sessionDate),
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatTime(session.startAt)} - ${_formatTime(session.endAt)}',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (att != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      att.statusDisplayName,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                session.isCancelled ? session.statusDisplayName : 'Pendiente',
                style: TextStyle(
                  color: session.isCancelled
                      ? AppColors.error
                      : context.textMuted,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  static String _formatTime(DateTime d) {
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}

class _CancelButton extends ConsumerStatefulWidget {
  const _CancelButton({required this.enrollment});

  final ClassEnrollmentModel enrollment;

  @override
  ConsumerState<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends ConsumerState<_CancelButton> {
  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(enrollmentActionProvider);
    final canCancel = widget.enrollment.isActive;

    if (actionState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Column(
      children: [
        if (actionState.error != null) ...[
          Text(
            actionState.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
          const SizedBox(height: 12),
        ],
        if (canCancel)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
            onPressed: () => _confirmCancel(context),
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Quitar de mi horario'),
          ),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(
          'Quitar de mi horario',
          style: TextStyle(color: context.textOnBg),
        ),
        content: Text(
          '¿Seguro que quieres quitar esta clase de tu horario? '
          'Podés volver a anotarte cuando quieras.',
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('No', style: TextStyle(color: context.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, quitar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(enrollmentActionProvider.notifier)
        .cancel(widget.enrollment.id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Clase quitada de tu horario.'
                : 'No se pudo quitar la clase.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.cardBg,
        ),
      );
  }
}
