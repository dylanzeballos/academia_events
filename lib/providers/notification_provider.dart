import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notification_repository.dart';

// Provider del repositorio
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(Supabase.instance.client);
});

// StreamProvider en tiempo real con las notificaciones del usuario autenticado
final notificationsStreamProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    return Stream.value([]);
  }

  return repository.streamUserNotifications(user.id);
});

// Contador de notificaciones no leídas (ideal para el badge de la campana en la barra superior)
final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notificationsAsync = ref.watch(notificationsStreamProvider);
  return notificationsAsync.maybeWhen(
    data: (notifications) => notifications.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});