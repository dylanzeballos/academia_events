class DanceClassScheduleModel {
  const DanceClassScheduleModel({
    required this.id,
    required this.danceClassId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.instructorId,
    this.instructorName,
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
        'is_active': isActive,
      };
}
