import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/organization_image_model.dart';
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
            organizations!inner(
              id, name, logo_url, cover_image_url, description, is_active, is_verified,
              department_id, province_id, municipality_id, location_name, address, latitude, longitude,
              qr_code_hash, views_count
            )
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at');
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchOrganization(String orgId) async {
    try {
      return await supabase
          .from('organizations')
          .select('''
            *,
            departments(id, name),
            provinces(id, name),
            municipalities(id, name)
          ''')
          .eq('id', orgId)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  Future<void> recordOrganizationView(
    String organizationId, {
    String source = 'app',
  }) async {
    await supabase.rpc('record_organization_view', params: {
      'p_org_id': organizationId,
      'p_source': source,
    });
  }

  Future<Map<String, dynamic>> createOrganization({
    required String name,
    String? legalName,
    String? description,
    String? email,
    String? phoneNumber,
    String? websiteUrl,
    String? departmentId,
    String? provinceId,
    String? municipalityId,
    String? locationName,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const OrganizationException(
          'Debes iniciar sesión para crear una organización.');
    }

    try {
      final result =
          await supabase.rpc('create_organization_with_owner', params: {
        'p_name': name,
        'p_legal_name': legalName,
        'p_description': description,
        'p_email': email,
        'p_phone_number': phoneNumber,
        'p_website_url': websiteUrl,
      });

      final org = result as Map<String, dynamic>;
      final orgId = org['id'] as String;

      final Map<String, dynamic> locationUpdates = {};
      if (departmentId != null) locationUpdates['department_id'] = departmentId;
      if (provinceId != null) locationUpdates['province_id'] = provinceId;
      if (municipalityId != null) {
        locationUpdates['municipality_id'] = municipalityId;
      }
      if (locationName != null) locationUpdates['location_name'] = locationName;
      if (address != null) locationUpdates['address'] = address;
      if (latitude != null) locationUpdates['latitude'] = latitude;
      if (longitude != null) locationUpdates['longitude'] = longitude;

      if (locationUpdates.isNotEmpty) {
        final updatedData = await supabase
            .from('organizations')
            .update(locationUpdates)
            .eq('id', orgId)
            .select()
            .single();
        return updatedData;
      }

      return org;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const OrganizationException(
            'Ya existe una organización con ese nombre.');
      }
      throw OrganizationException(_friendlyPostgresError(e.message));
    }
  }

  // ─── Storage: Logo & Portada / Banner ───────────────

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

  Future uploadLogoForOrg({
    required String orgId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final logoPath = await uploadLogo(orgId, bytes, extension: extension);
    await updateOrganization(orgId, {'logo_url': logoPath});
  }

  Future<String?> logoSignedUrl(String? path) =>
      _storage.signedUrl(path, bucket: 'organization-logos');

  Future<String> uploadCover(
    String orgId,
    Uint8List bytes, {
    required String extension,
  }) async {
    final cleanExt = extension.toLowerCase().replaceAll('.', '');
    final path = '$orgId/cover.$cleanExt';
    final contentType = cleanExt == 'png' ? 'image/png' : 'image/jpeg';

    await supabase.storage.from('organization-logos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );

    return supabase.storage.from('organization-logos').getPublicUrl(path);
  }

  Future uploadCoverForOrg({
    required String orgId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final coverUrl = await uploadCover(orgId, bytes, extension: extension);
    await updateOrganization(orgId, {'cover_image_url': coverUrl});
  }

  Future<List<Map<String, dynamic>>> fetchOrganizationImages(
      String orgId) async {
    final rows = await supabase
        .from('organization_images')
        .select('id, organization_id, image_url, title, sort_order, created_at')
        .eq('organization_id', orgId)
        .order('sort_order')
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addOrganizationImage({
    required String orgId,
    required Uint8List bytes,
    required String extension,
    String? title,
  }) async {
    final cleanExt = extension.toLowerCase().replaceAll('.', '');
    final fileName = '${DateTime.now().microsecondsSinceEpoch}.$cleanExt';
    final path = '$orgId/gallery/$fileName';
    final contentType = cleanExt == 'png' ? 'image/png' : 'image/jpeg';

    await supabase.storage.from('organization-logos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: contentType,
            cacheControl: '3600',
          ),
        );

    try {
      final maxSort = await supabase
          .from('organization_images')
          .select('sort_order')
          .eq('organization_id', orgId)
          .order('sort_order', ascending: false)
          .limit(1);
      final nextSort = maxSort.isEmpty
          ? 0
          : ((maxSort.first['sort_order'] as num?)?.toInt() ?? 0) + 1;

      final row = await supabase
          .from('organization_images')
          .insert({
            'organization_id': orgId,
            'image_url': path,
            'title': title?.trim().isEmpty == true ? null : title?.trim(),
            'sort_order': nextSort,
          })
          .select()
          .single();
      return Map<String, dynamic>.from(row);
    } catch (_) {
      await supabase.storage.from('organization-logos').remove([path]);
      rethrow;
    }
  }

  Future<void> deleteOrganizationImage(OrganizationImageModel image) async {
    await supabase.from('organization_images').delete().eq('id', image.id);
    final path = image.imageUrl.startsWith('http')
        ? StorageService.extractPathFromSignedUrl(image.imageUrl)
        : image.imageUrl;
    if (path != null && path.isNotEmpty) {
      await supabase.storage.from('organization-logos').remove([path]);
    }
  }

  // ─── Actualizaciones & Borrado ───────────────────────

    Future<void> updateOrganization(
      String orgId, Map<String, dynamic> data) async {
    try {
      await supabase.from('organizations').update(data).eq('id', orgId);
    } on PostgrestException catch (e) {
      throw OrganizationException(_friendlyPostgresError(e.message));
    }
  }

  Future deleteOrganization(String orgId) async {
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

  Future addMember({
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
        throw const OrganizationException(
            'Este usuario ya es miembro de la organización.');
      }
      throw OrganizationException(_friendlyPostgresError(e.message));
    }
  }

  Future updateMemberRole({
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

  Future removeMember(String memberId) async {
    await supabase
        .from('organization_members')
        .update({'is_active': false}).eq('id', memberId);
  }

  // ─── Invitations ─────────────────────────────────

  Future sendInvitation({
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
            'Ya existe una invitación pendiente para ese email.');
      }
      throw OrganizationException(_friendlyPostgresError(e.message));
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrgInvitations(
      String orgId) async {
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
      final invitations = await supabase
          .from('organization_invitations')
          .select('*')
          .eq('status', 'pending')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

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

  Future cancelInvitation(String invitationId) async {
    await supabase
        .from('organization_invitations')
        .delete()
        .eq('id', invitationId);
  }

  // ─── Helpers ───────────────────────────────────────

  String _friendlyPostgresError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('permission denied') ||
        msg.contains('row-level security')) {
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