// lib/features/organization/views/organization_members_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/organization_member_model.dart';
import '../../../data/repositories/organization_repository.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/loading_indicator.dart';

class OrganizationMembersView extends ConsumerWidget {
  const OrganizationMembersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(organizationMembersProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageMembers ?? false;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: membersAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppBanner(message: friendlyError(e)),
          ),
        ),
        data: (members) {
          if (members.isEmpty) {
            return AppEmptyState(
              icon: Icons.people_outline,
              title: 'Sin miembros',
              message: 'Invita a tu equipo para empezar a colaborar.',
              actionLabel: canManage ? 'Invitar miembro' : null,
              onAction: canManage
                  ? () => _showInviteDialog(context, ref)
                  : null,
            );
          }

          final groups = <MemberRole, List<OrganizationMemberWithProfile>>{};
          for (final member in members) {
            groups.putIfAbsent(member.member.role, () => []).add(member);
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(organizationMembersProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        members.length == 1
                            ? '1 miembro en el equipo'
                            : '${members.length} miembros en el equipo',
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (canManage)
                      TextButton.icon(
                        onPressed: () => _showInviteDialog(context, ref),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Invitar'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final role in MemberRole.values)
                  if (groups.containsKey(role)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Text(
                        '${role.displayName} · ${groups[role]!.length}',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    for (final m in groups[role]!)
                      _MemberTile(
                        member: m,
                        isAdmin: canManage,
                        isOwner: m.member.role.isOwner,
                        canChangeRoles: myRole?.canChangeRoles ?? false,
                        onRoleChanged: canManage && !m.member.role.isOwner
                            ? (newRole) async {
                                final repo = ref.read(
                                  organizationRepositoryProvider,
                                );
                                await repo.updateMemberRole(
                                  memberId: m.member.id,
                                  newRole: newRole,
                                );
                                ref.invalidate(organizationMembersProvider);
                              }
                            : null,
                        onRemove: canManage && !m.member.role.isOwner
                            ? () => _confirmRemove(context, ref, m)
                            : null,
                      ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    OrganizationMemberWithProfile member,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(
          'Eliminar miembro',
          style: TextStyle(color: context.textOnBg),
        ),
        content: Text(
          '¿Eliminar a ${member.profileName} del equipo? Perderá el acceso a la '
          'organización.',
          style: TextStyle(color: context.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(organizationRepositoryProvider)
          .removeMember(member.member.id);
      ref.invalidate(organizationMembersProvider);
      if (context.mounted) {
        AppFeedback.success(context, '${member.profileName} salió del equipo.');
      }
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, friendlyError(e));
    }
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
            style: TextStyle(
              color: context.textOnBg,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: context.textOnBg),
                decoration: InputDecoration(
                  labelText: 'Email del invitado',
                  labelStyle: TextStyle(color: context.textMuted),
                  hintText: 'correo@ejemplo.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                dropdownColor: context.cardBg,
                style: TextStyle(color: context.textOnBg),
                decoration: InputDecoration(
                  labelText: 'Rol',
                  labelStyle: TextStyle(color: context.textMuted),
                  prefixIcon: const Icon(Icons.work_outline),
                ),
                items: MemberRole.values
                    .where((r) => !r.isOwner)
                    .map(
                      (r) => DropdownMenuItem(
                        value: r.value,
                        child: Text(
                          r.displayName,
                          style: TextStyle(color: context.textOnBg),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedRole = v);
                },
              ),
              const SizedBox(height: 8),
              Text(
                'El usuario recibirá la invitación en la plataforma y podrá aceptar o rechazar.',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(color: context.textMuted),
              ),
            ),
            TextButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  AppFeedback.warning(ctx, 'Ingresa un correo válido.');
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
                }
              },
              child: const Text(
                'Enviar invitación',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isAdmin,
    required this.isOwner,
    required this.canChangeRoles,
    this.onRoleChanged,
    this.onRemove,
  });

  final OrganizationMemberWithProfile member;
  final bool isAdmin;
  final bool isOwner;
  final bool canChangeRoles;
  final ValueChanged<String>? onRoleChanged;
  final VoidCallback? onRemove;

  static const String _removeValue = '__remove';

  Color get _roleColor {
    if (isOwner) return AppColors.warning;
    return switch (member.member.role) {
      MemberRole.manager => AppColors.primary,
      MemberRole.instructor => AppColors.success,
      _ => AppColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final initials = member.profileName.length >= 2
        ? '${member.profileName[0]}${member.profileName[member.profileName.length - 1]}'
        : member.profileName;
    final color = _roleColor;
    final canEdit = isAdmin && !isOwner;

    return Card(
      color: context.cardBg,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                initials.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.profileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      member.member.role.displayName,
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (canEdit)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: context.textMuted, size: 20),
                color: context.cardBg,
                tooltip: 'Opciones de ${member.profileName}',
                onSelected: (value) {
                  if (value == _removeValue) {
                    onRemove?.call();
                    return;
                  }
                  onRoleChanged?.call(value);
                },
                itemBuilder: (menuContext) => [
                  if (canChangeRoles && onRoleChanged != null) ...[
                    const PopupMenuItem<String>(
                      enabled: false,
                      height: 30,
                      child: Text(
                        'Cambiar rol',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final role in MemberRole.values)
                      if (!role.isOwner)
                        PopupMenuItem(
                          value: role.value,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                child: member.member.role == role
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      )
                                    : null,
                              ),
                              Text(
                                role.displayName,
                                style: TextStyle(color: context.textOnBg),
                              ),
                            ],
                          ),
                        ),
                    if (onRemove != null) const PopupMenuDivider(),
                  ],
                  if (onRemove != null)
                    PopupMenuItem(
                      value: _removeValue,
                      child: const Row(
                        children: [
                          Icon(
                            Icons.person_remove_outlined,
                            size: 18,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Eliminar del equipo',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
