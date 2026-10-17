// lib/feature/public/tickets/views/ticket_qr_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/data/models/event_purchase_result_model.dart';

class TicketQrScreen extends StatelessWidget {
  const TicketQrScreen({super.key, required this.result});
  final EventPurchaseResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text('Tus entradas · ${result.eventTitle ?? ""}'),
        backgroundColor: context.scaffoldBg,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: result.tickets.length,
        itemBuilder: (_, i) {
          final ticket = result.tickets[i];
          final attendee = ticket.attendeeName;

          return Card(
            color: context.cardBg,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              side: BorderSide(color: context.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Entrada ${i + 1} de ${result.tickets.length}',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (attendee != null && attendee.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          attendee,
                          style: TextStyle(
                            color: context.textOnBg,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: ticket.qrToken,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Orden: ${result.orderNumber}',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 12,
                    ),
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