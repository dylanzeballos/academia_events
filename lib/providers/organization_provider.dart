import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/organization_model.dart';
import '../data/models/organization_member_model.dart';
import '../data/repositories/organization_repository.dart';
import '../data/services/organization_service.dart';

final organizationRepositoryProvider = Provider<IOrganizationRepository>((ref) {
  return const OrganizationRepository();
});

// ─── Mis organizaciones ─────────────────────────────

final myOrganizationsProvider =
    FutureProvider<List<OrganizationWithRole>>((ref) async {
  final repo = ref.watch(organizationRepositoryProvider);
  return repo.fetchMyOrganizations();
});

// ─── Organización actual (seleccionada) ─────────────

class SelectedOrgIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

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

  CreateOrgState copyWith({bool? isLoading, String? error}) {
    return CreateOrgState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
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
    String? cityId,
    Uint8List? logoBytes,
    String? logoExtension,
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
        cityId: cityId,
      );

      // Upload logo if provided
      if (logoBytes != null && logoExtension != null) {
        await repo.uploadLogoForOrg(
          orgId: org.id,
          bytes: logoBytes,
          extension: logoExtension,
        );
      }

      ref.invalidate(myOrganizationsProvider);
      state = const CreateOrgState();
      return true;
    } on OrganizationException catch (e) {
      state = CreateOrgState(error: e.message);
      return false;
    } catch (e) {
      state = const CreateOrgState(error: 'Ocurrió un error inesperado. Intenta de nuevo.');
      return false;
    }
  }

  void clearError() => state = state.copyWith();
}

final createOrgProvider =
    NotifierProvider<CreateOrgNotifier, CreateOrgState>(() {
  return CreateOrgNotifier();
});
