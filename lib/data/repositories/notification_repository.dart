import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _supabase;

  NotificationRepository(this._supabase);

  // Escuchar en tiempo real las notificaciones del usuario
  Stream<List<NotificationModel>> streamUserNotifications(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => NotificationModel.fromJson(json)).toList());
  }

  // Marcar una notificación individual como leída
  Future<void> markAsRead(String notificationId) async {
    await _supabase.from('notifications').update({
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId);
  }

  // Marcar todas como leídas
  Future<void> markAllAsRead(String userId) async {
    await _supabase.from('notifications').update({
      'read_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId).isFilter('read_at', null);
  }
}