import 'dart:typed_data';

import '../models/organization_model.dart';
import '../models/organization_member_model.dart';
import '../models/organization_invitation_model.dart';
import '../services/organization_service.dart';

abstract interface class IOrganizationRepository {
  Future<List<OrganizationWithRole>> fetchMyOrganizations();
  Future<OrganizationModel?> fetchOrganization(String orgId);
  Future<OrganizationModel> createOrganization({
    required String name,
    String? legalName,
    String? description,
    String? email,
    String? phoneNumber,
    String? websiteUrl,
    String? cityId,
  });
  Future<void> updateOrganization(String orgId, Map<String, dynamic> data);
  Future<void> deleteOrganization(String orgId);

  Future<List<OrganizationMemberWithProfile>> fetchMembers(String orgId);
  Future<void> addMember({
    required String orgId,
    required String userId,
    required String role,
  });
  Future<void> updateMemberRole({
    required String memberId,
    required String newRole,
  });
  Future<void> removeMember(String memberId);

  Future<void> sendInvitation({
    required String orgId,
    required String email,
    required String role,
  });
  Future<List<OrganizationInvitationModel>> fetchOrgInvitations(String orgId);
  Future<List<OrganizationInvitationModel>> fetchMyInvitations();
  Future<Map<String, dynamic>> acceptInvitation(String invitationId);
  Future<Map<String, dynamic>> declineInvitation(String invitationId);
  Future<void> cancelInvitation(String invitationId);

  Future<String> uploadLogo(
    String orgId,
    Uint8List bytes, {
    required String extension,
  });
  Future<String?> logoSignedUrl(String? path);
  Future<void> uploadLogoForOrg({
    required String orgId,
    required Uint8List bytes,
    required String extension,
  });
}

class OrganizationWithRole {
  const OrganizationWithRole({
    required this.organization,
    required this.role,
  });

  final OrganizationModel organization;
  final MemberRole role;

  factory OrganizationWithRole.fromJson(Map<String, dynamic> json) {
    final orgData = json['organizations'] as Map<String, dynamic>;
    return OrganizationWithRole(
      organization: OrganizationModel.fromJson(orgData),
      role: MemberRole.fromString(json['role'] as String),
    );
  }
}

class OrganizationMemberWithProfile {
  const OrganizationMemberWithProfile({
    required this.member,
    required this.profileName,
    this.profilePhone,
  });

  final OrganizationMemberModel member;
  final String profileName;
  final String? profilePhone;

  factory OrganizationMemberWithProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final firstName = profile?['first_name'] as String? ?? '';
    final lastName = profile?['last_name'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();

    return OrganizationMemberWithProfile(
      member: OrganizationMemberModel.fromJson(json),
      profileName: fullName.isNotEmpty ? fullName : 'Sin nombre',
      profilePhone: profile?['phone_number'] as String?,
    );
  }
}

class OrganizationRepository implements IOrganizationRepository {
  const OrganizationRepository({OrganizationService? service})
      : _service = service ?? const OrganizationService();

  final OrganizationService _service;

  @override
  Future<List<OrganizationWithRole>> fetchMyOrganizations() async {
    final rows = await _service.fetchMyOrganizations();
    return rows.map((row) => OrganizationWithRole.fromJson(row)).toList();
  }

  @override
  Future<OrganizationModel?> fetchOrganization(String orgId) async {
    final raw = await _service.fetchOrganization(orgId);
    return raw != null ? OrganizationModel.fromJson(raw) : null;
  }

  @override
  Future<OrganizationModel> createOrganization({
    required String name,
    String? legalName,
    String? description,
    String? email,
    String? phoneNumber,
    String? websiteUrl,
    String? cityId,
  }) async {
    final raw = await _service.createOrganization(
      name: name,
      legalName: legalName,
      description: description,
      email: email,
      phoneNumber: phoneNumber,
      websiteUrl: websiteUrl,
      cityId: cityId,
    );
    return OrganizationModel.fromJson(raw);
  }

  @override
  Future<void> updateOrganization(
          String orgId, Map<String, dynamic> data) =>
      _service.updateOrganization(orgId, data);

  @override
  Future<void> deleteOrganization(String orgId) =>
      _service.deleteOrganization(orgId);

  @override
  Future<List<OrganizationMemberWithProfile>> fetchMembers(String orgId) async {
    final rows = await _service.fetchMembers(orgId);
    return rows
        .map((row) => OrganizationMemberWithProfile.fromJson(row))
        .toList();
  }

  @override
  Future<void> addMember({
    required String orgId,
    required String userId,
    required String role,
  }) =>
      _service.addMember(orgId: orgId, userId: userId, role: role);

  @override
  Future<void> updateMemberRole({
    required String memberId,
    required String newRole,
  }) =>
      _service.updateMemberRole(memberId: memberId, newRole: newRole);

  @override
  Future<void> removeMember(String memberId) =>
      _service.removeMember(memberId);

  @override
  Future<void> sendInvitation({
    required String orgId,
    required String email,
    required String role,
  }) =>
      _service.sendInvitation(orgId: orgId, email: email, role: role);

  @override
  Future<List<OrganizationInvitationModel>> fetchOrgInvitations(
      String orgId) async {
    final rows = await _service.fetchOrgInvitations(orgId);
    return rows
        .map((row) => OrganizationInvitationModel.fromJson(row))
        .toList();
  }

  @override
  Future<List<OrganizationInvitationModel>> fetchMyInvitations() async {
    final rows = await _service.fetchMyInvitations();
    return rows
        .map((row) => OrganizationInvitationModel.fromJson(row))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> acceptInvitation(String invitationId) =>
      _service.acceptInvitation(invitationId);

  @override
  Future<Map<String, dynamic>> declineInvitation(String invitationId) =>
      _service.declineInvitation(invitationId);

  @override
  Future<void> cancelInvitation(String invitationId) =>
      _service.cancelInvitation(invitationId);

  @override
  Future<String> uploadLogo(
    String orgId,
    Uint8List bytes, {
    required String extension,
  }) =>
      _service.uploadLogo(orgId, bytes, extension: extension);

  @override
  Future<String?> logoSignedUrl(String? path) =>
      _service.logoSignedUrl(path);

  @override
  Future<void> uploadLogoForOrg({
    required String orgId,
    required Uint8List bytes,
    required String extension,
  }) =>
      _service.uploadLogoForOrg(
        orgId: orgId,
        bytes: bytes,
        extension: extension,
      );
}
