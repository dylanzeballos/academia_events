/// Datos del informe VIP mensual (espejo del RPC `fetch_org_vip_attendance`).
///
/// Un alumno es VIP si tiene un pase de clase activo vigente en el mes. El
/// informe cruza a los alumnos VIP con las clases incluidas del mes.
class VipAttendanceData {
  const VipAttendanceData({
    required this.monthStart,
    required this.classes,
    required this.students,
    required this.marks,
  });

  final DateTime monthStart;
  final List<VipClass> classes;
  final List<VipStudent> students;
  final List<VipMark> marks;

  factory VipAttendanceData.fromJson(Map<String, dynamic> json) {
    return VipAttendanceData(
      monthStart: DateTime.tryParse(json['month_start'] as String? ?? '') ??
          DateTime.now(),
      classes: [
        for (final c in (json['classes'] as List? ?? const []))
          VipClass.fromJson(Map<String, dynamic>.from(c as Map)),
      ],
      students: [
        for (final s in (json['students'] as List? ?? const []))
          VipStudent.fromJson(Map<String, dynamic>.from(s as Map)),
      ],
      marks: [
        for (final m in (json['marks'] as List? ?? const []))
          VipMark.fromJson(Map<String, dynamic>.from(m as Map)),
      ],
    );
  }

  /// Fecha/hora del check-in del alumno en una clase, si existe.
  DateTime? markFor(String userId, String classId) {
    for (final m in marks) {
      if (m.userId == userId && m.classId == classId) return m.recordedAt;
    }
    return null;
  }

  /// Número de clases incluidas en las que el alumno hizo check-in.
  int attendedClasses(String userId) {
    return marks.where((m) => m.userId == userId).length;
  }

  /// Ingreso correspondiente al alumno: precio de cada clase asistida
  /// repartido entre sus sesiones totales.
  double incomeFor(String userId) {
    var total = 0.0;
    for (final mark in marks.where((m) => m.userId == userId)) {
      final klass = _classById(mark.classId);
      total += klass?.perSessionValue ?? 0;
    }
    return double.parse(total.toStringAsFixed(2));
  }

  VipClass? _classById(String id) {
    for (final c in classes) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class VipClass {
  const VipClass({
    required this.id,
    required this.title,
    required this.price,
    required this.currency,
    required this.sessions,
  });

  final String id;
  final String title;
  final double price;
  final String currency;
  final int sessions;

  double get perSessionValue =>
      (price <= 0 || sessions <= 0) ? 0 : price / sessions;

  factory VipClass.fromJson(Map<String, dynamic> json) {
    return VipClass(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?)?.trim() ?? 'BOB',
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    );
  }
}

class VipStudent {
  const VipStudent({
    required this.userId,
    required this.firstName,
    required this.lastName,
  });

  final String userId;
  final String firstName;
  final String lastName;

  String get fullName => '$firstName $lastName'.trim();

  factory VipStudent.fromJson(Map<String, dynamic> json) {
    return VipStudent(
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
    );
  }
}

class VipMark {
  const VipMark({
    required this.userId,
    required this.classId,
    required this.recordedAt,
  });

  final String userId;
  final String classId;
  final DateTime? recordedAt;

  factory VipMark.fromJson(Map<String, dynamic> json) {
    return VipMark(
      userId: json['user_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'] as String)
          : null,
    );
  }
}
