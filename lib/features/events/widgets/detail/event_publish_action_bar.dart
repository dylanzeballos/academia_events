// lib/features/events/widgets/detail/event_publish_action_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';
import '../../../../data/services/pagosya_service.dart';
import '../../../../data/services/ticket_service.dart';
import '../../../../providers/events_provider.dart';
import '../../../../shared/widgets/app_confirm_dialog.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../tickets/views/pagosya_checkout_screen.dart';

/// Genera el QR de publicación de un evento y espera la confirmación del pago.
///
/// Devuelve `true` si el pago se confirmó y el backend publicó el evento.
Future<bool> showEventPublicationFlow(
  BuildContext context,
  WidgetRef ref, {
  required String eventId,
  required String eventTitle,
}) async {
  const service = PagosyaService();
  try {
    final price = await service.eventPublicationPrice();
    if (!context.mounted) return false;

    if (price == null || price <= 0) {
      AppFeedback.warning(
        context,
        'La plataforma todavía no configuró el precio de publicación.',
      );
      return false;
    }

    final label = price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2);
    final ok = await showAppConfirm(
      context,
      title: 'Publicar evento',
      message:
          'Se cobrarán BOB $label por publicar "$eventTitle". Después del '
          'pago, el evento se publica automáticamente.',
      confirmLabel: 'Generar QR',
      icon: Icons.qr_code_2,
    );
    if (!ok || !context.mounted) return false;

    final checkout = await service.createPublicationCheckout(
      kind: 'event_publication',
      referenceId: eventId,
      amount: price,
    );
    if (!context.mounted) return false;

    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PagosyaCheckoutScreen(checkout: checkout),
      ),
    );
    if (!context.mounted) return false;

    if (paid == true) {
      ref.invalidate(eventDetailProvider(eventId));
      ref.invalidate(orgEventsProvider);
      ref.invalidate(allEventsProvider);
      ref.invalidate(weekEventsProvider);
      AppFeedback.success(context, 'Pago confirmado. Evento publicado.');
      return true;
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      AppFeedback.error(
        context,
        e is TicketException ? e.message : friendlyError(e),
      );
    }
    return false;
  }
}

/// Acción para publicar un evento borrador desde el detalle.
class EventPublishActionBar extends ConsumerStatefulWidget {
  const EventPublishActionBar({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<EventPublishActionBar> createState() =>
      _EventPublishActionBarState();
}

class _EventPublishActionBarState extends ConsumerState<EventPublishActionBar> {
  bool _busy = false;

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      await showEventPublicationFlow(
        context,
        ref,
        eventId: widget.event.id,
        eventTitle: widget.event.title,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
          child: FilledButton.icon(
            onPressed: _busy ? null : _publish,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Icon(Icons.qr_code_2, size: 20),
            label: Text(
              _busy ? 'Generando QR…' : 'Publicar evento',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
