import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract class IAuthService {
  User? get currentUser;
  Session? get currentSession;
  bool get isAuthenticated;
  Stream<AuthState> get onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  });

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendPasswordRecovery({
    required String email,
    String? redirectTo,
  });

  Future<UserResponse> updatePassword({required String newPassword});

  Future<void> ensureAuthenticated();
  bool consumeManualSignOutFlag();
  Future<Map<String, dynamic>?> fetchCurrentProfile();
  Future<void> upsertMyProfile({String? fullName});
  Future<void> updateMyProfile({
    required String firstName,
    required String lastName,
    String? phone,
    bool? isActive,
    String? avatarPath,
  });
  Future<String> uploadAvatar(Uint8List bytes, {required String extension});
  Future<String?> createAvatarSignedUrl(String avatarPath);
  Future<UserResponse> updateEmail(String email, {String? emailRedirectTo});
  Future<void> setMyAccountActive(bool isActive);
}

class AuthService implements IAuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  final SupabaseClient _client = Supabase.instance.client;

  bool _manualSignOut = false;
  static const _avatarBucket = 'profile-avatars';

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  bool get isAuthenticated => currentSession != null;

  @override
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );

    final userId = response.user?.id;
    if (userId != null) {
      await upsertMyProfile(fullName: fullName);
    }

    return response;
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user != null) {
      await upsertMyProfile(
        fullName: user.userMetadata?['full_name'] as String?,
      );
    }

    return response;
  }

  @override
  Future<void> signOut() async {
    _manualSignOut = true;
    await _client.auth.signOut();
  }

  @override
  Future<void> sendPasswordRecovery({
    required String email,
    String? redirectTo,
  }) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }

  @override
  Future<UserResponse> updatePassword({required String newPassword}) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> ensureAuthenticated() async {
    if (currentSession == null || currentUser == null) {
      throw const AuthException('Sesion expirada. Inicia sesion nuevamente.');
    }
  }

  @override
  bool consumeManualSignOutFlag() {
    final wasManual = _manualSignOut;
    _manualSignOut = false;
    return wasManual;
  }

  @override
  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    await ensureAuthenticated();

    Map<String, dynamic>? profile;

    try {
      profile = await _client
          .from('profiles')
          .select(
            'id, first_name, last_name, phone_number, profile_image_url, is_active, created_at, updated_at, deleted_at',
          )
          .eq('id', currentUser!.id)
          .maybeSingle();
    } on PostgrestException catch (e) {
      if (e.code != '42703') {
        rethrow;
      }

      profile = await _client
          .from('profiles')
          .select(
            'id, first_name, last_name, phone_number, profile_image_url, is_active, created_at, updated_at, deleted_at',
          )
          .eq('id', currentUser!.id)
          .maybeSingle();
    }

    if (profile == null) {
      final metadataFullName =
          (_client.auth.currentUser?.userMetadata?['full_name'] as String?)
              ?.trim();
      final splitName = (metadataFullName ?? '')
          .split(' ')
          .where((value) => value.isNotEmpty)
          .toList();

      final firstName = splitName.isNotEmpty ? splitName.first : 'Usuario';
      final lastName = splitName.length > 1 ? splitName.sublist(1).join(' ') : 'Nuevo';

      await _client.from('profiles').upsert({
        'id': currentUser!.id,
        'first_name': firstName,
        'last_name': lastName,
      });

      profile = await _client
          .from('profiles')
          .select(
            'id, first_name, last_name, phone_number, profile_image_url, is_active, created_at, updated_at, deleted_at',
          )
          .eq('id', currentUser!.id)
          .maybeSingle();
    }

    return profile;
  }

  @override
  Future<void> upsertMyProfile({String? fullName}) async {
    await ensureAuthenticated();

    final splitName = (fullName ?? '')
        .trim()
        .split(' ')
        .where((value) => value.isNotEmpty)
        .toList();
    final firstName = splitName.isNotEmpty ? splitName.first : 'Usuario';
    final lastName = splitName.length > 1 ? splitName.sublist(1).join(' ') : 'Nuevo';

    await _client.from('profiles').upsert({
      'id': currentUser!.id,
      'first_name': firstName,
      'last_name': lastName,
    });
  }

  @override
  Future<void> updateMyProfile({
    required String firstName,
    required String lastName,
    String? phone,
    bool? isActive,
    String? avatarPath,
  }) async {
    await ensureAuthenticated();

    final firstNameValue = firstName.trim();
    final lastNameValue = lastName.trim();

    final payload = <String, dynamic>{
      'id': currentUser!.id,
      'first_name': firstNameValue,
      'last_name': lastNameValue,
      'phone_number': phone?.trim().isEmpty == true ? null : phone?.trim(),
      // 'birth_date': birthDate?.toIso8601String().split('T').first,
    };

    if (isActive != null) {
      payload['is_active'] = isActive;
    }
    if (avatarPath != null) {
      payload['profile_image_url'] = avatarPath;
    }

    try {
      await _client.from('profiles').upsert(payload);
    } on PostgrestException catch (e) {
      if (e.code != '42703') {
        rethrow;
      }

      payload.remove('birth_date');
      await _client.from('profiles').upsert(payload);
    }
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, {required String extension}) async {
    await ensureAuthenticated();

    final userId = currentUser!.id;
    final cleanExtension = extension.toLowerCase().replaceAll('.', '');
    final path = '$userId/avatar.$cleanExtension';
    final contentType = cleanExtension == 'png' ? 'image/png' : 'image/jpeg';

    try {
      await _client.storage.from(_avatarBucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: contentType,
          cacheControl: '3600',
        ),
      );
    } on StorageException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('bucket') && message.contains('not')) {
        throw const AuthException(
          'No existe el bucket profile-avatars. Ejecuta migraciones de Supabase.',
        );
      }
      if (message.contains('permission') ||
          message.contains('not allowed') ||
          message.contains('row-level security')) {
        throw const AuthException(
          'Sin permisos para subir imagen. Revisa policies de storage.objects.',
        );
      }

      throw AuthException('Error al subir imagen: ${e.message}');
    }

    return path;
  }

  @override
  Future<String?> createAvatarSignedUrl(String avatarPath) async {
    await ensureAuthenticated();
    if (avatarPath.trim().isEmpty) {
      return null;
    }

    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return avatarPath;
    }

    final signedUrl = await _client.storage
        .from(_avatarBucket)
        .createSignedUrl(avatarPath, 60 * 60);
    return signedUrl;
  }

  @override
  Future<UserResponse> updateEmail(String email, {String? emailRedirectTo}) {
    return _client.auth.updateUser(
      UserAttributes(email: email.trim()),
      emailRedirectTo: emailRedirectTo,
    );
  }

  @override
  Future<void> setMyAccountActive(bool isActive) async {
    await ensureAuthenticated();
    await _client.from('profiles').upsert({
      'id': currentUser!.id,
      'is_active': isActive,
    });
  }
}