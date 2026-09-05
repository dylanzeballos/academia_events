class SingleTicketItem {
  final String ticketId;
  final String ticketNumber;
  final String qrToken;

  SingleTicketItem({
    required this.ticketId,
    required this.ticketNumber,
    required this.qrToken,
  });
}

class EventTicketGroup {
  final String eventId;
  final String eventTitle;
  final String? coverImageUrl;
  final String ticketTypeName;
  final List<SingleTicketItem> tickets;

  EventTicketGroup({
    required this.eventId,
    required this.eventTitle,
    this.coverImageUrl,
    required this.ticketTypeName,
    required this.tickets,
  });

  int get totalTickets => tickets.length;
}