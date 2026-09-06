/// Pase de clase (espejo del RPC `fetch_my_class_passes`).
class ClassPassModel {
  const ClassPassModel({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.passStatus,
    required this.classId,
    required this.enrollmentId,
    required this.classTitle,
    this.sessionCount = 0,
    this.price = 0,
    this.currency = 'BOB',
    this.totalAmount = 0,
    this.organizationName,
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String passStatus;
  final String classId;
  final String enrollmentId;
  final String classTitle;
  final int sessionCount;
  final double price;
  final String currency;
  final double totalAmount;
  final String? organizationName;

  bool get isActive => passStatus == 'active';
  bool get isExpired => passStatus == 'expired';

  String get statusDisplayName => switch (passStatus) {
        'active' => 'Activo',
        'expired' => 'Expirado',
        'cancelled' => 'Cancelado',
        _ => passStatus,
      };

  factory ClassPassModel.fromJson(Map<String, dynamic> json) {
    return ClassPassModel(
      id: json['id'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      passStatus: json['pass_status'] as String? ?? 'active',
      classId: json['class_id'] as String,
      enrollmentId: json['enrollment_id'] as String,
      classTitle: json['class_title'] as String,
      sessionCount: (json['session_count'] as int?) ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?)?.trim() ?? 'BOB',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      organizationName: json['organization_name'] as String?,
    );
  }
}