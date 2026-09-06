import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_ticket_model.dart';
import '../../../providers/checkin_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';

class ClassTicketsTab extends ConsumerWidget {
  const ClassTicketsTab({super.key});

  void _showQr(BuildContext context, ClassTicketModel ticket) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ticket.classTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(ticket.validDate),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: ticket.qrToken!,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              const Text(
                'Presenta este código al personal de la academia.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myClassTicketsProvider);

    return ticketsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tickets) {
        if (tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Sin tickets de clases',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Compra un pase de tu clase inscrita para obtener tus tickets.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myClassTicketsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return _TicketCard(
                ticket: ticket,
                onTap: ticket.canShowQr
                    ? () => _showQr(context, ticket)
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime d) {
    return DateFormat('EEE d MMM yyyy', 'es').format(d.toLocal());
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final ClassTicketModel ticket;
  final VoidCallback? onTap;

  static const _statusColors = <String, Color>{
    'issued': AppColors.success,
    'used': Colors.blueGrey,
    'expired': AppColors.warning,
    'cancelled': AppColors.error,
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[ticket.status] ?? Colors.grey;

    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: ListTile(
        onTap: onTap,
        enabled: onTap != null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.calendar_month, color: AppColors.primary),
        ),
        title: Text(
          ticket.classTitle,
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${_formatDate(ticket.validDate)} · ${_formatTime(ticket.sessionStartAt)} - ${_formatTime(ticket.sessionEndAt)}',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ticket.statusDisplayName,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              ticket.canShowQr ? Icons.qr_code_2 : Icons.block,
              size: 20,
              color: ticket.canShowQr ? AppColors.primary : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    return DateFormat('EEE d MMM yyyy', 'es').format(d.toLocal());
  }

  static String _formatTime(DateTime d) {
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}