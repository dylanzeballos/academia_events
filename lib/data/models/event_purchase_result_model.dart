class PurchasedTicketQr {
  const PurchasedTicketQr({required this.ticketId, required this.qrToken});
  final String ticketId;
  final String qrToken;

  factory PurchasedTicketQr.fromJson(Map<String, dynamic> json) =>
      PurchasedTicketQr(
        ticketId: json['ticket_id'] as String? ?? '',
        qrToken: json['qr_token'] as String? ?? '',
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

  factory EventPurchaseResult.fromJson(Map<String, dynamic> json) {
    final ticketsList = (json['tickets'] as List<dynamic>? ?? [])
        .map(
          (t) => PurchasedTicketQr.fromJson(
            Map<String, dynamic>.from(t as Map),
          ),
        )
        .toList();

    return EventPurchaseResult(
      orderId: json['order_id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? ticketsList.length,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 
                (json['total_amount'] as num?)?.toDouble() ?? 
                0.0,
      eventTitle: json['event_title'] as String?,
      tickets: ticketsList,
    );
  }
}