import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fcm_token_model.dart';
import '../repositories/fcm_token_repository.dart';

class NotificationService {
  final FcmTokenRepository _repository;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;

  NotificationService(this._repository);

  /// Pide permisos (Android 13+ / iOS) y registra el token del dispositivo.
  /// Es idempotente: se puede llamar en cada inicio de sesión sin duplicar
  /// listeners ni peticiones innecesarias.
  Future<void> initNotificationService() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final status = settings.authorizationStatus;
    final canNotify =
        status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    if (!canNotify) {
      debugPrint(
        'Notificaciones push sin permiso (estado: ${status.name}). '
        'El usuario puede habilitarlas desde los ajustes del sistema.',
      );
      return;
    }

    await syncTokenForCurrentUser();

    // Se registra una sola vez aunque haya varios inicios de sesión.
    if (!_initialized) {
      _initialized = true;
      // La API nueva (onRegistered) devuelve el FID, pero el backend envía a
      // FCM v1 por `token`; por eso se mantiene el token clásico.
      // ignore: deprecated_member_use
      _tokenRefreshSubscription = _fcm.onTokenRefresh.listen(
        _syncTokenWithDatabase,
        onError: (Object error) {
          debugPrint('Error renovando token FCM: $error');
        },
      );
    }
  }

  /// Vuelve a asociar el token actual con el usuario autenticado.
  Future<void> syncTokenForCurrentUser() async {
    try {
      // ignore: deprecated_member_use
      final token = await _fcm.getToken();
      if (token != null) {
        await _syncTokenWithDatabase(token);
      }
    } catch (error) {
      debugPrint('No se pudo obtener el token FCM: $error');
    }
  }

  /// Elimina el token del dispositivo del usuario actual. Se llama antes de
  /// cerrar sesión para que el siguiente usuario no reciba avisos ajenos.
  Future<void> clearToken() async {
    try {
      // ignore: deprecated_member_use
      final token = await _fcm.getToken();
      if (token != null) {
        await _repository.deleteToken(token);
      }
    } catch (error) {
      debugPrint('No se pudo eliminar el token FCM: $error');
    }
  }

  Future<void> _syncTokenWithDatabase(String token) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final tokenModel = UserFcmTokenModel(
        userId: currentUser.id,
        fcmToken: token,
        deviceType: Platform.isAndroid
            ? 'android'
            : (Platform.isIOS ? 'ios' : 'other'),
      );

      await _repository.upsertToken(tokenModel);
    } catch (error) {
      debugPrint('No se pudo guardar el token FCM: $error');
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _initialized = false;
  }
}
