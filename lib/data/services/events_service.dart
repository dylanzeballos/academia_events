import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

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
          organizations(name, logo_url),
          event_categories(name),
          event_locations(*),
          event_images(*),
          ticket_types(*)
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
          organizations(name, logo_url),
          event_categories(name),
          event_locations(*),
          event_images(*),
          ticket_types(*)
        ''')
        .eq('organization_id', organizationId)
        .order('start_at');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchAllEvents() async {
    final response = await supabase
        .from('events')
        .select('''
          id, title, organization_id, category_id,
          description, cover_image_url,
          start_at, end_at, timezone,
          capacity, status, visibility,
          requires_approval, published_at, created_at,
          organizations(name, logo_url),
          event_categories(name),
          event_locations(*),
          event_images(*),
          ticket_types(*)
        ''')
        .order('start_at');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> fetchEventById(String id) async {
    final response = await supabase
        .from('events')
        .select('''
          id, title, organization_id, category_id,
          description, cover_image_url,
          start_at, end_at, timezone,
          capacity, status, visibility,
          requires_approval, published_at, created_at,
          organizations(name, logo_url),
          event_categories(name),
          event_locations(*),
          event_images(*),
          ticket_types(*)
        ''')
        .eq('id', id)
        .single();

    return Map<String, dynamic>.from(response);
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

  // ─── TICKETS, STORAGE Y SUB-TABLAS ────────────────────────────────

  Future<void> insertTicketTypes(List<Map<String, dynamic>> ticketsData) async {
    if (ticketsData.isEmpty) return;
    await supabase.from('ticket_types').insert(ticketsData);
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

  Future<String> uploadImage(String bucket, String path, Uint8List bytes) async {
    final contentType = _detectImageContentType(bytes);
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final fullPath = '$path.$ext';

    await supabase.storage.from(bucket).uploadBinary(
          fullPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
            cacheControl: '3600',
          ),
        );

    return supabase.storage.from(bucket).getPublicUrl(fullPath);
  }

  String _detectImageContentType(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x4E &&
        bytes[2] == 0x47 &&
        bytes[3] == 0x0D) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45) {
      return 'image/webp';
    }
    return 'image/jpeg';
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

  Future<List<Map<String, dynamic>>> fetchWeekSchedules(
    String startIso,
    String endIso,
  ) async {
    final response = await supabase
        .from('dance_class_schedules')
        .select('''
          id, dance_class_id, day_of_week,
          start_time, end_time,
          instructor_id,
          start_date, end_date,
          location_override, is_active,
          dance_classes!inner(
            id, title, organization_id,
            description, cover_image_url,
            status, capacity, price, currency,
            start_at, end_at, timezone,
            organizations!inner(name),
            profiles!instructor_id(first_name, last_name)
          )
        ''')
        .eq('is_active', true)
        .eq('dance_classes.status', 'published')
        .order('dance_class_id')
        .order('day_of_week');

    return List<Map<String, dynamic>>.from(response);
  }
}