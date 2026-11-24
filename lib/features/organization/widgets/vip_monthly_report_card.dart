import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/attendance_provider.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../utils/vip_attendance_exporter.dart';

/// Descarga del informe VIP mensual.
///
/// Vive dentro de la pestaña VIP (donde tiene sentido), con etiqueta y
/// descripción en lugar de un ícono suelto en el AppBar.
class VipMonthlyReportCard extends ConsumerWidget {
  const VipMonthlyReportCard({super.key, required this.organizationId});

  final String organizationId;

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Mes del informe VIP',
    );
    if (picked == null || !context.mounted) return;

    final month = DateTime(picked.year, picked.month, 1);
    try {
      final data = await ref
          .read(attendanceRepositoryProvider)
          .fetchOrgVipAttendance(organizationId, month);
      await VipAttendanceExporter.export(data);
    } catch (_) {
      if (context.mounted) {
        AppFeedback.error(
          context,
          'No se pudo generar el informe VIP. Inténtalo de nuevo.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppSectionCard(
      title: 'Informe VIP mensual',
      icon: Icons.summarize_outlined,
      children: [
        Text(
          'Descargá un Excel con las asistencias de los alumnos VIP del mes '
          'que elijas.',
          style: TextStyle(
            color: context.textMuted,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Descargar informe'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          ),
          onPressed: () => _export(context, ref),
        ),
      ],
    );
  }
}
