/// Datos de asistencia de una clase para el dashboard del organizador
/// (espejo del RPC `fetch_class_attendance`).
class ClassAttendanceData {
  const ClassAttendanceData({
    required this.capacity,
    required this.enrolled,
    required this.sessions,
    required this.students,
    this.classTitle,
    this.price,
    this.currency = 'BOB',
  });

  final int? capacity;
  final int enrolled;
  final List<SessionStats> sessions;
  final List<ClassStudent> students;
  final String? classTitle;
  final double? price;
  final String currency;

  factory ClassAttendanceData.fromJson(Map<String, dynamic> json) {
    return ClassAttendanceData(
      capacity: (json['capacity'] as num?)?.toInt(),
      enrolled: (json['enrolled'] as num?)?.toInt() ?? 0,
      classTitle: json['class_title'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      currency: (json['currency'] as String?)?.trim() ?? 'BOB',
      sessions: [
        for (final s in (json['sessions'] as List? ?? const []))
          SessionStats.fromJson(Map<String, dynamic>.from(s as Map)),
      ],
      students: [
        for (final s in (json['students'] as List? ?? const []))
          ClassStudent.fromJson(Map<String, dynamic>.from(s as Map)),
      ],
    );
  }
}

/// Métricas de una sesión: presentes/tarde/ausentes y pendientes de marcar.
class SessionStats {
  const SessionStats({
    required this.sessionId,
    required this.sessionDate,
    required this.startAt,
    required this.status,
    required this.present,
    required this.late,
    required this.absent,
    required this.pending,
    this.endAt,
  });

  final String sessionId;
  final DateTime sessionDate;
  final DateTime startAt;
  final DateTime? endAt;
  final String status;
  final int present;
  final int late;
  final int absent;
  final int pending;

  int get marked => present + late + absent;
  int get total => marked + pending;

  factory SessionStats.fromJson(Map<String, dynamic> json) {
    return SessionStats(
      sessionId: json['session_id'] as String? ?? '',
      sessionDate: DateTime.tryParse(json['session_date'] as String? ?? '') ??
          DateTime.now(),
      startAt: DateTime.tryParse(json['start_at'] as String? ?? '') ??
          DateTime.now(),
      endAt: json['end_at'] != null
          ? DateTime.tryParse(json['end_at'] as String)
          : null,
      status: json['status'] as String? ?? 'scheduled',
      present: (json['present'] as num?)?.toInt() ?? 0,
      late: (json['late'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Estudiante inscrito con su progreso de asistencia.
class ClassStudent {
  const ClassStudent({
    required this.enrollmentId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.enrollmentStatus,
    required this.sessionsAttended,
    required this.sessionsTotal,
    required this.lastAttendanceStatus,
    required this.lastCheckInTime,
    this.attendance = const [],
  });

  final String enrollmentId;
  final String userId;
  final String firstName;
  final String lastName;
  final String enrollmentStatus;
  final int sessionsAttended;
  final int sessionsTotal;
  final String? lastAttendanceStatus;
  final DateTime? lastCheckInTime;
  final List<StudentSessionAttendance> attendance;

  String get fullName => '$firstName $lastName'.trim();

  /// Número de sesiones efectivamente asistidas (presente o con retraso).
  int get attendedCount => attendance.where((a) => a.isAttended).length;

  factory ClassStudent.fromJson(Map<String, dynamic> json) {
    return ClassStudent(
      enrollmentId: json['enrollment_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      enrollmentStatus: json['enrollment_status'] as String? ?? '',
      sessionsAttended: (json['sessions_attended'] as num?)?.toInt() ?? 0,
      sessionsTotal: (json['sessions_total'] as num?)?.toInt() ?? 0,
      lastAttendanceStatus: json['last_attendance_status'] as String?,
      lastCheckInTime: json['last_check_in_time'] != null
          ? DateTime.tryParse(json['last_check_in_time'] as String)
          : null,
      attendance: [
        for (final a in (json['attendance'] as List? ?? const []))
          StudentSessionAttendance.fromJson(
            Map<String, dynamic>.from(a as Map),
          ),
      ],
    );
  }

  /// Registro de asistencia del estudiante a una sesión concreta.
  StudentSessionAttendance? recordForSession(String sessionId) {
    for (final a in attendance) {
      if (a.sessionId == sessionId) return a;
    }
    return null;
  }
}

/// Asistencia de un estudiante a una sesión concreta de la clase.
class StudentSessionAttendance {
  const StudentSessionAttendance({
    required this.sessionId,
    required this.sessionDate,
    required this.status,
    required this.recordedAt,
  });

  final String sessionId;
  final DateTime sessionDate;
  final String status;
  final DateTime? recordedAt;

  bool get isAttended => status == 'present' || status == 'late';

  factory StudentSessionAttendance.fromJson(Map<String, dynamic> json) {
    return StudentSessionAttendance(
      sessionId: json['session_id'] as String? ?? '',
      sessionDate: DateTime.tryParse(json['session_date'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? '',
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'] as String)
          : null,
    );
  }
}