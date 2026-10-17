import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/providers/layout_mode_provider.dart';

class AuthCallbackPage extends ConsumerWidget {
  const AuthCallbackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (prev, next) {
      next.whenData((state) {
        if (state.event == sb.AuthChangeEvent.signedIn ||
            state.event == sb.AuthChangeEvent.tokenRefreshed) {
          final mode = ref.read(effectiveLayoutModeProvider);
          // Redirigir a rutas que REALMENTE existen en el router:
          context.go(
            mode == AppLayoutMode.academy
                ? AppRoutes.academyDashboard
                : AppRoutes.studentProfile, // <-- Corregido: apunta a studentProfile
          );
        }
      });
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}