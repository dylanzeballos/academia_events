import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/event_purchase_result_model.dart';
import '../data/models/event_ticket_group.dart';
import '../data/models/event_ticket_model.dart';
import '../data/models/ticket_type_model.dart';
import '../data/repositories/ticket_repository.dart';

final ticketRepositoryProvider = Provider<ITicketRepository>((ref) {
  return const TicketRepository();
});

final eventTicketTypesProvider =
    FutureProvider.autoDispose.family<List<TicketTypeModel>, String>((ref, eventId) async {
  final repo = ref.watch(ticketRepositoryProvider);
  return repo.fetchTicketTypes(eventId);
});

/// Crea la orden y confirma el pago en un solo paso (simulado).
final purchaseTicketsProvider = FutureProvider.autoDispose
    .family<EventPurchaseResult, ({String ticketTypeId, int quantity})>((ref, args) async {
  final repo = ref.watch(ticketRepositoryProvider);

  final order = await repo.createEventOrder(
    ticketTypeId: args.ticketTypeId,
    quantity: args.quantity,
  );

  return repo.confirmEventOrderPayment(orderId: order.orderId);
});

/// Tickets sin agrupar (lista plana de tickets individuales)
final userEventTicketsProvider = FutureProvider.autoDispose<List<EventTicketModel>>((ref) async {
  final repo = ref.watch(ticketRepositoryProvider);
  return repo.fetchUserEventTickets();
});

/// Tickets agrupados por evento con todos sus códigos QR
final userGroupedTicketsProvider = FutureProvider.autoDispose<List<EventTicketGroup>>((ref) async {
  final repo = ref.watch(ticketRepositoryProvider);
  final rawList = await repo.fetchRawUserEventTickets();

  final Map<String, EventTicketGroup> groups = {};

  for (final row in rawList) {
    final type = row['ticket_types'] as Map<String, dynamic>;
    final event = type['events'] as Map<String, dynamic>;
    final eventId = event['id'] as String;

    final qrToken = (row['qr_data'] as String?) ?? (row['ticket_number'] as String);

    final ticketItem = SingleTicketItem(
      ticketId: row['id'] as String,
      ticketNumber: row['ticket_number'] as String,
      qrToken: qrToken,
    );

    if (!groups.containsKey(eventId)) {
      groups[eventId] = EventTicketGroup(
        eventId: eventId,
        eventTitle: event['title'] as String? ?? 'Evento',
        coverImageUrl: event['cover_image_url'] as String?,
        ticketTypeName: type['name'] as String? ?? 'Entrada General',
        tickets: [ticketItem],
      );
    } else {
      groups[eventId]!.tickets.add(ticketItem);
    }
  }

  return groups.values.toList();
});