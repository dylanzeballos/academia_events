class DanceClassScheduleModel {
  const DanceClassScheduleModel({
    required this.id,
    required this.danceClassId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.instructorId,
    this.instructorName,
    this.startDate,
    this.endDate,
    this.locationOverride,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String danceClassId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? instructorId;
  final String? instructorName;

  /// Inicio de la recurrencia (opcional). Si es nulo, aplica desde el inicio
  /// del período de la clase.
  final DateTime? startDate;

  /// Fin de la recurrencia (opcional). Si es nulo, no tiene fecha de fin.
  final DateTime? endDate;

  /// Ubicación propia del horario (heredada a sus sesiones).
  final Map<String, dynamic>? locationOverride;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get dayName => switch (dayOfWeek) {
        0 => 'Domingo',
        1 => 'Lunes',
        2 => 'Martes',
        3 => 'Miércoles',
        4 => 'Jueves',
        5 => 'Viernes',
        6 => 'Sábado',
        _ => '',
      };

  factory DanceClassScheduleModel.fromJson(Map<String, dynamic> json) {
    final instructorProfile = json['profiles'] as Map<String, dynamic>?;
    final firstName = instructorProfile?['first_name'] as String? ?? '';
    final lastName = instructorProfile?['last_name'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();

    return DanceClassScheduleModel(
      id: json['id'] as String,
      danceClassId: json['dance_class_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      instructorId: json['instructor_id'] as String?,
      instructorName: fullName.isNotEmpty ? fullName : null,
      isActive: (json['is_active'] as bool?) ?? true,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      locationOverride: json['location_override'] as Map<String, dynamic>?,
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
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'instructor_id': instructorId,
        'start_date': startDate?.toIso8601String().split('T')[0],
        'end_date': endDate?.toIso8601String().split('T')[0],
        'location_override': locationOverride,
        'is_active': isActive,
      };
}
