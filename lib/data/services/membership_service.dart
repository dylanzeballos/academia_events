import '../../core/config/supabase_config.dart';

class MembershipService {
  const MembershipService();

  Future<List<Map<String, dynamic>>> fetchPlans() async {
    final result = await supabase.from('subscription_plans')
        .select('id, name, description, price, currency, interval, can_create_events')
        .eq('is_active', true).order('price');
    return List<Map<String, dynamic>>.from(result);
  }

  Future<List<Map<String, dynamic>>> fetchOrganizationMemberships(String organizationId) async {
    final result = await supabase.from('subscriptions')
        .select('id, status, current_period_start, current_period_end, created_at, subscription_plans(name)')
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, dynamic>> request({
    required String organizationId,
    required String planId,
    String? paymentNote,
  }) async {
    final result = await supabase.rpc('request_organization_membership', params: {
      'p_organization_id': organizationId,
      'p_plan_id': planId,
      'p_payment_note': paymentNote,
    });
    return Map<String, dynamic>.from(result as Map);
  }
}
