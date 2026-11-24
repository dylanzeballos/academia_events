/// Resultado de un intento de check-in (evento o clase).
/// El frontend solo muestra el resultado: toda la validación ocurre en el
/// servidor (RPC `register_event_check_in` / `register_class_check_in`).
class CheckInResultModel {
  const CheckInResultModel({
    required this.success,
    this.reason,
    this.ticketNumber,
    this.eventTitle,
    this.classTitle,
    this.sessionDate,
    this.attendeeName,
    this.checkedInAt,
  });

  final bool success;

  /// Motivo de rechazo cuando `success` es false (mensaje del servidor).
  final String? reason;

  // Campos presentes en un check-in exitoso.
  final String? ticketNumber;
  final String? eventTitle;
  final String? classTitle;
  final DateTime? sessionDate;
  final String? attendeeName;
  final DateTime? checkedInAt;

  bool get isEvent => eventTitle != null;
  bool get isClass => classTitle != null;

  factory CheckInResultModel.fromJson(Map<String, dynamic> json) {
    return CheckInResultModel(
      success: (json['success'] as bool?) ?? false,
      reason: json['reason'] as String?,
      ticketNumber: json['ticket_number'] as String?,
      eventTitle: json['event_title'] as String?,
      classTitle: json['class_title'] as String?,
      sessionDate: json['session_date'] != null
          ? DateTime.tryParse(json['session_date'] as String)
          : null,
      attendeeName: json['attendee_name'] as String?,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.tryParse(json['checked_in_at'] as String)
          : null,
    );
  }
}