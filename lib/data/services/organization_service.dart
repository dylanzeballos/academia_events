import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../services/storage_service.dart';

/// Excepción amigable para errores de organización.
class OrganizationException implements Exception {
  const OrganizationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OrganizationService {
  const OrganizationService({StorageService? storage})
      : _storage = storage ?? const StorageService();

  final StorageService _storage;

  // ─── Organizations CRUD ────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMyOrganizations() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      return await supabase
          .from('organization_members')
          .select('''
            role, is_active, created_at,
            organizations!inner(id, name, logo_url, description, is_active, is_verified)
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at');
    } catch (e) {
      // Si falla por RLS o permisos, retornar lista vacía en vez de crashear
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchOrganization(String orgId) async {
    try {
      return await supabase
          .from('organizations')
          .select('*, cities(name)')
          .eq('id', orgId)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createOrganization({
    required String name,
    String? legalName,
    String? description,
    String? email,
    String? phoneNumber,
    String? websiteUrl,
    String? cityId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const OrganizationException('Debes iniciar sesión para crear una organización.');
    }

    try {
      final result =
          await supabase.rpc('create_organization_with_owner', params: {
        'p_name': name,
        'p_legal_name': ?legalName,
        'p_description': ?description,
        'p_email': ?email,
        'p_phone_number': ?phoneNumber,
        'p_website_url': ?websiteUrl,
      });

      final org = result as Map<String, dynamic>;

      if (cityId != null) {
        await supabase
            .from('organizations')
            .update({'city_id': cityId}).eq('id', org['id'] as String);
      }

      return org;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // unique_violation
        throw const OrganizationException('Ya existe una organización con ese nombre.');
      }
      throw OrganizationException(_friendlyPostgresError(e.message));
    }
  }

  /// Upload logo after organization creation and update the record.
  /// Stores the storage path in logo_url (not signed URL).
  Future<void> uploadLogoForOrg({
    required String orgId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final logoPath = await uploadLogo(orgId, bytes, extension: extension);
    await updateOrganization(orgId, {'logo_url': logoPath});
  }

  /// Generate a fresh signed URL from a stored path.
  Future<String?> logoSignedUrl(String? path) =>
      _storage.signedUrl(path, bucket: 'organization-logos');

  Future<void> updateOrganization(
      String orgId, Map<String, dynamic> data) async {
    try {
      await supabase.from('organizations').update(data).eq('id', orgId);
    } on PostgrestException catch (e) {
      throw OrganizationException(_friendlyPostgresError(e.message));
    }
  }

  Future<void> deleteOrganization(String orgId) async {
    await supabase.from('organizations').update({
      'is_active': false,
    }).eq('id', orgId);
  }

  // ─── Members ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMembers(String orgId) async {
    try {
      return await supabase
          .from('organization_members')
          .select('''
            id, organization_id, user_id, role, is_active, created_at, updated_at,
            profiles(first_name, last_name, phone_number)
          ''')
          .eq('organization_id', orgId)
          .eq('is_active', true)
          .order('created_at');
    } catch (e) {
      return [];
    }
  }

  Future<void> addMember({
    required String orgId,
    required String userId,
    required String role,
  }) async {
    try {
      await supabase.from('organization_members').insert({
        'organization_id': orgId,
        'user_id': userId,
        'role': role,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const OrganizationException('Este usuario ya es miembro de la organización.');
      }
      throw OrganizationException(_friendlyPostgresError(e.message));
    }
  }

  Future<void> updateMemberRole({
    required String memberId,
    required String newRole,
  }) async {
    try {
      await supabase
          .from('organization_members')
          .update({'role': newRole}).eq('id', memberId);
    } on PostgrestException catch (e) {
      throw OrganizationException(_friendlyPostgresError(e.message));
    }
  }

  Future<void> removeMember(String memberId) async {
    await supabase
        .from('organization_members')
        .update({'is_active': false}).eq('id', memberId);
  }

  // ─── Invitations ─────────────────────────────────

  Future<void> sendInvitation({
    required String orgId,
    required String email,
    required String role,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const OrganizationException('No autenticado.');
    }

    try {
      await supabase.from('organization_invitations').insert({
        'organization_id': orgId,
        'email': email.trim().toLowerCase(),
        'role': role,
        'invited_by': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const OrganizationException(
            'Ya existe una invitacion pendiente para ese email.');
      }
      throw OrganizationException(_friendlyPostgresError(e.message));
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrgInvitations(String orgId) async {
    try {
      return await supabase
          .from('organization_invitations')
          .select('*')
          .eq('organization_id', orgId)
          .order('created_at', ascending: false);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyInvitations() async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) return [];

    try {
      // Let RLS handle email matching (users_can_view_own_invitations policy)
      final invitations = await supabase
          .from('organization_invitations')
          .select('*')
          .eq('status', 'pending')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      // Fetch org names separately to avoid RLS issues on organizations join
      for (final inv in invitations) {
        final orgId = inv['organization_id'] as String?;
        if (orgId != null) {
          try {
            final org = await supabase
                .from('organizations')
                .select('name')
                .eq('id', orgId)
                .maybeSingle();
            if (org != null) {
              inv['org_name'] = org['name'] as String?;
            }
          } catch (_) {}
        }
      }

      return invitations;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> acceptInvitation(String invitationId) async {
    try {
      final result = await supabase.rpc('accept_invitation', params: {
        'invitation_id': invitationId,
      });
      return result as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw OrganizationException(_friendlyPostgresError(e.message));
    }
  }

  Future<Map<String, dynamic>> declineInvitation(String invitationId) async {
    try {
      final result = await supabase.rpc('decline_invitation', params: {
        'invitation_id': invitationId,
      });
      return result as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw OrganizationException(_friendlyPostgresError(e.message));
    }
  }

  Future<void> cancelInvitation(String invitationId) async {
    await supabase
        .from('organization_invitations')
        .delete()
        .eq('id', invitationId);
  }

  // ─── Logo Storage ──────────────────────────────────

  Future<String> uploadLogo(
    String orgId,
    Uint8List bytes, {
    required String extension,
  }) async {
    final cleanExt = extension.toLowerCase().replaceAll('.', '');
    final path = '$orgId/logo.$cleanExt';
    final contentType = cleanExt == 'png' ? 'image/png' : 'image/jpeg';

    await supabase.storage.from('organization-logos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );

    return path;
  }

  // ─── Helpers ───────────────────────────────────────

  String _friendlyPostgresError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('permission denied') || msg.contains('row-level security')) {
      return 'No tienes permiso para realizar esta acción.';
    }
    if (msg.contains('duplicate key') || msg.contains('unique constraint')) {
      return 'Ya existe un registro con esos datos.';
    }
    if (msg.contains('foreign key') || msg.contains('violates foreign key')) {
      return 'Referencia no válida. Verifica los datos.';
    }
    if (msg.contains('work_mem') || msg.contains('out of memory')) {
      return 'Error interno. Intenta de nuevo más tarde.';
    }
    return 'Error al guardar. Intenta de nuevo.';
  }
}
