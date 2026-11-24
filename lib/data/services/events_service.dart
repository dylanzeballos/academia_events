import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/seat_model.dart';

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
          id, title, organization_id, category_id, venue_id,
          description, cover_image_url, contact_phone, rules_pdf_url,
          start_at, end_at, timezone,
          capacity, status, visibility,
          requires_approval, published_at, created_at,
          organizations(name, logo_url),
          event_categories(name),
          event_dance_categories(dance_category_id, dance_categories(name)),
          event_locations(*),
          event_images(*),
          ticket_types(*)
        ''')
        .or('start_at.lte.$endIso,end_at.gte.$startIso')
        .eq('status', 'published')
        .eq('moderation_status', 'approved')
        .order('start_at');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchOrganizationEvents(
    String organizationId,
  ) async {
    final response = await supabase
        .from('events')
        .select('''
          id, title, organization_id, category_id, venue_id,
          description, cover_image_url, contact_phone, rules_pdf_url,
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
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchAllEvents() async {
    final response = await supabase
        .from('events')
        .select('''
          id, title, organization_id, category_id, venue_id,
          description, cover_image_url, contact_phone, rules_pdf_url,
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
          id, title, organization_id, category_id, venue_id,
          description, cover_image_url, contact_phone, rules_pdf_url,
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
    final deleted = await supabase
        .from('events')
        .delete()
        .eq('id', id)
        .select('id');

    if (deleted.isEmpty) {
      throw Exception(
        'No tienes permisos para eliminar este evento en esta organización.',
      );
    }
  }

  // ─── TICKETS, STORAGE Y REGLAMENTO ────────────────────────────────

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

  Future<String> uploadImage(
    String bucket,
    String path,
    Uint8List bytes,
  ) async {
    final contentType = _detectImageContentType(bytes);
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final fullPath = '$path.$ext';

    await supabase.storage
        .from(bucket)
        .uploadBinary(
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

  Future<String> uploadRulesPdf(String eventId, Uint8List pdfBytes) async {
    final fullPath = '$eventId/reglamento.pdf';

    await supabase.storage
        .from('event-documents')
        .uploadBinary(
          fullPath,
          pdfBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/pdf',
            cacheControl: '3600',
          ),
        );

    return supabase.storage.from('event-documents').getPublicUrl(fullPath);
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

  // ─── CLASES ───────────────────────────────────────────────────────

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

  // ─── TEATROS Y BUTACAS ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchVenues() async {
    final rows = await supabase
        .from('venue_templates')
        .select('id, name, description, address, total_capacity')
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> cloneVenueSeats({
    required String eventId,
    required String venueId,
    required double defaultPrice,
  }) async {
    await supabase.rpc(
      'clone_venue_seats_to_event',
      params: {
        'p_event_id': eventId,
        'p_venue_id': venueId,
        'p_default_price': defaultPrice,
      },
    );
  }

  Future<SeatMapModel> fetchSeatMap(String eventId) async {
    final res = await supabase.rpc(
      'get_event_seat_map',
      params: {'p_event_id': eventId},
    );
    return SeatMapModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<int> holdSeat(String seatId) async {
    final res = await supabase.rpc(
      'hold_event_seat',
      params: {'p_seat_id': seatId, 'p_minutes': 10},
    );
    return (res as num).toInt();
  }

  Future<void> releaseSeat(String seatId) async {
    await supabase.rpc('release_event_seat', params: {'p_seat_id': seatId});
  }

  Future<void> releaseAllMyHolds() async {
    await supabase.rpc('release_my_seat_holds');
  }

  Future<void> confirmSeatPurchase({
    required String orderId,
    required List<String> seatIds,
  }) async {
    await supabase.rpc(
      'confirm_seat_purchase',
      params: {'p_order_id': orderId, 'p_seat_ids': seatIds},
    );
  }
}
