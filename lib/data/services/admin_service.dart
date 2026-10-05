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
  publicationPayments('Pagos de publicación', 'event_publication_payments'),
  classPublicationPayments('Publicación de clases', 'dance_class_publication_payments'),
  sales('Ventas', 'orders'),
  payouts('Liquidaciones', 'payouts'),
  audit('Auditoría', 'audit_logs');

  const AdminSection(this.label, this.table);
  final String label;
  final String table;
}

class AdminService {
  const AdminService();

  Future<List<Map<String, dynamic>>> fetch(AdminSection section) async {
    final response = await supabase.rpc('admin_fetch_section', params: {
      'p_section': section.name,
    });
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> moderateEvent(String id, String status, {String? reason}) async {
    await supabase.rpc('admin_set_event_moderation', params: {
      'p_event_id': id,
      'p_status': status,
      'p_reason': reason,
    });
  }

  Future<void> setOrganizationActive(String id, bool active) async {
    await supabase.rpc('admin_set_organization_active', params: {
      'p_organization_id': id,
      'p_active': active,
    });
  }

  Future<void> verifyMembership(String id, bool approve) async {
    await supabase.rpc('admin_verify_subscription', params: {
      'p_subscription_id': id,
      'p_approve': approve,
    });
  }

  Future<void> registerPayout({
    required String organizationId,
    required double amount,
    required String reference,
    String currency = 'BOB',
  }) async {
    await supabase.rpc('admin_register_payout', params: {
      'p_organization_id': organizationId,
      'p_amount': amount,
      'p_currency': currency,
      'p_reference': reference,
    });
  }

  Future<void> setPayoutStatus(String id, String status) async {
    await supabase.rpc('admin_set_payout_status', params: {
      'p_payout_id': id,
      'p_status': status,
    });
  }
}
