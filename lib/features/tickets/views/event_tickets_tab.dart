import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/ticket_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../data/models/event_ticket_group.dart';

class EventTicketsTab extends ConsumerWidget {
  const EventTicketsTab({super.key});

  void _showQrsModal(BuildContext context, EventTicketGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  group.eventTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '${group.ticketTypeName} · ${group.totalTickets} ${group.totalTickets == 1 ? "entrada" : "entradas"}',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),

                // Carrusel horizontal para ver cada uno de los QRs comprados
                SizedBox(
                  height: 320,
                  child: PageView.builder(
                    itemCount: group.tickets.length,
                    itemBuilder: (context, i) {
                      final item = group.tickets[i];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 8),
                              ],
                            ),
                            child: QrImageView(
                              data: item.qrToken,
                              size: 200,
                              version: QrVersions.auto,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.ticketNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Entrada ${i + 1} de ${group.totalTickets}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                if (group.totalTickets > 1)
                  const Text(
                    '← Desliza para ver la siguiente entrada →',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(userGroupedTicketsProvider);

    return ticketsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (groups) {
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Sin tickets de eventos',
                  style: TextStyle(color: context.textOnBg, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aún no has comprado ni reservado tickets.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(userGroupedTicketsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                color: context.cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.event, color: Colors.white),
                  ),
                  title: Text(
                    group.eventTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${group.ticketTypeName} · ${group.totalTickets} ${group.totalTickets == 1 ? "ticket" : "tickets"}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${group.totalTickets} QRs',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.qr_code_2, color: AppColors.primary, size: 28),
                    ],
                  ),
                  onTap: () => _showQrsModal(context, group),
                ),
              );
            },
          ),
        );
      },
    );
  }
}