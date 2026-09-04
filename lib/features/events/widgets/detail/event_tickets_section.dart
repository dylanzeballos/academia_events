// lib/features/events/widgets/event_tickets_section.dart

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';

class EventTicketsSection extends StatelessWidget {
  const EventTicketsSection({
    super.key,
    required this.event,
    required this.accentColor,
  });

  final EventModel event;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (event.ticketTypes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Entradas disponibles',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: event.ticketTypes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, index) {
            final ticket = event.ticketTypes[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(color: context.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.name,
                          style: TextStyle(
                            color: context.textOnBg,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (ticket.description != null && ticket.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            ticket.description!,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          ticket.isSoldOut
                              ? 'Agotado'
                              : 'Disponibles: ${ticket.availableQuantity}',
                          style: TextStyle(
                            color: ticket.isSoldOut ? Colors.red : Colors.grey,
                            fontSize: 11,
                            fontWeight: ticket.isSoldOut ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${ticket.price <= 0 ? "Gratis" : "${ticket.currency} ${ticket.price.toStringAsFixed(2)}"}',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}