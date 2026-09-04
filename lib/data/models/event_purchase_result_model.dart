class PurchasedTicketQr {
  const PurchasedTicketQr({required this.ticketId, required this.qrToken});
  final String ticketId;
  final String qrToken;

  factory PurchasedTicketQr.fromJson(Map<String, dynamic> json) => PurchasedTicketQr(
        ticketId: json['ticket_id'] as String,
        qrToken: json['qr_token'] as String,
      );
}

class EventPurchaseResult {
  const EventPurchaseResult({
    required this.orderId,
    required this.orderNumber,
    required this.quantity,
    required this.subtotal,
    required this.tickets,
    this.eventTitle,
  });

  final String orderId;
  final String orderNumber;
  final int quantity;
  final double subtotal;
  final List<PurchasedTicketQr> tickets;
  final String? eventTitle;

  factory EventPurchaseResult.fromJson(Map<String, dynamic> json) => EventPurchaseResult(
        orderId: json['order_id'] as String,
        orderNumber: json['order_number'] as String,
        quantity: json['quantity'] as int,
        subtotal: (json['subtotal'] as num).toDouble(),
        eventTitle: json['event_title'] as String?,
        tickets: (json['tickets'] as List)
            .map((t) => PurchasedTicketQr.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
      );
}