import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/models/event_purchase_result_model.dart';

class TicketQrScreen extends StatelessWidget {
  const TicketQrScreen({super.key, required this.result});
  final EventPurchaseResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tus entradas · ${result.eventTitle ?? ""}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: result.tickets.length,
        itemBuilder: (_, i) {
          final ticket = result.tickets[i];
          final attendee = ticket.attendeeName;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Entrada ${i + 1} de ${result.tickets.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (attendee != null && attendee.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.blueAccent),
                        const SizedBox(width: 4),
                        Text(
                          attendee,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  QrImageView(
                    data: ticket.qrToken,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Orden: ${result.orderNumber}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}