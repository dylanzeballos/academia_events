/// Datos de asistencia/venta de un evento para el dashboard del organizador
/// (espejo del RPC `fetch_event_attendance`).
class EventAttendanceData {
  const EventAttendanceData({
    required this.capacity,
    required this.ticketsSold,
    required this.ticketsAvailable,
    required this.checkedIn,
    required this.pendingEntry,
    required this.byTicketType,
    required this.attendees,
  });

  final int? capacity;
  final int ticketsSold;
  final int? ticketsAvailable;
  final int checkedIn;
  final int pendingEntry;
  final List<TicketTypeStats> byTicketType;
  final List<EventAttendee> attendees;

  factory EventAttendanceData.fromJson(Map<String, dynamic> json) {
    return EventAttendanceData(
      capacity: (json['capacity'] as num?)?.toInt(),
      ticketsSold: (json['tickets_sold'] as num?)?.toInt() ?? 0,
      ticketsAvailable: (json['tickets_available'] as num?)?.toInt(),
      checkedIn: (json['checked_in'] as num?)?.toInt() ?? 0,
      pendingEntry: (json['pending_entry'] as num?)?.toInt() ?? 0,
      byTicketType: [
        for (final t in (json['by_ticket_type'] as List? ?? const []))
          TicketTypeStats.fromJson(Map<String, dynamic>.from(t as Map)),
      ],
      attendees: [
        for (final a in (json['attendees'] as List? ?? const []))
          EventAttendee.fromJson(Map<String, dynamic>.from(a as Map)),
      ],
    );
  }
}

/// Ventas y check-ins por tipo de entrada.
class TicketTypeStats {
  const TicketTypeStats({
    required this.name,
    required this.sold,
    required this.checkedIn,
  });

  final String name;
  final int sold;
  final int checkedIn;

  factory TicketTypeStats.fromJson(Map<String, dynamic> json) {
    return TicketTypeStats(
      name: json['name'] as String? ?? '',
      sold: (json['sold'] as num?)?.toInt() ?? 0,
      checkedIn: (json['checked_in'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Un asistente (comprador) con su ticket y estado de ingreso.
class EventAttendee {
  const EventAttendee({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.ticketNumber,
    required this.ticketType,
    required this.ticketStatus,
    required this.checkedIn,
    required this.checkInTime,
    required this.accessPoint,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String ticketNumber;
  final String ticketType;
  final String ticketStatus;
  final bool checkedIn;
  final DateTime? checkInTime;
  final String? accessPoint;

  String get fullName => '$firstName $lastName'.trim();

  factory EventAttendee.fromJson(Map<String, dynamic> json) {
    return EventAttendee(
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      ticketNumber: json['ticket_number'] as String? ?? '',
      ticketType: json['ticket_type'] as String? ?? '',
      ticketStatus: json['ticket_status'] as String? ?? 'active',
      checkedIn: json['checked_in'] as bool? ?? false,
      checkInTime: json['check_in_time'] != null
          ? DateTime.tryParse(json['check_in_time'] as String)
          : null,
      accessPoint: json['access_point'] as String?,
    );
  }
}