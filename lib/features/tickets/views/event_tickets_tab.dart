import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/ticket_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';

class EventTicketsTab extends ConsumerWidget {
  const EventTicketsTab({super.key});

  void _showQr(BuildContext context, String eventTitle, String qrData) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(eventTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              QrImageView(data: qrData, size: 220, backgroundColor: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(userEventTicketsProvider);

    return ticketsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tickets) {
        if (tickets.isEmpty) {
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
                  'Aún no has comprado ni reservado tickets para eventos.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(userEventTicketsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return Card(
                color: context.cardBg,
                child: ListTile(
                  title: Text(ticket.eventTitle),
                  subtitle: Text('${ticket.ticketTypeName} · ${ticket.ticketNumber}'),
                  trailing: const Icon(Icons.qr_code_2, color: AppColors.primary),
                  onTap: ticket.qrData == null
                      ? null
                      : () => _showQr(context, ticket.eventTitle, ticket.qrData!),
                ),
              );
            },
          ),
        );
      },
    );
  }
}