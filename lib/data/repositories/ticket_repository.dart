import '../models/event_order_model.dart';
import '../models/event_purchase_result_model.dart';
import '../models/event_ticket_model.dart';
import '../models/ticket_type_model.dart';
import '../services/ticket_service.dart';

abstract interface class ITicketRepository {
  Future<List<TicketTypeModel>> fetchTicketTypes(String eventId);

  Future<EventOrderModel> createEventOrder({
    required String ticketTypeId,
    required int quantity,
  });

  Future<EventPurchaseResult> confirmEventOrderPayment({
    required String orderId,
    String provider = 'simulated',
    String? providerPaymentId,
  });

  /// Atajo: crea la orden y confirma el pago en un solo llamado (simulado).
  Future<EventPurchaseResult> purchaseEventTickets({
    required String ticketTypeId,
    required int quantity,
  });

  Future<List<EventTicketModel>> fetchUserEventTickets();
}

class TicketRepository implements ITicketRepository {
  const TicketRepository({TicketService? service})
      : _service = service ?? const TicketService();

  final TicketService _service;

  @override
  Future<List<TicketTypeModel>> fetchTicketTypes(String eventId) async {
    final rows = await _service.fetchTicketTypes(eventId);
    return rows.map((row) => TicketTypeModel.fromJson(row)).toList();
  }

  @override
  Future<EventOrderModel> createEventOrder({
    required String ticketTypeId,
    required int quantity,
  }) async {
    final raw = await _service.createEventOrder(
      ticketTypeId: ticketTypeId,
      quantity: quantity,
    );
    return EventOrderModel.fromJson(raw);
  }

  @override
  Future<EventPurchaseResult> confirmEventOrderPayment({
    required String orderId,
    String provider = 'simulated',
    String? providerPaymentId,
  }) async {
    final raw = await _service.confirmEventOrderPayment(
      orderId: orderId,
      provider: provider,
      providerPaymentId: providerPaymentId,
    );
    return EventPurchaseResult.fromJson(raw);
  }

  @override
  Future<EventPurchaseResult> purchaseEventTickets({
    required String ticketTypeId,
    required int quantity,
  }) async {
    final order = await createEventOrder(ticketTypeId: ticketTypeId, quantity: quantity);
    return confirmEventOrderPayment(orderId: order.orderId);
  }

  @override
  Future<List<EventTicketModel>> fetchUserEventTickets() async {
    final rows = await _service.fetchUserEventTickets();
    return rows.map((row) => EventTicketModel.fromJson(row)).toList();
  }
}