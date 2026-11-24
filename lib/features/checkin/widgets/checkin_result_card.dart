// lib/features/checkin/widgets/checkin_result_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/check_in_result_model.dart';

class CheckInResultCard extends StatelessWidget {
  const CheckInResultCard({
    super.key,
    required this.result,
    this.onContinue,
  });

  final CheckInResultModel result;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final statusColor = result.success ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.cancel,
            size: 64,
            color: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            result.success ? 'Entrada registrada' : 'Entrada rechazada',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (result.success) _buildSuccessDetails(context) else _buildError(context),
          if (onContinue != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
              ),
              onPressed: onContinue,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear otro', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Text(
      result.reason ?? 'QR no válido.',
      textAlign: TextAlign.center,
      style: TextStyle(color: context.textMuted, fontSize: 14),
    );
  }

  Widget _buildSuccessDetails(BuildContext context) {
    final title = result.eventTitle ?? result.classTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (result.sessionDate != null) ...[
          const SizedBox(height: 4),
          Text(
            DateFormat('EEE d MMM yyyy', 'es').format(result.sessionDate!.toLocal()),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        _InfoRow(
          icon: Icons.person_outline,
          label: 'Asistente',
          value: result.attendeeName ?? '—',
        ),
        if (result.ticketNumber != null)
          _InfoRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Ticket',
            value: result.ticketNumber!,
          ),
        if (result.checkedInAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Registrado el ${DateFormat('HH:mm', 'es').format(result.checkedInAt!.toLocal())}',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.textMuted),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}