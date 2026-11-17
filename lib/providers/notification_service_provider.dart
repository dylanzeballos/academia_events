import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/fcm_token_repository.dart';
import '../data/services/notification_service.dart';

/// Servicio único de notificaciones para toda la app.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    FcmTokenRepository(Supabase.instance.client),
  );
  ref.onDispose(service.dispose);
  return service;
});
