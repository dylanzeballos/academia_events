// lib/feature/public/profile/widgets/profile_settings_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/theme/theme_transition.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/providers/layout_mode_provider.dart';
import 'package:academia_events/providers/organization_provider.dart';
import 'package:academia_events/providers/theme_provider.dart';
import 'package:academia_events/shared/widgets/app_button.dart';
import 'package:academia_events/feature/public/profile/views/my_invitations_view.dart';

class ProfileSettingsSection extends ConsumerWidget {
  const ProfileSettingsSection({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Cerrar sesión', style: TextStyle(color: context.textOnBg)),
        content: Text(
          '¿Estás seguro de que quieres salir?',
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  void _onModeChanged(BuildContext context, WidgetRef ref, AppLayoutMode mode) {
    if (mode == ref.read(effectiveLayoutModeProvider)) return;
    ref.read(layoutModeProvider.notifier).set(mode);
    context.go(
      mode == AppLayoutMode.academy
          ? AppRoutes.academyDashboard
          : AppRoutes.studentHome,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final mode = ref.watch(effectiveLayoutModeProvider);

    // Compatibilidad Riverpod: asData?.value
    final orgsAsync = ref.watch(myOrganizationsProvider);
    final invitationsAsync = ref.watch(myInvitationsProvider);

    final pendingCount = invitationsAsync.asData?.value.length ?? 0;
    final orgs = orgsAsync.asData?.value;
    final hasOrgs = orgs != null && orgs.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: context.divider),
        const SizedBox(height: 16),

        // Toggle Modo Oscuro con animación
        Builder(
          builder: (tileContext) => SwitchListTile(
            title: Text(
              'Modo oscuro',
              style: TextStyle(color: context.textOnBg, fontSize: 15),
            ),
            subtitle: Text(
              isDark ? 'Activado' : 'Desactivado',
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: AppColors.primary,
            ),
            value: isDark,
            onChanged: (_) {
              final box = tileContext.findRenderObject() as RenderBox?;
              final origin = box != null
                  ? box.localToGlobal(
                      Offset(box.size.width - 32, box.size.height / 2),
                    )
                  : MediaQuery.sizeOf(context).center(Offset.zero);
              animateThemeToggle(context, ref, origin: origin);
            },
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 16),

        // Conmutador de modo / Creación de organizaciones
        if (!hasOrgs) ...[
          Text(
            'Organización',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _CreateOrgCard(),
        ] else ...[
          Text(
            'Modo de la app',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cambia entre la vista de estudiante y el panel de tu organización.',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppLayoutMode>(
            segments: const [
              ButtonSegment(
                value: AppLayoutMode.student,
                icon: Icon(Icons.person_outline),
                label: Text('Usuario'),
              ),
              ButtonSegment(
                value: AppLayoutMode.academy,
                icon: Icon(Icons.storefront_outlined),
                label: Text('Organización'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) =>
                _onModeChanged(context, ref, selection.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: WidgetStateProperty.resolveWith((states) {
                final isSelected = states.contains(WidgetState.selected);
                return BorderSide(
                  color: isSelected ? AppColors.primary : context.divider,
                  width: isSelected ? 1.4 : 1,
                );
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : context.textMuted;
              }),
            ),
          ),
        ],

        const SizedBox(height: 12),
        AppButton(
          label: pendingCount > 0
              ? 'Invitaciones ($pendingCount pendientes)'
              : 'Mis Invitaciones',
          isOutlined: true,
          icon: Icons.mail_outline,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyInvitationsView()),
          ),
        ),
        const SizedBox(height: 16),

        AppButton(
          label: 'Cerrar sesión',
          isOutlined: true,
          color: AppColors.error,
          onPressed: () => _signOut(context, ref),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _CreateOrgCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Tienes una academia u organizas eventos?',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Crea tu organización y conviértete en su propietario para administrar clases, eventos, profesores y entradas.',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Crear mi organización',
            icon: Icons.add_business_outlined,
            onPressed: () => context.push(AppRoutes.organizationsCreate),
          ),
        ],
      ),
    );
  }
}