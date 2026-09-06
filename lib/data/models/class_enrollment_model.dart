/// Inscripción de un usuario a una clase de baile.
///
/// Espeja la tabla `class_enrollments` del proyecto:
/// (id, dance_class_id, user_id, status, enrolled_at, cancelled_at,
///  created_at, updated_at). El enum `enrollment_status` de la BD es:
/// pending / approved / active / cancelled / rejected / completed.
class ClassEnrollmentModel {
  const ClassEnrollmentModel({
    required this.id,
    required this.danceClassId,
    required this.userId,
    this.status = 'pending',
    this.enrolledAt,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
    this.classTitle,
    this.classCoverImageUrl,
    this.organizationId,
    this.organizationName,
    this.instructorName,
  });

  final String id;
  final String danceClassId;
  final String userId;
  final String status;
  final DateTime? enrolledAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Datos anidados opcionales (vienen de joins en consultas).
  final String? classTitle;
  final String? classCoverImageUrl;
  final String? organizationId;
  final String? organizationName;
  final String? instructorName;

  bool get isActive =>
      status == 'pending' || status == 'approved' || status == 'active';
  bool get isCancelled => status == 'cancelled';

  String get statusDisplayName => switch (status) {
        'pending' => 'Pendiente',
        'approved' => 'Aprobada',
        'active' => 'Activa',
        'cancelled' => 'Cancelada',
        'rejected' => 'Rechazada',
        'completed' => 'Completada',
        _ => status,
      };

  factory ClassEnrollmentModel.fromJson(Map<String, dynamic> json) {
    final danceClass = json['dance_classes'] as Map<String, dynamic>?;
    final organization = (danceClass?['organizations'] as Map<String, dynamic>?) ??
        (json['organizations'] as Map<String, dynamic>?);

    var instructorName = json['instructor_name'] as String?;
    final instructorProfile = json['profiles'] as Map<String, dynamic>?;
    if (instructorName == null && instructorProfile != null) {
      final first = instructorProfile['first_name'] as String? ?? '';
      final last = instructorProfile['last_name'] as String? ?? '';
      instructorName = '$first $last'.trim();
      if (instructorName.isEmpty) instructorName = null;
    }

    return ClassEnrollmentModel(
      id: json['id'] as String,
      danceClassId: json['dance_class_id'] as String,
      userId: json['user_id'] as String,
      status: (json['status'] as String?) ?? 'pending',
      enrolledAt: json['enrolled_at'] != null
          ? DateTime.tryParse(json['enrolled_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      classTitle: danceClass?['title'] as String? ?? json['class_title'] as String?,
      classCoverImageUrl:
          danceClass?['cover_image_url'] as String? ?? json['class_cover_image_url'] as String?,
      organizationId:
          organization?['id'] as String? ?? json['organization_id'] as String?,
      organizationName:
          organization?['name'] as String? ?? json['organization_name'] as String?,
      instructorName: instructorName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dance_class_id': danceClassId,
        'user_id': userId,
        'status': status,
        'enrolled_at': enrolledAt?.toIso8601String(),
        'cancelled_at': cancelledAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}