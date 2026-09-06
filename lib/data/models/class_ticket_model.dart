/// Ticket diario de sesión de clase con su token QR (espejo del RPC
/// `fetch_my_class_tickets`).
class ClassTicketModel {
  const ClassTicketModel({
    required this.id,
    required this.sessionId,
    required this.validDate,
    required this.status,
    required this.classId,
    required this.classTitle,
    required this.organizationName,
    required this.sessionStartAt,
    required this.sessionEndAt,
    required this.passStatus,
    this.usedAt,
    this.qrToken,
    this.qrActive = false,
    this.qrExpiresAt,
  });

  final String id;
  final String sessionId;
  final DateTime validDate;
  final String status;
  final String classId;
  final String classTitle;
  final String? organizationName;
  final DateTime sessionStartAt;
  final DateTime sessionEndAt;
  final String passStatus;

  final DateTime? usedAt;
  final String? qrToken;
  final bool qrActive;
  final DateTime? qrExpiresAt;

  bool get isUsed => status == 'used';
  bool get isIssued => status == 'issued';
  bool get isExpired => status == 'expired';
  bool get isCancelled => status == 'cancelled';
  bool get canShowQr => isIssued && qrToken != null;

  String get statusDisplayName => switch (status) {
        'issued' => 'Vigente',
        'used' => 'Usado',
        'expired' => 'Expirado',
        'cancelled' => 'Cancelado',
        _ => status,
      };

  factory ClassTicketModel.fromJson(Map<String, dynamic> json) {
    return ClassTicketModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      validDate: DateTime.parse(json['valid_date'] as String),
      status: json['status'] as String? ?? 'issued',
      classId: json['class_id'] as String,
      classTitle: json['class_title'] as String,
      organizationName: json['organization_name'] as String?,
      sessionStartAt: DateTime.parse(json['session_start_at'] as String),
      sessionEndAt: DateTime.parse(json['session_end_at'] as String),
      passStatus: json['pass_status'] as String? ?? 'active',
      usedAt: json['used_at'] != null
          ? DateTime.tryParse(json['used_at'] as String)
          : null,
      qrToken: json['qr_token'] as String?,
      qrActive: (json['qr_active'] as bool?) ?? false,
      qrExpiresAt: json['qr_expires_at'] != null
          ? DateTime.tryParse(json['qr_expires_at'] as String)
          : null,
    );
  }
}