import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/organization_member_model.dart';
import '../../../data/repositories/organization_repository.dart';
import '../../../data/services/organization_service.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_button.dart';
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
      body: membersAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: AppBanner(message: 'Error: $e'),
        ),
        data: (members) {
          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sin miembros',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Agregar miembro',
                      icon: Icons.person_add,
                      onPressed: () => _showAddMemberDialog(context, ref),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(organizationMembersProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (canManage)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppButton(
                      label: 'Agregar miembro',
                      icon: Icons.person_add,
                      isOutlined: true,
                      onPressed: () => _showAddMemberDialog(context, ref),
                    ),
                  ),
                ...List.generate(members.length, (index) {
                  final m = members[index];
                  return _MemberTile(
                    member: m,
                    isAdmin: canManage,
                    isOwner: m.member.role.isOwner,
                    canChangeRoles: myRole?.canChangeRoles ?? false,
                    onRoleChanged: canManage && !m.member.role.isOwner
                        ? (newRole) async {
                            final repo =
                                ref.read(organizationRepositoryProvider);
                            await repo.updateMemberRole(
                              memberId: m.member.id,
                              newRole: newRole,
                            );
                            ref.invalidate(organizationMembersProvider);
                          }
                        : null,
                    onRemove: canManage && !m.member.role.isOwner
                        ? () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('Eliminar miembro',
                                    style: TextStyle(color: context.textOnBg)),
                                content: Text(
                                  '¿Eliminar a ${m.profileName}?',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Eliminar',
                                        style: TextStyle(
                                            color: AppColors.error)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final repo =
                                  ref.read(organizationRepositoryProvider);
                              await repo.removeMember(m.member.id);
                              ref.invalidate(organizationMembersProvider);
                            }
                          }
                        : null,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    final userIdCtrl = TextEditingController();
    String selectedRole = 'check_in_staff';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Agregar miembro',
              style: TextStyle(color: context.textOnBg)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresa el ID del usuario (UUID de auth.users)',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: userIdCtrl,
                style: TextStyle(color: context.textOnBg),
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                dropdownColor: context.cardBg,
                style: TextStyle(color: context.textOnBg),
                decoration: const InputDecoration(
                  labelText: 'Rol',
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final userId = userIdCtrl.text.trim();
                if (userId.isEmpty) return;

                final orgId =
                    ref.read(selectedOrganizationIdProvider);
                if (orgId == null) return;

                final repo = ref.read(organizationRepositoryProvider);
                try {
                  await repo.addMember(
                    orgId: orgId,
                    userId: userId,
                    role: selectedRole,
                  );
                  ref.invalidate(organizationMembersProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } on OrganizationException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Error al agregar miembro. Intenta de nuevo.')),
                    );
                  }
                }
              },
              child: const Text('Agregar',
                  style: TextStyle(color: AppColors.primary)),
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

  @override
  Widget build(BuildContext context) {
    final initials = member.profileName.length >= 2
        ? '${member.profileName[0]}${member.profileName[member.profileName.length - 1]}'
        : member.profileName;

    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                initials.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
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
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isOwner
                              ? Colors.amber.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          member.member.role.displayName,
                          style: TextStyle(
                            color: isOwner ? Colors.amber : AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isAdmin && !isOwner)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                onSelected: onRoleChanged,
                itemBuilder: (_) => [
                  for (final role in MemberRole.values)
                    if (!role.isOwner)
                      PopupMenuItem(
                        value: role.value,
                        child: Text(role.displayName),
                      ),
                ],
              ),
            if (isAdmin && !isOwner)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppColors.error, size: 20),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
