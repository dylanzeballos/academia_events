// lib/features/academy/views/dashboard/dashboard_quick_actions.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/organization_member_model.dart';
import '../../../../providers/dance_class_provider.dart';
import '../../../../providers/organization_provider.dart';
import '../../../../shared/widgets/app_feedback.dart';

class DashboardQuickActions extends ConsumerWidget {
  const DashboardQuickActions({super.key, required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ChipAction(
            icon: Icons.add_circle_outline_rounded,
            label: '+ Clase',
            color: AppColors.primary,
            onTap: () async {
              // Navega en pantalla completa tapando la barra inferior
              await context.push(AppRoutes.classCreate);
              ref.invalidate(orgClassesProvider);
              ref.invalidate(orgWeeklyScheduleEntriesProvider);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ChipAction(
            icon: Icons.celebration_outlined,
            label: '+ Evento',
            color: AppColors.secondary,
            onTap: () => context.push(AppRoutes.eventCreate),
          ),
        ),
        if (canManage) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _ChipAction(
              icon: Icons.group_add_outlined,
              label: 'invitar',
              color: AppColors.warning,
              onTap: () => _showInviteDialog(context, ref),
            ),
          ),
        ],
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
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'correo@ejemplo.com',
                  labelStyle: TextStyle(color: context.textMuted),
                  prefixIcon: Icon(Icons.email_outlined, color: context.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                dropdownColor: context.cardBg,
                style: TextStyle(color: context.textOnBg),
                decoration: InputDecoration(
                  labelText: 'Rol asignado',
                  labelStyle: TextStyle(color: context.textMuted),
                  prefixIcon: Icon(Icons.work_outline, color: context.textMuted),
                ),
                items: MemberRole.values
                    .where((r) => !r.isOwner)
                    .map((r) => DropdownMenuItem(
                          value: r.value,
                          child: Text(r.displayName, style: TextStyle(color: context.textOnBg)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedRole = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
            ),
            FilledButton(
              onPressed: sending
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        AppFeedback.warning(ctx, 'Ingresa un correo válido.');
                        return;
                      }

                      final orgId = ref.read(selectedOrganizationIdProvider);
                      if (orgId == null) return;

                      setDialogState(() => sending = true);
                      try {
                        await ref
                            .read(organizationRepositoryProvider)
                            .sendInvitation(
                              orgId: orgId,
                              email: email,
                              role: selectedRole,
                            );
                        ref.invalidate(orgInvitationsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          AppFeedback.success(
                            context,
                            'Invitación enviada a $email.',
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          AppFeedback.error(ctx, friendlyError(e));
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => sending = false);
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipAction extends StatelessWidget {
  const _ChipAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: context.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}