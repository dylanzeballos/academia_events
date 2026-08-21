import 'dart:typed_data';

import '../../core/config/supabase_config.dart';

class EventsService {
  const EventsService();

  // ─── CONSULTAS DE EVENTOS ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchWeekEvents(
    String startIso,
    String endIso,
  ) async {
    final response = await supabase
        .from('events')
        .select('''
          id, title, organization_id, category_id,
          description, cover_image_url,
          start_at, end_at, timezone,
          capacity, status, visibility,
          requires_approval, published_at, created_at,
          organizations!inner(name),
          event_locations(*),
          event_images(*)
        ''')
        .gte('start_at', startIso)
        .lte('start_at', endIso)
        .eq('status', 'published')
        .order('start_at');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchOrganizationEvents(
    String organizationId,
  ) async {
    final response = await supabase
        .from('events')
        .select('''
          id, title, organization_id, category_id,
          description, cover_image_url,
          start_at, end_at, timezone,
          capacity, status, visibility,
          requires_approval, published_at, created_at,
          event_categories(name),
          event_locations(*),
          event_images(*)
        ''')
        .eq('organization_id', organizationId)
        .order('start_at');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> insertEvent(Map<String, dynamic> data) async {
    return await supabase.from('events').insert(data).select().single();
  }

  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    await supabase.from('events').update(data).eq('id', id);
  }

  Future<void> deleteEvent(String id) async {
    await supabase.from('events').delete().eq('id', id);
  }

  // ─── STORAGE Y SUB-TABLAS ─────────────────────────────────────────

  Future<String> uploadImage(String folder, Uint8List bytes) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$folder/$fileName';

    await supabase.storage.from('events').uploadBinary(path, bytes);
    return supabase.storage.from('events').getPublicUrl(path);
  }

  Future<void> insertLocation(Map<String, dynamic> locationData) async {
    await supabase.from('event_locations').insert(locationData);
  }

  Future<void> insertEventImage(String eventId, String imageUrl) async {
    await supabase.from('event_images').insert({
      'event_id': eventId,
      'image_url': imageUrl,
      'sort_order': 1,
    });
  }

  // ─── CONSULTAS DE CLASES ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchOrganizationClasses(
    String organizationId,
  ) async {
    final response = await supabase
        .from('dance_classes')
        .select(
          'id, title, organization_id, '
          'description, cover_image_url, '
          'status, capacity, price, currency, '
          'start_at, end_at, timezone',
        )
        .eq('organization_id', organizationId)
        .order('start_at');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> insertClass(Map<String, dynamic> data) async {
    return await supabase.from('dance_classes').insert(data).select().single();
  }

  Future<void> updateClass(String id, Map<String, dynamic> data) async {
    await supabase.from('dance_classes').update(data).eq('id', id);
  }

  Future<void> deleteClass(String id) async {
    await supabase.from('dance_classes').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> fetchWeekClasses(
    String startIso,
    String endIso,
  ) async {
    final response = await supabase
        .from('dance_classes')
        .select('''
          id, title, organization_id,
          description, cover_image_url,
          status, capacity, price, currency,
          start_at, end_at, timezone,
          organizations!inner(name)
        ''')
        .gte('start_at', startIso)
        .lte('start_at', endIso)
        .eq('status', 'published')
        .order('start_at');

    return List<Map<String, dynamic>>.from(response);
  }
}