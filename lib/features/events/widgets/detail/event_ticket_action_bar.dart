// lib/features/events/widgets/detail/event_ticket_action_bar.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';
import '../../../tickets/views/purchase_tickets_screen.dart';

class EventTicketActionBar extends StatelessWidget {
  const EventTicketActionBar({
    super.key,
    required this.event,
  });

  final EventModel event;

  void _navigateToPurchase(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PurchaseTicketsScreen(eventId: event.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startingPrice = event.startingPrice;
    final currency = event.ticketTypes.isNotEmpty ? event.ticketTypes.first.currency : 'BOB';

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          border: Border(top: BorderSide(color: context.divider)),
        ),
        child: Row(
          children: [
            if (startingPrice != null) ...[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Precio', style: TextStyle(color: context.textMuted, fontSize: 11)),
                  Text(
                    startingPrice <= 0 ? 'Gratis' : '$currency ${startingPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToPurchase(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
                icon: const Icon(Icons.confirmation_number_outlined),
                label: const Text('Comprar entrada', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}