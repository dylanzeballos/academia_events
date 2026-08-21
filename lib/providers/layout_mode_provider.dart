import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../data/models/profile_model.dart';
import 'auth_provider.dart';

/// Modo visual de la app:
/// - [student]: navbar de 4 pestañas (usuario normal).
/// - [academy]: navbar de 5 pestañas (panel de organización).
enum AppLayoutMode { student, academy }

/// Modo elegido manualmente por el usuario en el perfil.
/// `null` = automático (academy si pertenece a una organización,
/// student en caso contrario). Se reinicia al cerrar sesión.
class LayoutModeNotifier extends Notifier<AppLayoutMode?> {
  @override
  AppLayoutMode? build() {
    ref.listen(authStateProvider, (_, next) {
      if (next.value?.event == sb.AuthChangeEvent.signedOut) {
        state = null;
      }
    });
    return null;
  }

  void set(AppLayoutMode mode) => state = mode;
}

final layoutModeProvider =
    NotifierProvider<LayoutModeNotifier, AppLayoutMode?>(
  LayoutModeNotifier.new,
);

/// Modo efectivo del layout: el manual tiene prioridad; si no hay
/// selección manual se deduce de la membresía en organizaciones.
final effectiveLayoutModeProvider = Provider<AppLayoutMode>((ref) {
  final manual = ref.watch(layoutModeProvider);
  if (manual != null) return manual;

  final role = ref.watch(currentUserRoleProvider).whenOrNull(
            data: (r) => r,
          ) ??
      UserRole.student;
  return role == UserRole.academy ? AppLayoutMode.academy : AppLayoutMode.student;
});
