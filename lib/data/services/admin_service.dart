import '../../core/config/supabase_config.dart';

enum AdminSection {
  dashboard('Resumen', 'dashboard'),
  users('Usuarios', 'users'),
  organizations('Organizaciones', 'organizations'),
  events('Eventos', 'events'),
  categories('Categorías', 'event_categories'),
  classes('Clases', 'dance_classes'),
  memberships('Membresías', 'subscriptions'),
  payments('Pagos', 'payments'),
  pagosya('PagosYa', ''),
  publicationPayments('Pagos de publicación', 'event_publication_payments'),
  sales('Ventas', 'orders'),
  payouts('Liquidaciones', 'payouts'),
  audit('Auditoría', 'audit_logs');

  const AdminSection(this.label, this.table);
  final String label;
  final String table;
}

class AdminSectionPage {
  const AdminSectionPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.counts,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int limit;
  final int offset;
  final Map<String, int> counts;

  static const empty = AdminSectionPage(
    items: [],
    total: 0,
    limit: 25,
    offset: 0,
    counts: {},
  );
}

class AdminService {
  const AdminService();

  Future<AdminSectionPage> fetch(
    AdminSection section, {
    int limit = 25,
    int offset = 0,
  }) async {
    final response = await supabase.rpc(
      'admin_fetch_section_page',
      params: {'p_section': section.name, 'p_limit': limit, 'p_offset': offset},
    );
    final data = response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{};
    final rawItems = data['items'];
    final items = (rawItems as List? ?? const [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final rawCounts = data['counts'];
    final counts = <String, int>{
      if (rawCounts is Map)
        for (final entry in rawCounts.entries)
          if (entry.value is num)
            entry.key.toString(): (entry.value as num).toInt(),
    };
    return AdminSectionPage(
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      counts: counts,
    );
  }

  Future<void> moderateEvent(String id, String status, {String? reason}) async {
    await supabase.rpc(
      'admin_set_event_moderation',
      params: {'p_event_id': id, 'p_status': status, 'p_reason': reason},
    );
  }

  Future<void> setOrganizationActive(String id, bool active) async {
    await supabase.rpc(
      'admin_set_organization_active',
      params: {'p_organization_id': id, 'p_active': active},
    );
  }

  Future<void> verifyMembership(String id, bool approve) async {
    await supabase.rpc(
      'admin_verify_subscription',
      params: {'p_subscription_id': id, 'p_approve': approve},
    );
  }

  Future<void> registerPayout({
    required String organizationId,
    required double amount,
    required String reference,
    String currency = 'BOB',
  }) async {
    await supabase.rpc(
      'admin_register_payout',
      params: {
        'p_organization_id': organizationId,
        'p_amount': amount,
        'p_currency': currency,
        'p_reference': reference,
      },
    );
  }

  Future<void> setPayoutStatus(String id, String status) async {
    await supabase.rpc(
      'admin_set_payout_status',
      params: {'p_payout_id': id, 'p_status': status},
    );
  }

  // ─── Configuración de pagos ───────────────────────

  Future<double> setEventPublicationPrice(double price) async {
    final result = await supabase.rpc(
      'admin_set_event_publication_price',
      params: {'p_price': price},
    );
    final value = result is num
        ? result.toDouble()
        : double.tryParse('$result');
    return value ?? price;
  }

  // ─── Categorías de eventos ─────────────────────────

  /// Crea una categoría si [id] es null; si no, la actualiza. Devuelve el id.
  Future<String> saveEventCategory({
    String? id,
    required String name,
    bool isActive = true,
  }) async {
    final result = await supabase.rpc(
      'admin_save_event_category',
      params: {'p_id': id, 'p_name': name, 'p_is_active': isActive},
    );
    return result.toString();
  }

  Future<void> setEventCategoryActive(String id, bool active) async {
    await supabase.rpc(
      'admin_set_event_category_active',
      params: {'p_id': id, 'p_active': active},
    );
  }

  // ─── Planes de membresía ───────────────────────────

  Future<List<Map<String, dynamic>>> fetchMembershipPlans() async {
    final response = await supabase.rpc('admin_list_membership_plans');
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Crea un plan si [id] es null; si no, lo actualiza. Devuelve el id.
  Future<String> saveMembershipPlan({
    String? id,
    required String name,
    String? description,
    required double price,
    String currency = 'BOB',
    String interval = 'monthly',
    bool isActive = true,
    bool canCreateEvents = false,
    bool canCreateClasses = false,
    bool showInCalendar = false,
    int? maxEventsPerMonth,
    int? maxClassesPerMonth,
  }) async {
    final result = await supabase.rpc(
      'admin_save_membership_plan',
      params: {
        'p_id': id,
        'p_name': name,
        'p_description': description,
        'p_price': price,
        'p_currency': currency,
        'p_interval': interval,
        'p_is_active': isActive,
        'p_can_create_events': canCreateEvents,
        'p_can_create_classes': canCreateClasses,
        'p_show_in_calendar': showInCalendar,
        'p_max_events_per_month': maxEventsPerMonth,
        'p_max_classes_per_month': maxClassesPerMonth,
      },
    );
    return result.toString();
  }

  Future<void> setMembershipPlanActive(String id, bool active) async {
    await supabase.rpc(
      'admin_set_membership_plan_active',
      params: {'p_id': id, 'p_active': active},
    );
  }
}
