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
    List<String>? attendeeNames,
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
    List<String>? attendeeNames,
  });

  Future<List<EventTicketModel>> fetchUserEventTickets();

  /// Obtiene los datos crudos con los tokens QR incluidos para agrupar en el Provider
  Future<List<Map<String, dynamic>>> fetchRawUserEventTickets();
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
    List<String>? attendeeNames,
  }) async {
    // 1. Llamar al servicio directamente para obtener el mapa sin riesgo de fallo en EventOrderModel
    final rawOrder = await _service.createEventOrder(
      ticketTypeId: ticketTypeId,
      quantity: quantity,
      attendeeNames: attendeeNames,
    );

    // 2. Extraer el orderId tolerando cualquier nombre de clave ('order_id' o 'id')
    final orderId = (rawOrder['order_id'] ?? rawOrder['id'] ?? '')?.toString();
    if (orderId == null || orderId.isEmpty) {
      throw const TicketException('No se pudo obtener el ID de la orden generada');
    }

    // 3. Confirmar pago simulado
    return confirmEventOrderPayment(orderId: orderId);
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