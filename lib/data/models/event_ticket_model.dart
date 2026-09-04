class EventTicketModel {
  const EventTicketModel({
    required this.id,
    required this.ticketNumber,
    required this.status,
    required this.qrData,
    required this.eventTitle,
    required this.eventCoverImageUrl,
    required this.eventStartAt,
    required this.ticketTypeName,
  });

  final String id;
  final String ticketNumber;
  final String status;
  final String? qrData;
  final String eventTitle;
  final String? eventCoverImageUrl;
  final DateTime eventStartAt;
  final String ticketTypeName;

  factory EventTicketModel.fromJson(Map<String, dynamic> json) {
    final ticketType = json['ticket_types'] as Map<String, dynamic>;
    final event = ticketType['events'] as Map<String, dynamic>;
    return EventTicketModel(
      id: json['id'] as String,
      ticketNumber: json['ticket_number'] as String,
      status: json['status'] as String,
      qrData: json['qr_data'] as String?,
      eventTitle: event['title'] as String,
      eventCoverImageUrl: event['cover_image_url'] as String?,
      eventStartAt: DateTime.parse(event['start_at'] as String),
      ticketTypeName: ticketType['name'] as String,
    );
  }
}