// lib/features/tickets/views/event_orders_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
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
    final Map<String, ScreenshotController> screenshotControllers = {
      for (final ticket in order.tickets) ticket.ticketId: ScreenshotController(),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLarge)),
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
                          color: context.textMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        eventGroup.eventTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.ticketTypeName} · ${order.totalTickets} ${order.totalTickets == 1 ? "entrada" : "entradas"}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

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
                                  attendeeName: item.attendeeName,
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
                          style: TextStyle(color: context.textMuted, fontSize: 12),
                        ),
                      ],

                      const SizedBox(height: 16),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.onSecondary,
                          minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
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
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          eventGroup.eventTitle,
          style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: eventGroup.orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final order = eventGroup.orders[index];

          return InkWell(
            onTap: () => _showOrderQrs(context, order),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(color: context.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.ticketTypeName,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
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
                      Icon(Icons.access_time_outlined, size: 16, color: context.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Comprado a las: ${_formatPurchaseTime(order.purchaseDate)}',
                        style: TextStyle(fontSize: 13, color: context.textMuted),
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