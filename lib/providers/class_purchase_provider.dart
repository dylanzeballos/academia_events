import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/vip_plan_model.dart';
import '../data/repositories/class_purchase_repository.dart';

final classPurchaseRepositoryProvider = Provider<IClassPurchaseRepository>((ref) {
  return const ClassPurchaseRepository();
});

/// Plan VIP vigente de la organización (null si no está configurado).
final vipPlanProvider =
    FutureProvider.autoDispose.family<VipPlanModel?, String>((
      ref,
      organizationId,
    ) async {
      final repo = ref.watch(classPurchaseRepositoryProvider);
      return repo.quoteVip(organizationId);
    });

/// Configuración editable del plan VIP (para owner/admin/manager).
final vipPlanConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((
      ref,
      organizationId,
    ) async {
      final repo = ref.watch(classPurchaseRepositoryProvider);
      return repo.fetchVipPlanConfig(organizationId);
    });

/// Membresías VIP del usuario autenticado.
final myVipMembershipsProvider =
    FutureProvider.autoDispose<List<VipMembershipModel>>((ref) async {
      final repo = ref.watch(classPurchaseRepositoryProvider);
      return repo.fetchMyVipMemberships();
    });
