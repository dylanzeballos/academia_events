import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/organization_member_model.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../providers/organization_provider.dart';
import '../../../organization/views/organization_detail_view.dart';

class DashboardQuickActions extends ConsumerWidget {
  const DashboardQuickActions({super.key, required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuickActionCard(
          icon: Icons.qr_code_scanner,
          label: 'Check-in de entradas (QR)',
          onTap: () => context.push(AppRoutes.academyCheckin),
        ),
        if (canManage) ...[
          const SizedBox(height: 24),
          Text(
            'Acciones rápidas',
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
                  icon: Icons.person_add_outlined,
                  label: 'Invitar\nmiembro',
                  onTap: () => _showInviteDialog(context, ref),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.list_alt_outlined,
                  label: 'Ver\nmiembros',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrganizationDetailView(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.add_box_outlined,
                  label: 'Crear\nevento',
                  onTap: () => context.push(AppRoutes.eventCreate),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.calendar_month_outlined,
                  label: 'Gestionar\nhorario',
                  onTap: () => context.go(AppRoutes.academyClasses),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    String selectedRole = 'check_in_staff';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.cardBg,
          title: Text(
            'Invitar miembro',
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
                  labelText: 'Email del invitado',
                  hintText: 'correo@ejemplo.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField(
                initialValue: selectedRole,
                dropdownColor: context.cardBg,
                style: TextStyle(color: context.textOnBg),
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                items: MemberRole.values
                    .where((r) => !r.isOwner)
                    .map((r) => DropdownMenuItem(
                          value: r.value,
                          child: Text(r.displayName),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedRole = v);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Recibirán una invitación en la plataforma.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Ingresa un email válido')),
                  );
                  return;
                }

                final orgId = ref.read(selectedOrganizationIdProvider);
                if (orgId == null) return;

                final repo = ref.read(organizationRepositoryProvider);
                try {
                  await repo.sendInvitation(
                    orgId: orgId,
                    email: email,
                    role: selectedRole,
                  );
                  ref.invalidate(orgInvitationsProvider);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invitación enviada a $email')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text(
                'Enviar invitación',
                style: TextStyle(color: AppColors.primary),
              ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}