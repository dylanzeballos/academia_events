// lib/features/events/widgets/detail/event_publish_action_bar.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';

/// Estado informativo para eventos creados como borrador.
///
/// Para publicar un evento la organización necesita:
///  1. Una suscripción mensual activa.
///  2. Su cuenta de cobros registrada, para recibir los pagos de las entradas.
///
/// Cuando ambos requisitos se cumplen, el evento puede publicarse.
///
/// [hasActiveSubscription] y [hasPaymentAccount] son opcionales: si son
/// `null` (aún no se conoce el estado) se muestra la lista sin marcar.
class EventPublishActionBar extends StatelessWidget {
  const EventPublishActionBar({
    super.key,
    required this.event,
    this.hasActiveSubscription,
    this.hasPaymentAccount,
  });

  final EventModel event;
  final bool? hasActiveSubscription;
  final bool? hasPaymentAccount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: context.cardBg,
          border: Border(top: BorderSide(color: context.divider)),
        ),
        child: SizedBox(
          height: AppSizes.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: () => _showRequirementsDialog(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.textOnBg,
              side: BorderSide(color: context.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingMedium,
              ),
            ),
            icon: const Icon(
              Icons.lock_clock_outlined,
              color: AppColors.warning,
              size: 20,
            ),
            label: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ver requisitos de publicación',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRequirementsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.cardBg,
        surfaceTintColor: context.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          side: BorderSide(color: context.divider),
        ),
        icon: const Icon(
          Icons.lock_clock_outlined,
          color: AppColors.warning,
          size: 32,
        ),
        title: Text(
          'Publicación pendiente',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para publicar este evento necesitás:',
                style: TextStyle(color: context.textMuted, height: 1.4),
              ),
              const SizedBox(height: 12),
              _RequirementRow(
                text: 'Una suscripción mensual activa de tu organización.',
                done: hasActiveSubscription,
              ),
              const SizedBox(height: 10),
              _RequirementRow(
                text:
                    'Tu cuenta de cobros registrada, para recibir los '
                    'pagos de las entradas.',
                done: hasPaymentAccount,
              ),
              const SizedBox(height: 16),
              Text(
                'Cuando ambos estén listos, podrás publicar el evento.',
                style: TextStyle(color: context.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(112, AppSizes.buttonHeight),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.text, this.done});

  final String text;

  /// `true` = cumplido, `false` = pendiente, `null` = estado desconocido.
  final bool? done;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    if (done == true) {
      icon = Icons.check_circle;
      color = AppColors.success;
    } else if (done == false) {
      icon = Icons.error_outline;
      color = AppColors.warning;
    } else {
      icon = Icons.circle_outlined;
      color = context.textMuted;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12,
              height: 1.4,
              decoration: done == true ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }
}
