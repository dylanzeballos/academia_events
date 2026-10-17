import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../data/models/organization_member_model.dart';
import '../../../../providers/dance_class_provider.dart';
import '../../../../providers/organization_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../organization/classes/views/class_create_view.dart';

class DashboardQuickActions extends ConsumerWidget {
  const DashboardQuickActions({super.key, required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canManage) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Creación rápida',
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.add_circle_outline,
                label: 'Nueva\nclase',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClassCreateView()),
                  );
                  ref.invalidate(orgClassesProvider);
                  ref.invalidate(orgWeeklyScheduleEntriesProvider);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.celebration_outlined,
                label: 'Nuevo\nevento',
                onTap: () => context.push(AppRoutes.eventCreate),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Invitar\nstaff',
                onTap: () => _showInviteDialog(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    String selectedRole = 'check_in_staff';
    bool sending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.cardBg,
          title: Text(
            'Invitar miembro al equipo',
            style: TextStyle(color: context.textOnBg),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: context.textOnBg),
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'correo@ejemplo.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                dropdownColor: context.cardBg,
                style: TextStyle(color: context.textOnBg),
                decoration: const InputDecoration(
                  labelText: 'Rol asignado',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                items: MemberRole.values
                    .where((r) => !r.isOwner)
                    .map(
                      (r) => DropdownMenuItem(
                        value: r.value,
                        child: Text(r.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedRole = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(color: context.textMuted),
              ),
            ),
            AppButton(
              label: 'Enviar invitación',
              isLoading: sending,
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty) return;

                setDialogState(() => sending = true);
                try {
                  final orgId = ref.read(selectedOrganizationIdProvider);
                  if (orgId == null) return;

                  // Método real del repositorio de organizaciones
                  await ref
                      .read(organizationRepositoryProvider)
                      .sendInvitation(
                        orgId: orgId,
                        email: email,
                        role: selectedRole,
                      );

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    AppFeedback.success(context, 'Invitación enviada');
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => sending = false);
                    AppFeedback.error(context, friendlyError(e));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
