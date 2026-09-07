import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/event_ticket_group.dart';
import '../utils/ticket_share_helper.dart';
import '../widgets/event_ticket_pass_card.dart';

class EventOrdersDetailScreen extends StatelessWidget {
  const EventOrdersDetailScreen({super.key, required this.eventGroup});

  final EventGroupWithOrders eventGroup;

  String _formatPurchaseTime(DateTime dt) {
    return DateFormat("d MMM y, HH:mm", 'es').format(dt);
  }

  void _showOrderQrs(BuildContext context, OrderPurchaseItem order) {
    // Mapa de controladores independientes por ticket para evitar colisiones al deslizar
    final Map<String, ScreenshotController> screenshotControllers = {
      for (final ticket in order.tickets) ticket.ticketId: ScreenshotController(),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        int currentIndex = 0;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentTicket = order.tickets[currentIndex];
            final activeController = screenshotControllers[currentTicket.ticketId]!;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        eventGroup.eventTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.ticketTypeName} · ${order.totalTickets} ${order.totalTickets == 1 ? "entrada" : "entradas"}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),

                      // Carrusel de pases completos con altura estable
                      SizedBox(
                        height: 390,
                        child: PageView.builder(
                          key: PageStorageKey('order_carousel_${order.orderId}'),
                          itemCount: order.tickets.length,
                          onPageChanged: (i) => setModalState(() => currentIndex = i),
                          itemBuilder: (context, i) {
                            final item = order.tickets[i];
                            final controller = screenshotControllers[item.ticketId]!;

                            return Center(
                              key: ValueKey(item.ticketId),
                              child: Screenshot(
                                controller: controller,
                                child: EventTicketPassCard(
                                  key: ValueKey('card_${item.ticketNumber}'),
                                  eventTitle: eventGroup.eventTitle,
                                  ticketTypeName: order.ticketTypeName,
                                  ticketNumber: item.ticketNumber,
                                  qrToken: item.qrToken,
                                  eventStartAt: eventGroup.eventStartAt,
                                  purchaseDate: order.purchaseDate,
                                  attendeeName: item.attendeeName, // <-- Nombre del asistente conectado
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      if (order.totalTickets > 1) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Entrada ${currentIndex + 1} de ${order.totalTickets} (Desliza para ver las demás)',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Botón para compartir pase completo
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.share),
                        label: Text(
                          order.totalTickets > 1
                              ? 'Compartir esta entrada (${currentIndex + 1}/${order.totalTickets})'
                              : 'Enviar entrada por WhatsApp / Guardar',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          TicketShareHelper.shareTicketImage(
                            context: context,
                            screenshotController: activeController,
                            ticketNumber: currentTicket.ticketNumber,
                            eventTitle: eventGroup.eventTitle,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(eventGroup.eventTitle),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: eventGroup.orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final order = eventGroup.orders[index];

          return InkWell(
            onTap: () => _showOrderQrs(context, order),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.ticketTypeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${order.totalTickets} ${order.totalTickets == 1 ? "QR" : "QRs"}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.access_time_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Comprado a las: ${_formatPurchaseTime(order.purchaseDate)}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const Spacer(),
                      const Icon(Icons.qr_code_2, color: AppColors.primary, size: 24),
                    ],
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