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

final userGroupedTicketsProvider = FutureProvider.autoDispose<List<EventGroupWithOrders>>((ref) async {
  final repo = ref.watch(ticketRepositoryProvider);
  final rawList = await repo.fetchRawUserEventTickets();

  final Map<String, EventGroupWithOrders> eventMap = {};
  final Map<String, Map<String, OrderPurchaseItem>> orderMapByEvent = {};

  for (final row in rawList) {
    final type = row['ticket_types'] as Map<String, dynamic>;
    final event = type['events'] as Map<String, dynamic>;
    final eventId = event['id'] as String;

    // Si order_id viene nulo, agrupamos por el minuto exacto de creación del lote
    final rawCreatedAt = row['created_at'] as String? ?? '';
    final minuteBatch = rawCreatedAt.length >= 16 ? rawCreatedAt.substring(0, 16) : rawCreatedAt;
    final orderKey = (row['order_id'] as String?) ?? 'batch_$minuteBatch';

    final qrToken = (row['qr_data'] as String?) ?? (row['ticket_number'] as String);
    final ticketItem = SingleTicketItem(
      ticketId: row['id'] as String,
      ticketNumber: row['ticket_number'] as String,
      qrToken: qrToken,
    );

    // 1. Inicializar contenedor del Evento
    if (!eventMap.containsKey(eventId)) {
      eventMap[eventId] = EventGroupWithOrders(
        eventId: eventId,
        eventTitle: event['title'] as String? ?? 'Evento',
        coverImageUrl: event['cover_image_url'] as String?,
        eventStartAt: event['start_at'] != null ? DateTime.tryParse(event['start_at']) : null,
        orders: [],
      );
      orderMapByEvent[eventId] = {};
    }

    // 2. Inicializar la Orden dentro del Evento o agregar el ticket al lote
    final eventOrders = orderMapByEvent[eventId]!;
    if (!eventOrders.containsKey(orderKey)) {
      eventOrders[orderKey] = OrderPurchaseItem(
        orderId: orderKey,
        orderNumber: (row['ticket_number'] as String? ?? '').split('-').first,
        purchaseDate: DateTime.tryParse(rawCreatedAt)?.toLocal() ?? DateTime.now(),
        ticketTypeName: type['name'] as String? ?? 'Entrada General',
        tickets: [ticketItem],
      );
    } else {
      eventOrders[orderKey]!.tickets.add(ticketItem);
    }
  }

  // Asignar las órdenes ordenadas cronológicamente a cada evento
  for (final eventId in eventMap.keys) {
    final ordersList = orderMapByEvent[eventId]!.values.toList();
    ordersList.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    eventMap[eventId]!.orders.addAll(ordersList);
  }

  return eventMap.values.toList();
});