import 'package:flutter/material.dart';

import '../../tickets/views/purchase_tickets_screen.dart';

/// Barra inferior flotante encargada de iniciar el flujo de compra de tickets.
class EventTicketActionBar extends StatelessWidget {
  const EventTicketActionBar({
    super.key,
    required this.eventId,
    this.buttonText = 'Comprar entrada',
  });

  final String eventId;
  final String buttonText;

  void _navigateToPurchase(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PurchaseTicketsScreen(eventId: eventId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () => _navigateToPurchase(context),
          icon: const Icon(Icons.confirmation_number_outlined),
          label: Text(buttonText),
        ),
      ),
    );
  }
}