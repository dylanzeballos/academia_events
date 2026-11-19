import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../data/models/organization_model.dart';
import '../data/models/organization_member_model.dart';
import '../data/models/organization_invitation_model.dart';
import '../data/models/organization_image_model.dart';
import '../data/repositories/organization_repository.dart';
import '../data/services/organization_service.dart';
import 'auth_provider.dart';
import 'layout_mode_provider.dart';


final organizationRepositoryProvider = Provider<IOrganizationRepository>((ref) {
  return const OrganizationRepository();
});

// ─── Mis organizaciones ─────────────────────────────

final myOrganizationsProvider = FutureProvider<List<OrganizationWithRole>>((
  ref,
) async {
  // Re-ejecutar en cada cambio de sesión (login/logout): sin esto, el
  // resultado cacheado de una sesión anterior (o de estar deslogueado)
  // persistía y la UI mostraba el panel sin datos.
  ref.watch(authStateProvider);
  final repo = ref.watch(organizationRepositoryProvider);
  return repo.fetchMyOrganizations();
});

// ─── Organización actual (seleccionada) ─────────────

class SelectedOrgIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Se limpia al cerrar sesión para no arrastrar la academia de otro usuario.
    // No se usa `ref.watch(authStateProvider)` porque cada evento de auth
    // (token refrescado, app retomada) reiniciaría la selección y las vistas
    // se quedarían sin datos.
    ref.listen(authStateProvider, (_, next) {
      if (next.value?.event == sb.AuthChangeEvent.signedOut) {
        state = null;
      }
    });
    return null;
  }

  void select(String id) => state = id;
  void clear() => state = null;
}

final selectedOrganizationIdProvider =
    NotifierProvider<SelectedOrgIdNotifier, String?>(
      () => SelectedOrgIdNotifier(),
    );

final selectedOrganizationProvider = FutureProvider<OrganizationModel?>((ref) {
  final orgId = ref.watch(selectedOrganizationIdProvider);
  if (orgId == null) return Future.value(null);
  final repo = ref.watch(organizationRepositoryProvider);
  return repo.fetchOrganization(orgId);
});

final publicOrganizationProvider =
    FutureProvider.family<OrganizationModel?, String>((ref, orgId) {
      final repo = ref.watch(organizationRepositoryProvider);
      return repo.fetchOrganization(orgId);
    });

final organizationImagesProvider =
    FutureProvider.family<List<OrganizationImageModel>, String>((ref, orgId) {
      final repo = ref.watch(organizationRepositoryProvider);
      return repo.fetchOrganizationImages(orgId);
    });

// ─── Estilos de baile declarados de la organización ─

final organizationDanceCategoryIdsProvider =
    FutureProvider.family<List<String>, String>((ref, orgId) {
      final repo = ref.watch(organizationRepositoryProvider);
      return repo.fetchOrganizationDanceCategoryIds(orgId);
    });

// ─── Miembros de la organización seleccionada ───────

final organizationMembersProvider =
    FutureProvider<List<OrganizationMemberWithProfile>>((ref) {
      final orgId = ref.watch(selectedOrganizationIdProvider);
      if (orgId == null) return Future.value([]);
      final repo = ref.watch(organizationRepositoryProvider);
      return repo.fetchMembers(orgId);
    });

// ─── Mi rol en la organización seleccionada ─────────

final myOrgRoleProvider = Provider<MemberRole?>((ref) {
  final orgId = ref.watch(selectedOrganizationIdProvider);
  if (orgId == null) return null;
  final orgsAsync = ref.watch(myOrganizationsProvider);
  return orgsAsync.whenData((orgs) {
    final match = orgs.where((o) => o.organization.id == orgId);
    return match.isNotEmpty ? match.first.role : null;
  }).value;
});

// ─── ¿Soy admin de la org seleccionada? ────────────

final isOrgAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(myOrgRoleProvider);
  return role?.canEditOrg ?? false;
});

// ─── Estado de creación de organización ─────────────

class CreateOrgState {
  const CreateOrgState({this.isLoading = false, this.error});

  final bool isLoading;
  final String? error;

