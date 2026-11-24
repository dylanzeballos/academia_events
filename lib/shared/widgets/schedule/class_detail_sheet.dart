import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/class_presentation.dart';
import '../../../core/utils/public_urls.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_enrollment_model.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/dance_class_schedule_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../features/tickets/widgets/class_pass_purchase_sheet.dart';
import '../app_feedback.dart';

/// Ficha de una clase, como modal desde el horario semanal.
///
/// Muestra lo que el alumno necesita para decidir (ritmo, profesor, días,
/// horarios, precios y cupos) y resuelve la inscripción sin salir de acá:
/// confirmación en un diálogo y, al quedar inscrito, el acceso a comprar el
/// pase de sesiones.
class ClassDetailSheet extends ConsumerStatefulWidget {
  const ClassDetailSheet({
    super.key,
    required this.danceClass,
    required this.schedules,
    required this.accent,
  });

  final ClassModel danceClass;
  final List<DanceClassScheduleModel> schedules;
  final Color accent;

  static Future<void> show(
    BuildContext context, {
    required ClassModel danceClass,
    required List<DanceClassScheduleModel> schedules,
    required Color accent,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.cardBg,
      builder: (_) => ClassDetailSheet(
        danceClass: danceClass,
        schedules: schedules,
        accent: accent,
      ),
    );
  }

  @override
  ConsumerState<ClassDetailSheet> createState() => _ClassDetailSheetState();
}

class _ClassDetailSheetState extends ConsumerState<ClassDetailSheet> {
  bool _busy = false;
  String? _error;

  List<DanceClassScheduleModel> get _orderedSchedules {
    final list = [...widget.schedules]
      ..sort((a, b) {
        final byDay = (a.dayOfWeek == 0 ? 7 : a.dayOfWeek).compareTo(
          b.dayOfWeek == 0 ? 7 : b.dayOfWeek,
        );
        return byDay != 0 ? byDay : a.startTime.compareTo(b.startTime);
      });
    return list;
  }

  ClassEnrollmentModel? _enrollment(List<ClassEnrollmentModel> enrollments) {
    return enrollments
        .where(
          (e) =>
              e.danceClassId == widget.danceClass.id &&
              (e.status == 'active' ||
                  e.status == 'approved' ||
                  e.status == 'pending'),
        )
        .firstOrNull;
  }

  Future<void> _confirmAndEnroll() async {
    final danceClass = widget.danceClass;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        ),
        title: Text(
          'Inscribirme',
          style: TextStyle(color: dialogContext.textOnBg),
        ),
        content: Text(
          '¿Confirmás tu inscripción a "${danceClass.title}"?\n\n'
          'Después vas a poder comprar tu pase de sesiones, mensual o VIP.',
          style: TextStyle(color: dialogContext.textMuted, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: dialogContext.textMuted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Inscribirme'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final success = await ref
        .read(enrollmentActionProvider.notifier)
        .enroll(danceClass.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!success) {
        _error = friendlyError(
          ref.read(enrollmentActionProvider).error ?? 'No se pudo inscribir.',
        );
      }
    });
  }

  Future<void> _openPurchase(ClassEnrollmentModel enrollment) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLarge),
        ),
      ),
      builder: (_) => ClassPassPurchaseSheet(enrollment: enrollment),
    );
  }

  void _goToLogin() {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final danceClass = widget.danceClass;
    final genre = classGenre(danceClass.title);
    final instructor = danceClass.instructorName;
    final coverUrl = danceClass.coverImageUrl;

    final isLoggedIn = ref.watch(authStateProvider).value?.session != null;
    final enrollments =
        ref.watch(myEnrollmentsProvider).value ??
        const <ClassEnrollmentModel>[];
    final enrollment = _enrollment(enrollments);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (coverUrl != null && coverUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 7,
                        child: CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: widget.accent.withValues(alpha: 0.12),
                          ),
                          errorWidget: (_, _, _) =>
                              _CoverFallback(accent: widget.accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _GenreTag(label: genre, color: widget.accent),
                  const SizedBox(height: 10),
                  Text(
                    danceClass.title,
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (instructor != null && instructor.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      text: instructor,
                    ),
                  ],
                  if (danceClass.organizationName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _OrgLogo(
                          logoUrl: organizationLogoUrl(
                            danceClass.organizationLogoUrl,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            danceClass.organizationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.schedules.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _SectionLabel('Días y horarios'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final schedule in _orderedSchedules)
                          _ScheduleChip(
                            label:
                                '${schedule.dayName} · ${hhmm(schedule.startTime)}–${hhmm(schedule.endTime)}',
                            color: widget.accent,
                          ),
                      ],
                    ),
                  ],
                  if (_hasPrices || danceClass.capacity != null) ...[
                    const SizedBox(height: 18),
                    _SectionLabel('Precios y cupos'),
                    const SizedBox(height: 8),
                    if (danceClass.price > 0)
                      _InfoRow(
                        icon: Icons.confirmation_number_outlined,
                        text:
                            'Bs ${danceClass.price.toStringAsFixed(0)} por sesión',
                      ),
                    if (danceClass.priceMonthly > 0)
                      _InfoRow(
                        icon: Icons.calendar_month_outlined,
                        text:
                            'Bs ${danceClass.priceMonthly.toStringAsFixed(0)} pase mensual',
                      ),
                    if (danceClass.capacity != null)
                      _InfoRow(
                        icon: Icons.groups_outlined,
                        text: '${danceClass.capacity} cupos',
                      ),
                  ],
                  if (danceClass.description != null &&
                      danceClass.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _SectionLabel('Sobre la clase'),
                    const SizedBox(height: 6),
                    Text(
                      danceClass.description!.trim(),
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: _buildAction(context, enrollment, isLoggedIn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    ClassEnrollmentModel? enrollment,
    bool isLoggedIn,
  ) {
    if (enrollment != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.success,
              ),
              const SizedBox(width: 6),
              Text(
                'Ya estás inscrito',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_2, size: 18),
            label: const Text('Comprar sesiones, mensual o VIP'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
            ),
            onPressed: () => _openPurchase(enrollment),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 15,
                color: AppColors.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Icon(Icons.assignment_turned_in_outlined, size: 18),
          label: Text(
            isLoggedIn
                ? 'Inscribirme a esta clase'
                : 'Iniciá sesión para inscribirte',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          ),
          onPressed: _busy
              ? null
              : (isLoggedIn ? _confirmAndEnroll : _goToLogin),
        ),
      ],
    );
  }

  bool get _hasPrices =>
      widget.danceClass.price > 0 || widget.danceClass.priceMonthly > 0;
}

/// Logo chico de la academia para el encabezado del modal.
class _OrgLogo extends StatelessWidget {
  const _OrgLogo({required this.logoUrl});

  final String? logoUrl;

  static const double _size = 16;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.storefront_rounded,
          size: 11,
          color: AppColors.primary,
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: _size,
          height: _size,
          color: context.divider.withValues(alpha: 0.25),
        ),
        errorWidget: (_, _, _) => Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.storefront_rounded,
            size: 11,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: accent.withValues(alpha: 0.12),
      child: Icon(Icons.music_note_rounded, color: accent, size: 32),
    );
  }
}

class _GenreTag extends StatelessWidget {
  const _GenreTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.textOnBg,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.textOnBg, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.textOnBg,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
