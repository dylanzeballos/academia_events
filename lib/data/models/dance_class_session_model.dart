class DanceClassSessionModel {
  const DanceClassSessionModel({
    required this.id,
    required this.danceClassId,
    required this.sessionDate,
    required this.startAt,
    required this.endAt,
    this.scheduleId,
    this.status = 'scheduled',
    this.locationOverride,
    this.cancelledReason,
    this.isCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String danceClassId;
  final DateTime sessionDate;
  final DateTime startAt;
  final DateTime endAt;
  final String? scheduleId;
  final String status;
  final Map<String, dynamic>? locationOverride;
  final String? cancelledReason;
  final bool isCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isScheduled => status == 'scheduled';
  bool get isCancelled => status == 'cancelled';
  bool get isCompletedStatus => status == 'completed';

  String get statusDisplayName => switch (status) {
        'scheduled' => 'Programada',
        'cancelled' => 'Cancelada',
        'completed' => 'Completada',
        'rescheduled' => 'Reprogramada',
        _ => status,
      };

  factory DanceClassSessionModel.fromJson(Map<String, dynamic> json) {
    return DanceClassSessionModel(
      id: json['id'] as String,
      danceClassId: json['dance_class_id'] as String,
      sessionDate: DateTime.parse(json['session_date'] as String),
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      scheduleId: json['schedule_id'] as String?,
      status: (json['status'] as String?) ?? 'scheduled',
      locationOverride: json['location_override'] as Map<String, dynamic>?,
      cancelledReason: json['cancelled_reason'] as String?,
      isCompleted: (json['is_completed'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'dance_class_id': danceClassId,
        'session_date': sessionDate.toIso8601String().split('T')[0],
        'start_at': startAt.toIso8601String(),
        'end_at': endAt.toIso8601String(),
        'schedule_id': scheduleId,
        'status': status,
        'location_override': locationOverride,
        'cancelled_reason': cancelledReason,
        'is_completed': isCompleted,
      };
}
