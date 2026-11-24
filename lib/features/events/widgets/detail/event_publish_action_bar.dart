// lib/features/events/widgets/detail/event_publish_action_bar.dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';

/// Estado informativo para eventos creados como borrador.
///
/// La publicación ya no se hace desde la app: requiere el pago del QR de
/// publicación que genera el administrador de plataforma. Cuando el pago se
/// confirma, el backend publica el evento automáticamente.
class EventPublishActionBar extends StatelessWidget {
  const EventPublishActionBar({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          border: Border(top: BorderSide(color: context.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lock_clock_outlined,
              color: AppColors.warning,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Publicación pendiente',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Para publicar este evento se requiere una suscripción '
                    'mensual activa de la organización y el pago del QR de '
                    'publicación. Aparecerá automáticamente al confirmarse.',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
