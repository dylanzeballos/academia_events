import 'dance_class_session_model.dart';

/// Asistencia concreta de un estudiante a una sesión de clase.
///
/// Espeja la tabla `attendances`:
/// (id, enrollment_id, session_id, status, notes, recorded_by, recorded_at,
///  created_at, updated_at). status: present / absent / late.
class AttendanceModel {
  const AttendanceModel({
    required this.id,
    required this.enrollmentId,
    required this.sessionId,
    this.status = 'present',
    this.notes,
    this.recordedBy,
    this.recordedAt,
    this.createdAt,
    this.updatedAt,
    this.session,
  });

  final String id;
  final String enrollmentId;
  final String sessionId;
  final String status;
  final String? notes;
  final String? recordedBy;
  final DateTime? recordedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Sesión anidada opcional (viene de join en consultas).
  final DanceClassSessionModel? session;

  bool get isPresent => status == 'present';
  bool get isLate => status == 'late';

  String get statusDisplayName => switch (status) {
        'present' => 'Presente',
        'absent' => 'Ausente',
        'late' => 'Tarde',
        _ => status,
      };

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    DanceClassSessionModel? session;
    if (json['dance_class_sessions'] != null) {
      session = DanceClassSessionModel.fromJson(
        json['dance_class_sessions'] as Map<String, dynamic>,
      );
    }

    return AttendanceModel(
      id: json['id'] as String,
      enrollmentId: json['enrollment_id'] as String,
      sessionId: json['session_id'] as String,
      status: (json['status'] as String?) ?? 'present',
      notes: json['notes'] as String?,
      recordedBy: json['recorded_by'] as String?,
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      session: session,
    );
  }

  Map<String, dynamic> toJson() => {
        'enrollment_id': enrollmentId,
        'session_id': sessionId,
        'status': status,
        'notes': notes,
        'recorded_by': recordedBy,
      };
}