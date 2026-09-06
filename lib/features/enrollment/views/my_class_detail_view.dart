import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/class_enrollment_model.dart';
import '../../../data/models/class_pass_model.dart';
import '../../../data/models/dance_class_session_model.dart';
import '../../../providers/checkin_provider.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../tickets/widgets/class_pass_purchase_sheet.dart';

/// Detalle de una clase a la que el estudiante está inscrito: muestra sus
/// sesiones y la asistencia registrada, y permite cancelar la inscripción.
class MyClassDetailView extends ConsumerWidget {
  const MyClassDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentAsync = ref.watch(selectedMyEnrollmentProvider);
    final sessionsAsync = ref.watch(enrolledClassSessionsProvider);
    final attendanceAsync = ref.watch(enrolledClassAttendanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi clase')),
      body: enrollmentAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (enrollment) {
          if (enrollment == null) {
            return const Center(child: Text('Inscripción no encontrada.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(enrollment: enrollment),
              const SizedBox(height: 16),
              _PassSection(enrollment: enrollment),
              const SizedBox(height: 24),
              _SectionTitle(
                icon: Icons.event_available,
                title: 'Sesiones',
              ),
              const SizedBox(height: 8),
              sessionsAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return Text(
                      'No hay sesiones programadas.',
                      style: TextStyle(color: context.textMuted, fontSize: 14),
                    );
                  }
                  final attendanceBySession = <String, AttendanceModel>{
                    for (final a in attendanceAsync.value ?? const <AttendanceModel>[])
                      a.sessionId: a,
                  };
                  return Column(
                    children: [
                      for (final s in sessions)
                        _SessionTile(
                          session: s,
                          attendance: attendanceBySession[s.id],
                        ),
                    ],
                  );
                },
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
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
        if (enrollment.instructorName != null) ...[
          const SizedBox(height: 6),
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
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: enrollment.isCancelled
                ? AppColors.error.withValues(alpha: 0.15)
                : AppColors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            enrollment.statusDisplayName,
            style: TextStyle(
              color: enrollment.isCancelled ? AppColors.error : AppColors.success,
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
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (passes) {
        final activePass = passes
            .where((p) =>
                p.enrollmentId == enrollment.id && p.isActive)
            .firstOrNull;

        if (activePass != null) {
          return _ActivePassCard(pass: activePass);
        }
        return FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => showModalBottomSheet(
            context: context,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            isScrollControlled: true,
            builder: (_) =>
                ClassPassPurchaseSheet(enrollment: enrollment),
          ),
          icon: const Icon(Icons.add_card),
          label: const Text('Comprar pase'),
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
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
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
          const SizedBox(height: 8),
          Text(
            'Vence el ${_formatDate(pass.endsAt)} · quedan $daysLeft días.',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          if (pass.sessionCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Incluye ${pass.sessionCount} sesiones.',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
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
        ? Colors.grey
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
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (att != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      att.statusDisplayName,
                      style:
                          TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else
              Text(
                session.isCancelled ? session.statusDisplayName : 'Pendiente',
                style: TextStyle(
                  color: session.isCancelled ? AppColors.error : Colors.grey,
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
      return const Center(child: CircularProgressIndicator());
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
            ),
            onPressed: () => _confirmCancel(context),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar inscripción'),
          ),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).scaffoldBackgroundColor,
        title: const Text('Cancelar inscripción'),
        content: const Text(
          '¿Seguro que quieres cancelar tu inscripción a esta clase?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, cancelar'),
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
              success ? 'Inscripción cancelada.' : 'No se pudo cancelar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}