  CreateOrgState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CreateOrgState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CreateOrgNotifier extends Notifier<CreateOrgState> {
  @override
  CreateOrgState build() => const CreateOrgState();

  Future<bool> create({
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
    Uint8List? logoBytes,
    String? logoExtension,
    Uint8List? coverBytes,
    String? coverExtension,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(organizationRepositoryProvider);
      final org = await repo.createOrganization(
        name: name,
        legalName: legalName,
        description: description,
        email: email,
        phoneNumber: phoneNumber,
        websiteUrl: websiteUrl,
        departmentId: departmentId,
        provinceId: provinceId,
        municipalityId: municipalityId,
        locationName: locationName,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );

      // Upload logo if provided
      if (logoBytes != null && logoExtension != null) {
        await repo.uploadLogoForOrg(
          orgId: org.id,
          bytes: logoBytes,
          extension: logoExtension,
        );
      }

      if (coverBytes != null && coverExtension != null) {
        await repo.uploadCoverForOrg(
          orgId: org.id,
          bytes: coverBytes,
          extension: coverExtension,
        );
      }

      ref.invalidate(myOrganizationsProvider);
      // El creador pasa a ser propietario: activa el modo organización.
      ref.read(layoutModeProvider.notifier).set(AppLayoutMode.academy);
      state = const CreateOrgState();
      return true;
    } on OrganizationException catch (e) {
      state = CreateOrgState(error: e.message);
      return false;
    } catch (e) {
      state = const CreateOrgState(
        error: 'Ocurrió un error inesperado. Intenta de nuevo.',
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final createOrgProvider = NotifierProvider<CreateOrgNotifier, CreateOrgState>(
  () {
    return CreateOrgNotifier();
  },
);

// ─── Logo signed URL helper ─────────────────────────

final orgLogoUrlProvider = FutureProvider.family<String?, String?>((
  ref,
  String? logoPath,
) async {
  if (logoPath == null || logoPath.trim().isEmpty) return null;
  if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
    return logoPath;
  }
  final repo = ref.watch(organizationRepositoryProvider);
  return repo.logoSignedUrl(logoPath);
});

// ─── Invitations ───────────────────────────────────

final orgInvitationsProvider =
    FutureProvider<List<OrganizationInvitationModel>>((ref) async {
      final orgId = ref.watch(selectedOrganizationIdProvider);
      if (orgId == null) return [];
      final repo = ref.watch(organizationRepositoryProvider);
      return repo.fetchOrgInvitations(orgId);
    });

final myInvitationsProvider =
    FutureProvider<List<OrganizationInvitationModel>>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(organizationRepositoryProvider);
  return repo.fetchMyInvitations();
});

class OrganizationViewsStats {
  const OrganizationViewsStats({
    required this.totalViews,
    required this.currentMonthViews,
    required this.uniqueMonthUsers,
    required this.monthlyHistory,
    required this.monthSources,
  });

  final int totalViews;
  final int currentMonthViews;
  final int uniqueMonthUsers;
  final List<Map<String, dynamic>> monthlyHistory;
  final List<Map<String, dynamic>> monthSources;
}

final organizationViewsStatsProvider =
    FutureProvider.family<OrganizationViewsStats, String>((ref, orgId) async {
  final res = await sb.Supabase.instance.client.rpc(
    'get_organization_views_stats',
    params: {'p_org_id': orgId},
  );

  final data = Map<String, dynamic>.from(res as Map);

  final history = (data['monthly_history'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final sources = (data['month_sources'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  return OrganizationViewsStats(
    totalViews: (data['total_views'] as num?)?.toInt() ?? 0,
    currentMonthViews: (data['current_month_views'] as num?)?.toInt() ?? 0,
    uniqueMonthUsers: (data['unique_month_users'] as num?)?.toInt() ?? 0,
    monthlyHistory: history,
    monthSources: sources,
  );
});

class OrganizationActivityItem {
  const OrganizationActivityItem({
    required this.type,
    required this.userName,
    required this.actionText,
    required this.occurredAt,
  });

  final String type; // 'attendance' | 'enrollment' | 'ticket_order' | 'instructor'
  final String userName;
  final String actionText;
  final DateTime occurredAt;

  factory OrganizationActivityItem.fromJson(Map<String, dynamic> json) {
    return OrganizationActivityItem(
      type: (json['activity_type'] as String?) ?? 'enrollment',
      userName: (json['user_name'] as String?)?.trim().isNotEmpty == true
          ? (json['user_name'] as String).trim()
          : 'Usuario',
      actionText: (json['action_text'] as String?) ?? '',
      occurredAt: DateTime.parse(json['occurred_at'] as String),
    );
  }
}

final organizationRecentActivityProvider =
    FutureProvider.family<List<OrganizationActivityItem>, String>((ref, orgId) async {
  final res = await sb.Supabase.instance.client.rpc(
    'get_organization_recent_activity',
    params: {'p_org_id': orgId, 'p_limit': 10},
  );

  final list = (res as List? ?? []);
  return list
      .take(10)
      .map((e) => OrganizationActivityItem.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});