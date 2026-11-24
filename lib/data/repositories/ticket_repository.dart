import '../models/event_order_model.dart';
import '../models/event_purchase_result_model.dart';
import '../models/event_ticket_model.dart';
import '../models/pagosya_checkout_model.dart';
import '../models/ticket_type_model.dart';
import '../services/pagosya_service.dart';
import '../services/ticket_service.dart';

abstract interface class ITicketRepository {
  Future<List<TicketTypeModel>> fetchTicketTypes(String eventId);

  Future<EventOrderModel> createEventOrder({
    required String ticketTypeId,
    required int quantity,
    List<String>? attendeeNames,
  });

  /// Genera el checkout de PagosYa para una orden pendiente.
  Future<PagosyaCheckout> createPagosyaCheckout({
    required String orderId,
    List<String>? seatIds,
  });

  /// Consulta el estado del pago (webhook + reconciliación).
  Future<PagosyaCheckoutStatus> refreshCheckout(String orderId);

  /// Entradas + tokens QR de una orden ya pagada.
  Future<EventPurchaseResult> fetchOrderTickets(String orderId);

  Future<List<EventTicketModel>> fetchUserEventTickets();

  /// Obtiene los datos crudos con los tokens QR incluidos para agrupar en el Provider
  Future<List<Map<String, dynamic>>> fetchRawUserEventTickets();
}

class TicketRepository implements ITicketRepository {
  const TicketRepository({TicketService? service, PagosyaService? pagosya})
    : _service = service ?? const TicketService(),
      _pagosya = pagosya ?? const PagosyaService();

  final TicketService _service;
  final PagosyaService _pagosya;

  @override
  Future<List<TicketTypeModel>> fetchTicketTypes(String eventId) async {
    final rows = await _service.fetchTicketTypes(eventId);
    return rows.map((row) => TicketTypeModel.fromJson(row)).toList();
  }

  @override
  Future<EventOrderModel> createEventOrder({
    required String ticketTypeId,
    required int quantity,
    List<String>? attendeeNames,
  }) async {
    final raw = await _service.createEventOrder(
      ticketTypeId: ticketTypeId,
      quantity: quantity,
      attendeeNames: attendeeNames,
    );
    return EventOrderModel.fromJson(raw);
  }

  @override
  Future<PagosyaCheckout> createPagosyaCheckout({
    required String orderId,
    List<String>? seatIds,
  }) {
    return _pagosya.createCheckout(
      kind: 'ticket',
      referenceId: orderId,
      seatIds: seatIds,
    );
  }

  @override
  Future<PagosyaCheckoutStatus> refreshCheckout(String orderId) {
    return _pagosya.refreshCheckout(orderId: orderId);
  }

  @override
  Future<EventPurchaseResult> fetchOrderTickets(String orderId) {
    return _pagosya.fetchOrderTickets(orderId);
  }

  @override
  Future<List<EventTicketModel>> fetchUserEventTickets() async {
    final rows = await _service.fetchUserEventTickets();
    return rows.map((row) => EventTicketModel.fromJson(row)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRawUserEventTickets() {
    return _service.fetchUserEventTickets();
  }
}
