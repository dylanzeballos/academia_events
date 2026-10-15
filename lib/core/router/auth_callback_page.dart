import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/layout_mode_provider.dart';

class AuthCallbackPage extends ConsumerWidget {
  const AuthCallbackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (prev, next) {
      next.whenData((state) {
        if (state.event == sb.AuthChangeEvent.signedIn ||
            state.event == sb.AuthChangeEvent.tokenRefreshed) {
          final mode = ref.read(effectiveLayoutModeProvider);
          context.go(
            mode == AppLayoutMode.academy
                ? AppRoutes.academyDashboard
                : AppRoutes.studentHome,
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