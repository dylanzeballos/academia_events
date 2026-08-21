import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../data/models/profile_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/auth_service.dart';

final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return const AuthRepository(authService: AuthService());
});

final authStateProvider = StreamProvider<sb.AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).maybeWhen(
        data: (state) =>
            state.event == sb.AuthChangeEvent.signedIn ||
            state.event == sb.AuthChangeEvent.tokenRefreshed,
        orElse: () => ref.read(authRepositoryProvider).isAuthenticated,
      );
});

class AppAuthState {
  const AppAuthState({
    this.isLoading = false,
    this.error,
    this.isPasswordRecovery = false,
  });

  final bool isLoading;
  final String? error;
  final bool isPasswordRecovery;

  AppAuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isPasswordRecovery,
    bool clearError = false,
  }) {
    return AppAuthState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      isPasswordRecovery: isPasswordRecovery ?? this.isPasswordRecovery,
    );
  }
}

class AuthController extends Notifier<AppAuthState> {
  @override
  AppAuthState build() => const AppAuthState();

  IAuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.signIn(email: email, password: password);
      state = state.copyWith(isLoading: false);
    } on sb.AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudo iniciar sesión. Intenta nuevamente.',
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.signInWithGoogle();
      state = state.copyWith(isLoading: false);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudo iniciar sesión con Google.',
      );
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.signUp(
          email: email, password: password, fullName: fullName);
      state = state.copyWith(isLoading: false);
    } on sb.AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudo crear la cuenta. Intenta nuevamente.',
      );
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AppAuthState();
  }

  Future<void> sendPasswordRecovery(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.sendPasswordRecovery(email);
      state = state.copyWith(isLoading: false);
    } on sb.AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'No se pudo enviar el correo.');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.updatePassword(newPassword);
      state = state.copyWith(isLoading: false, isPasswordRecovery: false);
    } on sb.AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudo actualizar la contraseña.',
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final authControllerProvider =
    NotifierProvider<AuthController, AppAuthState>(() {
  return AuthController();
});

final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(authRepositoryProvider);
  if (!repo.isAuthenticated) return null;
  return repo.fetchCurrentProfile();
});

/// URL mostrable del avatar actual: convierte paths del bucket (o URLs
/// firmadas antiguas guardadas en BD) en una URL pública permanente.
final resolvedAvatarUrlProvider = Provider<String?>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  final repo = ref.watch(authRepositoryProvider);
  return repo.resolveAvatarUrl(profile?.profileImageUrl);
});

final currentUserRoleProvider = FutureProvider<UserRole>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(authRepositoryProvider);
  if (!repo.isAuthenticated) return UserRole.student;
  return repo.fetchUserRole();
});
