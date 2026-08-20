class OrganizationInvitationModel {
  const OrganizationInvitationModel({
    required this.id,
    required this.organizationId,
    required this.email,
    required this.role,
    required this.invitedBy,
    required this.status,
    this.token,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
    this.organizationName,
    this.inviterName,
  });

  final String id;
  final String organizationId;
  final String email;
  final String role;
  final String invitedBy;
  final String status;
  final String? token;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? organizationName;
  final String? inviterName;

  factory OrganizationInvitationModel.fromJson(Map<String, dynamic> json) {
    final orgData = json['organizations'] as Map<String, dynamic>?;
    final inviterData = json['inviter_profile'] as Map<String, dynamic>?;

    String? inviterName;
    if (inviterData != null) {
      final first = inviterData['first_name'] as String? ?? '';
      final last = inviterData['last_name'] as String? ?? '';
      inviterName = '$first $last'.trim();
      if (inviterName.isEmpty) inviterName = null;
    }

    // Support both joined org name and separate fetch
    final orgName = orgData?['name'] as String? ??
        json['org_name'] as String?;

    return OrganizationInvitationModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      invitedBy: json['invited_by'] as String,
      status: json['status'] as String,
      token: json['token'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      organizationName: orgName,
      inviterName: inviterName,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'accepted':
        return 'Aceptada';
      case 'declined':
        return 'Rechazada';
      case 'expired':
        return 'Expirada';
      default:
        return status;
    }
  }
}
