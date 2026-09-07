import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class TicketException implements Exception {
  const TicketException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TicketService {
  const TicketService();

  Future<List<Map<String, dynamic>>> fetchTicketTypes(String eventId) async {
    try {
      final rows = await supabase
          .from('ticket_types')
          .select('id, event_id, name, description, price, currency, quantity, sold_quantity')
          .eq('event_id', eventId)
          .eq('is_active', true)
          .order('price', ascending: true);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw TicketException(e.message);
    }
  }

  Future<Map<String, dynamic>> createEventOrder({
    required String ticketTypeId,
    required int quantity,
    List<String>? attendeeNames,
  }) async {
    try {
      final result = await supabase.rpc('create_event_order', params: {
        'p_ticket_type_id': ticketTypeId,
        'p_quantity': quantity,
        if (attendeeNames != null) 'p_attendee_names': attendeeNames,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw TicketException(e.message);
    }
  }

  Future<Map<String, dynamic>> confirmEventOrderPayment({
    required String orderId,
    String provider = 'simulated',
    String? providerPaymentId,
  }) async {
    try {
      final result = await supabase.rpc('confirm_event_order_payment', params: {
        'p_order_id': orderId,
        'p_provider': provider,
        'p_provider_payment_id': providerPaymentId,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw TicketException(e.message);
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserEventTickets() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw const TicketException('No autenticado');

      final rows = await supabase
          .from('tickets')
          .select('''
            id, order_id, ticket_number, attendee_name, status, created_at,
            ticket_types!inner(
              name,
              events!inner(id, title, cover_image_url, start_at)
            ),
            ticket_qr_codes(token_hash)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (rows as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);

        final qrData = map['ticket_qr_codes'];
        String? token;
        if (qrData is Map) {
          token = qrData['token_hash']?.toString();
        } else if (qrData is List && qrData.isNotEmpty) {
          token = (qrData.first as Map)['token_hash']?.toString();
        }

        map['qr_data'] = token ?? map['ticket_number']?.toString();
        map['attendee_name'] = map['attendee_name']?.toString();
        return map;
      }).toList();
    } on PostgrestException catch (e) {
      throw TicketException(e.message);
    }
  }

  Future<Map<String, dynamic>> fetchOrderPurchaseResult(String orderId) async {
    try {
      final row = await supabase
          .from('orders')
          .select('''
            id,
            order_number,
            subtotal,
            total_amount,
            events(title),
            tickets(
              id,
              ticket_number,
              attendee_name,
              ticket_qr_codes(token_hash)
            )
          ''')
          .eq('id', orderId)
          .single();

      final ticketsList = (row['tickets'] as List? ?? []).map((t) {
        final qrData = t['ticket_qr_codes'];
        String token = '';

        if (qrData is Map) {
          token = qrData['token_hash']?.toString() ?? '';
        } else if (qrData is List && qrData.isNotEmpty) {
          token = (qrData.first as Map)['token_hash']?.toString() ?? '';
        }

        final ticketNum = t['ticket_number']?.toString() ?? '';

        return {
          'ticket_id': t['id']?.toString() ?? '',
          'ticket_number': ticketNum,
          'attendee_name': t['attendee_name']?.toString(),
          'qr_token': token.isNotEmpty ? token : ticketNum,
        };
      }).toList();

      // Extracción a prueba de nulos o variaciones de estructura
      String eventTitle = 'Evento';
      final eventData = row['events'];
      if (eventData is Map) {
        eventTitle = eventData['title']?.toString() ?? 'Evento';
      } else if (eventData is List && eventData.isNotEmpty) {
        eventTitle = (eventData.first as Map)['title']?.toString() ?? 'Evento';
      }

      return {
        'order_id': row['id']?.toString() ?? orderId,
        'order_number': row['order_number']?.toString() ?? '',
        'subtotal': (row['subtotal'] as num?)?.toDouble() ?? 
                    (row['total_amount'] as num?)?.toDouble() ?? 0.0,
        'quantity': ticketsList.length,
        'event_title': eventTitle,
        'tickets': ticketsList,
      };
    } on PostgrestException catch (e) {
      throw TicketException(e.message);
    } catch (e) {
      throw TicketException(e.toString());
    }
  }
}