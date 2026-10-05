import '../../core/config/supabase_config.dart';

class EventAccessService {
  const EventAccessService();

  Future<List<Map<String, dynamic>>> fetchPoints(String eventId) async {
    final rows = await supabase
        .from('event_access_points')
        .select('id, event_id, name, description, is_active, event_access_point_staff(organization_member_id, organization_members(id, user_id, role, is_active, profiles(first_name, last_name)))')
        .eq('event_id', eventId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchOrganizationMembers(String organizationId) async {
    final rows = await supabase
        .from('organization_members')
        .select('id, user_id, role, is_active, profiles(first_name, last_name)')
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> savePoint({
    String? id,
    required String eventId,
    required String name,
    String? description,
  }) async {
    final values = {'name': name.trim(), 'description': description?.trim()};
    if (id == null) {
      await supabase.from('event_access_points').insert({'event_id': eventId, ...values});
    } else {
      await supabase.from('event_access_points').update(values).eq('id', id);
    }
  }

  Future<void> setActive(String id, bool active) async {
    await supabase.from('event_access_points').update({'is_active': active}).eq('id', id);
  }

  Future<void> setMemberAssigned(String accessPointId, String memberId, bool assigned) async {
    final query = supabase.from('event_access_point_staff');
    if (assigned) {
      await query.insert({'access_point_id': accessPointId, 'organization_member_id': memberId});
    } else {
      await query.delete().eq('access_point_id', accessPointId)
          .eq('organization_member_id', memberId);
    }
  }
}
