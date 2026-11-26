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
        .map(
          (data) =>
              data.map((json) => NotificationModel.fromJson(json)).toList(),
        );
  }

  // Marcar una notificación individual como leída
  Future<void> markAsRead(String notificationId) async {
    final updatedRows = await _supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId)
        .select('id');

    if (updatedRows.isEmpty) {
      throw StateError(
        'La notificación no existe o ya fue marcada como leída.',
      );
    }
  }

  // Marcar todas como leídas
  Future<void> markAllAsRead(String userId) async {
    await _supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }

  // Marcar una notificación como no leída
  Future<void> markAsUnread(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'read_at': null})
        .eq('id', notificationId);
  }

  // Eliminar una notificación
  Future<void> deleteNotification(String notificationId) async {
    await _supabase.from('notifications').delete().eq('id', notificationId);
  }

  // Eliminar todos los avisos del usuario (solo quedan los de hoy)
  Future<void> deleteAll(String userId) async {
    await _supabase.from('notifications').delete().eq('user_id', userId);
  }
}
