import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/shared/widgets/app_error_state.dart';
import 'package:academia_events/shared/widgets/app_feedback.dart';

import '../widgets/profile_avatar_header.dart';
import '../widgets/profile_form_section.dart';
import '../widgets/profile_settings_section.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(
            child: AppErrorState(message: friendlyError(e)),
          ),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Text(
                  'No se pudo cargar el perfil',
                  style: TextStyle(color: context.textMuted),
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: ProfileAvatarHeader(profile: profile),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ProfileFormSection(profile: profile),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: ProfileSettingsSection(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}