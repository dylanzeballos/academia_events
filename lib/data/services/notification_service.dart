import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fcm_token_model.dart';
import '../repositories/fcm_token_repository.dart';

class NotificationService {
  final FcmTokenRepository _repository;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  NotificationService(this._repository);

  Future<void> initNotificationService() async {
    // 1. Pedir permisos al usuario
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Obtener el token actual del teléfono
      String? token = await _fcm.getToken();
      if (token != null) {
        await _syncTokenWithDatabase(token);
      }

      // 3. Escuchar si Firebase renueva el token
      _fcm.onTokenRefresh.listen((newToken) {
        _syncTokenWithDatabase(newToken);
      });
    }
  }

  Future<void> _syncTokenWithDatabase(String token) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final tokenModel = UserFcmTokenModel(
      userId: currentUser.id,
      fcmToken: token,
      deviceType: Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
    );

    await _repository.upsertToken(tokenModel);
  }
}