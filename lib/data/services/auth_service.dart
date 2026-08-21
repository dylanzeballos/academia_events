import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'storage_service.dart';

class AuthService {
  const AuthService({StorageService? storage})
      : _storage = storage ?? const StorageService();

  final StorageService _storage;

  User? get currentUser => supabase.auth.currentUser;
  Session? get currentSession => supabase.auth.currentSession;
  bool get isAuthenticated => currentSession != null;
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  String get _oauthRedirectUrl {
    if (kIsWeb) {
      // En web, redirigir a la misma URL del navegador
      return '${Uri.base.origin}/auth/callback';
    }
    // En móvil, usar deep link
    return 'io.supabase.academia-events://login-callback/';
  }

  Future<void> signInWithGoogle() {
    return supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _oauthRedirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.inAppWebView
          : LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() => supabase.auth.signOut();

  Future<void> sendPasswordRecovery({
    required String email,
    String? redirectTo,
  }) {
    return supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }

  Future<UserResponse> updatePassword(String newPassword) =>
      supabase.auth.updateUser(UserAttributes(password: newPassword));

  Future<UserResponse> updateEmail(String email, {String? emailRedirectTo}) =>
      supabase.auth.updateUser(
        UserAttributes(email: email.trim()),
        emailRedirectTo: emailRedirectTo,
      );

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    return supabase
        .from('profiles')
        .select(
          'id, first_name, last_name, phone_number, profile_image_url, '
          'is_active, created_at, updated_at',
        )
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> upsertProfile(Map<String, dynamic> data) async {
    await supabase.from('profiles').upsert(data);
  }

  Future<bool> isOrganizationMember(String userId) async {
    final result = await supabase
        .from('organization_members')
        .select('id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .limit(1);
    return result.isNotEmpty;
  }

  Future<String> uploadAvatar(
    String userId,
    Uint8List bytes, {
    required String extension,
  }) =>
      _storage.uploadAvatar(userId, bytes, extension: extension);

  /// Resuelve el valor guardado en profile_image_url a una URL mostrable.
  /// El bucket de avatares es público: los paths se convierten a URL pública
  /// (permanente). Las URLs firmadas antiguas se reparan extrayendo su path.
  String? resolveAvatarUrl(String? stored) {
    if (stored == null || stored.trim().isEmpty) return null;

    if (stored.startsWith('http://') || stored.startsWith('https://')) {
      final path = StorageService.extractPathFromSignedUrl(stored);
      // URL externa (p. ej. foto de Google): devolver tal cual.
      return path != null ? _storage.publicUrl(path) : stored;
    }

    // Path relativo dentro del bucket.
    return _storage.publicUrl(stored);
  }
}
