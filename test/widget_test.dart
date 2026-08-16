import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

import 'package:academia_events/auth/auth_gate.dart';
import 'package:academia_events/auth/auth_service.dart';

void main() {
  testWidgets('Rutas privadas bloqueadas sin autenticacion', (
    WidgetTester tester,
  ) async {
    final fakeAuth = _FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(authService: fakeAuth),
      ),
    );

    expect(find.text('Iniciar sesion'), findsOneWidget);
    expect(find.text('HORARIO'), findsNothing);
  });
}

class _FakeAuthService implements IAuthService {
  final Stream<AuthState> _stream = const Stream<AuthState>.empty();

  @override
  User? get currentUser => null;

  @override
  Session? get currentSession => null;

  @override
  bool get isAuthenticated => false;

  @override
  Stream<AuthState> get onAuthStateChange => _stream;

  @override
  bool consumeManualSignOutFlag() => false;

  @override
  Future<void> ensureAuthenticated() async {}

  @override
  Future<Map<String, dynamic>?> fetchCurrentProfile() async => null;

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordRecovery({
    required String email,
    String? redirectTo,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserResponse> updatePassword({required String newPassword}) {
    throw UnimplementedError();
  }

  @override
  Future<String?> createAvatarSignedUrl(String avatarPath) async => null;

  @override
  Future<void> updateMyProfile({
    required String firstName,
    required String lastName,
    String? phone,
    DateTime? birthDate,
    bool? isActive,
    String? avatarPath,
  }) async {}

  @override
  Future<String> uploadAvatar(Uint8List bytes, {required String extension}) {
    throw UnimplementedError();
  }

  @override
  Future<UserResponse> updateEmail(String email, {String? emailRedirectTo}) {
    throw UnimplementedError();
  }

  @override
  Future<void> setMyAccountActive(bool isActive) async {}

  @override
  Future<void> upsertMyProfile({String? fullName}) async {}
}
