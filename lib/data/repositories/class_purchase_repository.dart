import '../models/purchasable_session_model.dart';
import '../models/vip_plan_model.dart';
import '../services/class_purchase_service.dart';

abstract interface class IClassPurchaseRepository {
  Future<List<PurchasableSession>> fetchPurchasableSessions(
    String classId, {
    int? limit,
    int offset = 0,
    int? weeks,
  });
  Future<Map<String, dynamic>> quoteSessions(
    String enrollmentId,
    List<String> sessionIds,
  );
  Future<Map<String, dynamic>> quoteMonthly(String enrollmentId);
  Future<VipPlanModel?> quoteVip(String organizationId);
  Future<List<VipMembershipModel>> fetchMyVipMemberships();
  Future<Map<String, dynamic>?> fetchVipPlanConfig(String organizationId);
  Future<String> saveVipPlan({
    required String organizationId,
    required String name,
    String? description,
    required double priceMonthly,
    required bool includesAllClasses,
    required List<String> categoryIds,
    bool isActive,
  });
}

class ClassPurchaseRepository implements IClassPurchaseRepository {
  const ClassPurchaseRepository({ClassPurchaseService? service})
    : _service = service ?? const ClassPurchaseService();

  final ClassPurchaseService _service;

  @override
  Future<List<PurchasableSession>> fetchPurchasableSessions(
    String classId, {
    int? limit,
    int offset = 0,
    int? weeks,
  }) async {
    final rows = await _service.listClassPurchaseSessions(
      classId,
      limit: limit,
      offset: offset,
      weeks: weeks,
    );
    return rows.map(PurchasableSession.fromJson).toList();
  }

  @override
  Future<Map<String, dynamic>> quoteSessions(
    String enrollmentId,
    List<String> sessionIds,
  ) => _service.quoteClassSessions(enrollmentId, sessionIds);

  @override
  Future<Map<String, dynamic>> quoteMonthly(String enrollmentId) =>
      _service.quoteClassMonthly(enrollmentId);

  @override
  Future<VipPlanModel?> quoteVip(String organizationId) async {
    final data = await _service.quoteVipMembership(organizationId);
    if (data['success'] != true) return null;
    return VipPlanModel.fromJson(data);
  }

  @override
  Future<List<VipMembershipModel>> fetchMyVipMemberships() async {
    final rows = await _service.fetchMyVipMemberships();
    return rows.map(VipMembershipModel.fromJson).toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchVipPlanConfig(String organizationId) =>
      _service.fetchVipPlan(organizationId);

  @override
  Future<String> saveVipPlan({
    required String organizationId,
    required String name,
    String? description,
    required double priceMonthly,
    required bool includesAllClasses,
    required List<String> categoryIds,
    bool isActive = true,
  }) => _service.saveVipPlan(
    organizationId: organizationId,
    name: name,
    description: description,
    priceMonthly: priceMonthly,
    includesAllClasses: includesAllClasses,
    categoryIds: categoryIds,
    isActive: isActive,
  );
}
