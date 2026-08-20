class OrganizationMemberModel {
  const OrganizationMemberModel({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.role,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.userName,
    this.userEmail,
  });

  final String id;
  final String organizationId;
  final String userId;
  final MemberRole role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Campos de joined query (no están en la tabla)
  final String? userName;
  final String? userEmail;

  factory OrganizationMemberModel.fromJson(Map<String, dynamic> json) {
    return OrganizationMemberModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      userId: json['user_id'] as String,
      role: MemberRole.fromString(json['role'] as String),
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'organization_id': organizationId,
        'user_id': userId,
        'role': role.value,
        'is_active': isActive,
      };

  OrganizationMemberModel copyWith({MemberRole? role, bool? isActive}) {
    return OrganizationMemberModel(
      id: id,
      organizationId: organizationId,
      userId: userId,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      userName: userName,
      userEmail: userEmail,
    );
  }
}

enum MemberRole {
  owner,
  manager,
  eventManager,
  checkInStaff;

  static MemberRole fromString(String value) => switch (value) {
        'owner' => MemberRole.owner,
        'manager' => MemberRole.manager,
        'event_manager' => MemberRole.eventManager,
        'check_in_staff' => MemberRole.checkInStaff,
        _ => MemberRole.checkInStaff,
      };

  String get value => switch (this) {
        MemberRole.owner => 'owner',
        MemberRole.manager => 'manager',
        MemberRole.eventManager => 'event_manager',
        MemberRole.checkInStaff => 'check_in_staff',
      };

  String get displayName => switch (this) {
        MemberRole.owner => 'Propietario',
        MemberRole.manager => 'Gerente',
        MemberRole.eventManager => 'Gestor de Eventos',
        MemberRole.checkInStaff => 'Staff de Check-in',
      };

  bool get canEditOrg => this == MemberRole.owner || this == MemberRole.manager;
  bool get canManageMembers =>
      this == MemberRole.owner || this == MemberRole.manager;
  bool get canChangeRoles => this == MemberRole.owner;
  bool get isOwner => this == MemberRole.owner;
}
