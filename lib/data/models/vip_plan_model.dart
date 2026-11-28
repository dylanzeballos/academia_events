/// Plan VIP mensual configurado por una organización
/// (espejo del RPC `quote_vip_membership`).
class VipPlanModel {
  const VipPlanModel({
    required this.planId,
    required this.organizationId,
    required this.name,
    this.description,
    required this.priceMonthly,
    required this.currency,
    required this.includesAllClasses,
    this.categoryIds = const [],
    this.classCount = 0,
    this.classes = const [],
    this.periodStart,
    this.periodEnd,
  });

  final String planId;
  final String organizationId;
  final String name;
  final String? description;
  final double priceMonthly;
  final String currency;
  final bool includesAllClasses;
  final List<String> categoryIds;
  final int classCount;
  final List<VipPlanClass> classes;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  factory VipPlanModel.fromJson(Map<String, dynamic> json) {
    final rawClasses = (json['classes'] as List?) ?? const [];
    return VipPlanModel(
      planId: json['plan_id'] as String,
      organizationId: json['organization_id'] as String,
      name: (json['name'] as String?) ?? 'Pase VIP',
      description: json['description'] as String?,
      priceMonthly: (json['price_monthly'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?)?.trim() ?? 'BOB',
      includesAllClasses: json['includes_all_classes'] as bool? ?? true,
      categoryIds: ((json['category_ids'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      classCount: (json['class_count'] as num?)?.toInt() ?? 0,
      classes: rawClasses
          .whereType<Map>()
          .map((e) => VipPlanClass.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      periodStart: json['period_start'] != null
          ? DateTime.tryParse(json['period_start'] as String)?.toLocal()
          : null,
      periodEnd: json['period_end'] != null
          ? DateTime.tryParse(json['period_end'] as String)?.toLocal()
          : null,
    );
  }
}

class VipPlanClass {
  const VipPlanClass({
    required this.id,
    required this.title,
    this.pricePerSession = 0,
    this.priceMonthly = 0,
    this.categoryId,
  });

  final String id;
  final String title;
  final double pricePerSession;
  final double priceMonthly;
  final String? categoryId;

  factory VipPlanClass.fromJson(Map<String, dynamic> json) {
    return VipPlanClass(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'Clase',
      pricePerSession: (json['price_per_session'] as num?)?.toDouble() ?? 0,
      priceMonthly: (json['price_monthly'] as num?)?.toDouble() ?? 0,
      categoryId: json['category_id'] as String?,
    );
  }
}

/// Membresía VIP del usuario (espejo de `fetch_my_vip_memberships`).
class VipMembershipModel {
  const VipMembershipModel({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.status,
    required this.price,
    required this.currency,
    required this.startsAt,
    required this.endsAt,
    this.planName,
  });

  final String id;
  final String organizationId;
  final String organizationName;
  final String status;
  final double price;
  final String currency;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? planName;

  bool get isActive => status == 'active' && !endsAt.isBefore(DateTime.now());

  factory VipMembershipModel.fromJson(Map<String, dynamic> json) {
    return VipMembershipModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      organizationName: (json['organization_name'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?)?.trim() ?? 'BOB',
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      planName: json['plan_name'] as String?,
    );
  }
}
