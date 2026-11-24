import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(Supabase.instance.client);
});

/// Guarda en memoria los IDs marcados como leídos para reflejarlo al instante en toda la app
class _ReadOverridesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void markOne(String id) => state = {...state, id};
  void markMany(Iterable<String> ids) => state = {...state, ...ids};
}

final _readOverridesProvider =
    NotifierProvider<_ReadOverridesNotifier, Set<String>>(_ReadOverridesNotifier.new);

/// Stream activo mientras exista sesión (sin autoDispose para no reiniciar el socket al cambiar de pestaña)
final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    return Stream.value(const <NotificationModel>[]);
  }

  return repository.streamUserNotifications(user.id);
});

/// Lista combinada con actualización inmediata + sincronización con Supabase
final effectiveNotificationsProvider = Provider<AsyncValue<List<NotificationModel>>>((ref) {
  final asyncList = ref.watch(notificationsStreamProvider);
  final readIds = ref.watch(_readOverridesProvider);

  return asyncList.whenData((notifications) {
    return notifications.map((n) {
      if (n.isRead || readIds.contains(n.id)) {
        return NotificationModel(
          id: n.id,
          userId: n.userId,
          type: n.type,
          title: n.title,
          message: n.message,
          createdAt: n.createdAt,
          readAt: n.readAt ?? DateTime.now(),
        );
      }
      return n;
    }).toList();
  });
});

/// Contador exacto para InstagramNavBar: baja a 0 y oculta el Badge al instante
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final effectiveAsync = ref.watch(effectiveNotificationsProvider);
  return effectiveAsync.maybeWhen(
    data: (notifications) => notifications.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

/// Helper único para marcar como leída una o todas las notificaciones
final notificationActionsProvider = Provider<NotificationActions>((ref) {
  return NotificationActions(ref);
});

class NotificationActions {
  final Ref _ref;
  NotificationActions(this._ref);

  Future<void> markAsRead(String notificationId) async {
    _ref.read(_readOverridesProvider.notifier).markOne(notificationId);
    try {
      await _ref.read(notificationRepositoryProvider).markAsRead(notificationId);
    } catch (_) {}
  }

  Future<void> markAllAsRead(String userId) async {
    final current = _ref.read(effectiveNotificationsProvider).asData?.value ?? [];
    _ref.read(_readOverridesProvider.notifier).markMany(current.map((e) => e.id));
    try {
      await _ref.read(notificationRepositoryProvider).markAllAsRead(userId);
    } catch (_) {}
  }
}