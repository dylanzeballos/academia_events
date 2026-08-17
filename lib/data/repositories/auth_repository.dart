import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';
import '../services/auth_service.dart';

abstract interface class IAuthRepository {
  User? get currentUser;
  bool get isAuthenticated;
  Stream<AuthState> get authStateChanges;

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  });

  Future<void> signIn({required String email, required String password});
  Future<void> signInWithGoogle();
  Future<void> signOut();

  Future<void> sendPasswordRecovery(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> updateEmail(String email);

  Future<ProfileModel?> fetchCurrentProfile();
  Future<UserRole> fetchUserRole();
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? phone,
    bool? isActive,
    String? avatarPath,
  });
  Future<String> uploadAvatar(Uint8List bytes, {required String extension});
  Future<String?> avatarSignedUrl(String? path);
}

class AuthRepository implements IAuthRepository {
  const AuthRepository({AuthService? authService})
      : _auth = authService ?? const AuthService();

  final AuthService _auth;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  bool get isAuthenticated => _auth.isAuthenticated;

  @override
  Stream<AuthState> get authStateChanges => _auth.authStateChanges;

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );

    final userId = response.user?.id;
    if (userId != null) {
      final splitName = _splitName(fullName);
      await _auth.upsertProfile({
        'id': userId,
        'first_name': splitName.$1,
        'last_name': splitName.$2,
      });
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final response = await _auth.signIn(email: email, password: password);
    final user = response.user;
    if (user != null) {
      final fullName = user.userMetadata?['full_name'] as String?;
      final splitName = _splitName(fullName);
      await _auth.upsertProfile({
        'id': user.id,
        'first_name': splitName.$1,
        'last_name': splitName.$2,
      });
    }
  }

  @override
  Future<void> signInWithGoogle() => _auth.signInWithGoogle();

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordRecovery(String email) =>
      _auth.sendPasswordRecovery(email: email);

  @override
  Future<void> updatePassword(String newPassword) =>
      _auth.updatePassword(newPassword);

  @override
  Future<void> updateEmail(String email) => _auth.updateEmail(email);

  @override
  Future<ProfileModel?> fetchCurrentProfile() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return null;

    var raw = await _auth.fetchProfile(userId);

    if (raw == null) {
      final fullName =
          _auth.currentUser?.userMetadata?['full_name'] as String?;
      final splitName = _splitName(fullName);
      await _auth.upsertProfile({
        'id': userId,
        'first_name': splitName.$1,
        'last_name': splitName.$2,
      });
      raw = await _auth.fetchProfile(userId);
    }

    return raw != null ? ProfileModel.fromJson(raw) : null;
  }

  @override
  Future<UserRole> fetchUserRole() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return UserRole.student;

    final isMember = await _auth.isOrganizationMember(userId);
    return isMember ? UserRole.academy : UserRole.student;
  }

  @override
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? phone,
    bool? isActive,
    String? avatarPath,
  }) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) throw const AuthException('No autenticado');

    final payload = <String, dynamic>{
      'id': userId,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'phone_number': phone?.trim().isEmpty == true ? null : phone?.trim(),
    };
    if (isActive != null) payload['is_active'] = isActive;
    if (avatarPath != null) payload['profile_image_url'] = avatarPath;

    await _auth.upsertProfile(payload);
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, {required String extension}) {
    final userId = _auth.currentUser?.id;
    if (userId == null) throw const AuthException('No autenticado');
    return _auth.uploadAvatar(userId, bytes, extension: extension);
  }

  @override
  Future<String?> avatarSignedUrl(String? path) => _auth.avatarSignedUrl(path);

  (String, String) _splitName(String? fullName) {
    final parts = (fullName ?? '')
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    return (
      parts.isNotEmpty ? parts.first : 'Usuario',
      parts.length > 1 ? parts.sublist(1).join(' ') : 'Nuevo',
    );
  }
}
