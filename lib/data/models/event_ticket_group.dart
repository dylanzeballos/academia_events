class SingleTicketItem {
  final String ticketId;
  final String ticketNumber;
  final String qrToken;
  final String? attendeeName; // <-- Campo añadido

  SingleTicketItem({
    required this.ticketId,
    required this.ticketNumber,
    required this.qrToken,
    this.attendeeName,         // <-- Opcional para admitir tickets sin nombre
  });
}

class OrderPurchaseItem {
  final String orderId;
  final String orderNumber;
  final DateTime purchaseDate;
  final String ticketTypeName;
  final List<SingleTicketItem> tickets;

  OrderPurchaseItem({
    required this.orderId,
    required this.orderNumber,
    required this.purchaseDate,
    required this.ticketTypeName,
    required this.tickets,
  });

  int get totalTickets => tickets.length;
}

class EventGroupWithOrders {
  final String eventId;
  final String eventTitle;
  final String? coverImageUrl;
  final DateTime? eventStartAt;
  final List<OrderPurchaseItem> orders;

  EventGroupWithOrders({
    required this.eventId,
    required this.eventTitle,
    this.coverImageUrl,
    this.eventStartAt,
    required this.orders,
  });

  int get totalEventTickets =>
      orders.fold(0, (acc, order) => acc + order.totalTickets);
}