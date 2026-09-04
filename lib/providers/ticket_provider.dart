import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/event_purchase_result_model.dart';
import '../data/models/ticket_type_model.dart';
import '../data/repositories/ticket_repository.dart';
import '../data/models/event_ticket_model.dart';

final ticketRepositoryProvider = Provider<ITicketRepository>((ref) {
  return const TicketRepository();
});

final eventTicketTypesProvider =
    FutureProvider.autoDispose.family<List<TicketTypeModel>, String>((ref, eventId) async {
  final repo = ref.watch(ticketRepositoryProvider);
  return repo.fetchTicketTypes(eventId);
});

/// Crea la orden y confirma el pago en un solo paso (simulado por ahora).
/// Cuando tengas la API del banco, este es el único lugar que cambia:
/// en vez de confirmar acá, esperás el webhook y hacés polling/realtime
/// sobre `orders.status` hasta que sea 'paid'.
final purchaseTicketsProvider = FutureProvider.autoDispose
    .family<EventPurchaseResult, ({String ticketTypeId, int quantity})>((ref, args) async {
  final repo = ref.watch(ticketRepositoryProvider);

  final order = await repo.createEventOrder(
    ticketTypeId: args.ticketTypeId,
    quantity: args.quantity,
  );

  return repo.confirmEventOrderPayment(orderId: order.orderId);
});

/// Tickets ya comprados por el usuario (para "Mis Tickets")
final userEventTicketsProvider = FutureProvider.autoDispose<List<EventTicketModel>>((ref) async {
  final repo = ref.watch(ticketRepositoryProvider);
  return repo.fetchUserEventTickets();
});