// lib/features/events/widgets/event_ticket_action_bar.dart

import 'package:flutter/material.dart';

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
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            if (startingPrice != null) ...[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Precio', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(
                    startingPrice <= 0 ? 'Gratis' : '$currency ${startingPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToPurchase(context),
                icon: const Icon(Icons.confirmation_number_outlined),
                label: const Text('Comprar entrada'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}