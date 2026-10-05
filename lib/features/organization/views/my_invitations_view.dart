import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/display_labels.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/organization_invitation_model.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';

class MyInvitationsView extends ConsumerWidget {
  const MyInvitationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(myInvitationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Invitaciones'),
      ),
      body: invitationsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => AppErrorState(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(myInvitationsProvider),
        ),
        data: (invitations) {
          if (invitations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  const Text(
                    'Sin invitaciones pendientes',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myInvitationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: invitations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _InvitationCard(invitation: invitations[index]),
            ),
          );
        },
      ),
    );
  }
}

class _InvitationCard extends ConsumerWidget {
  const _InvitationCard({required this.invitation});

  final OrganizationInvitationModel invitation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleDisplay = _roleDisplayName(invitation.role);

    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.business_outlined,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.organizationName ?? 'Organizacion',
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (invitation.inviterName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Invitado por ${invitation.inviterName}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Rol: $roleDisplay',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Aceptar',
                    onPressed: () => _accept(context, ref),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Rechazar',
                    isOutlined: true,
                    color: AppColors.error,
                    onPressed: () => _decline(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final ok = await showAppConfirm(
      context,
      title: 'Aceptar invitación',
      message:
          '¿Unirte a ${invitation.organizationName ?? 'la organización'}?',
      confirmLabel: 'Aceptar',
      icon: Icons.group_add_outlined,
    );
    if (!ok) return;
    final repo = ref.read(organizationRepositoryProvider);
    try {
      final result = await repo.acceptInvitation(invitation.id);
      if (result['error'] != null) {
        if (context.mounted) {
          AppFeedback.error(context, friendlyError(result['error']));
        }
        return;
      }
      ref.invalidate(myInvitationsProvider);
      ref.invalidate(myOrganizationsProvider);
      if (context.mounted) {
        AppFeedback.success(context, 'Te uniste a la organización.');
      }
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, friendlyError(e));
    }
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    final ok = await showAppConfirm(
      context,
      title: 'Rechazar invitación',
      message:
          '¿Rechazar la invitación de ${invitation.organizationName ?? 'esta organización'}?',
      confirmLabel: 'Rechazar',
      isDangerous: true,
    );
    if (!ok) return;
    try {
      await ref
          .read(organizationRepositoryProvider)
          .declineInvitation(invitation.id);
      ref.invalidate(myInvitationsProvider);
      if (context.mounted) {
        AppFeedback.info(context, 'Invitación rechazada.');
      }
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, friendlyError(e));
    }
  }

  String _roleDisplayName(String role) => DisplayLabels.role(role);
}
