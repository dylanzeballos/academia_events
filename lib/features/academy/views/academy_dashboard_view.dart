import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/organization_member_model.dart';
import '../../../data/repositories/organization_repository.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../organization/views/organization_detail_view.dart';

class AcademyDashboardView extends ConsumerStatefulWidget {
  const AcademyDashboardView({super.key});

  @override
  ConsumerState<AcademyDashboardView> createState() =>
      _AcademyDashboardViewState();
}

class _AcademyDashboardViewState extends ConsumerState<AcademyDashboardView> {
  @override
  Widget build(BuildContext context) {
    final selectedOrgId = ref.watch(selectedOrganizationIdProvider);
    final orgsAsync = ref.watch(myOrganizationsProvider);

    ref.listen(myOrganizationsProvider, (prev, next) {
      next.whenData((orgs) {
        if (orgs.isNotEmpty &&
            ref.read(selectedOrganizationIdProvider) == null) {
          ref
              .read(selectedOrganizationIdProvider.notifier)
              .select(orgs.first.organization.id);
        }
      });
    });

    if (selectedOrgId == null) {
      return orgsAsync.when(
        loading: () => const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        ),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
        data: (orgs) {
          if (orgs.isEmpty) {
            return const Scaffold(body: Center(child: _EmptyOrgsCta()));
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                ref.read(selectedOrganizationIdProvider) == null) {
              ref
                  .read(selectedOrganizationIdProvider.notifier)
                  .select(orgs.first.organization.id);
            }
          });
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          );
        },
      );
    }

    final statsAsync = ref.watch(orgStatsProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageMembers ?? false;
    final selectedOrgWithRole = orgsAsync.whenOrNull<List<OrganizationWithRole>>(
      data: (orgs) => orgs,
    )?.where((o) => o.organization.id == selectedOrgId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Panel')),
      body: orgsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orgs) {
          if (orgs.isEmpty) {
            return const _EmptyOrgsCta();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orgStatsProvider);
              ref.invalidate(orgClassesProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Org selector with logo, name, and role
                  _OrgSelector(
                    orgs: orgs,
                    selectedOrgId: selectedOrgId,
                    currentRole: selectedOrgWithRole?.role,
                    onSelected: (orgId) {
                      ref
                          .read(selectedOrganizationIdProvider.notifier)
                          .select(orgId);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Stats
                  statsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e',
                        style: const TextStyle(color: Colors.grey)),
                    data: (stats) => Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.school_outlined,
                                label: 'Clases',
                                value: '${stats['totalClasses'] ?? 0}',
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.calendar_today,
                                label: 'Proximas',
                                value: '${stats['upcomingSessions'] ?? 0}',
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.check_circle_outline,
                                label: 'Activas',
                                value: '${stats['activeClasses'] ?? 0}',
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.people_outline,
                                label: 'Miembros',
                                value: '${stats['totalMembers'] ?? 0}',
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick actions
                  if (canManage) ...[
                    Text(
                      'Acciones rapidas',
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
                                    builder: (_) =>
                                        const OrganizationDetailView()),
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
                            icon: Icons.fact_check_outlined,
                            label: 'Registrar\nasistencia',
                            onTap: () => context.push(AppRoutes.academyAttendance),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.event_note_outlined,
                            label: 'Gestionar\nclases',
                            onTap: () => context.go(AppRoutes.academyClasses),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Upcoming sessions
                  Text(
                    'Proximas sesiones',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _UpcomingSessionsList(),
                ],
              ),
            ),
          );
        },
      ),
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
          title: Text('Invitar miembro',
              style: TextStyle(color: context.textOnBg)),
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
              DropdownButtonFormField<String>(
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
                'Recibiran una invitacion en la plataforma.',
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
                    const SnackBar(content: Text('Ingresa un email valido')),
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
                      SnackBar(
                          content: Text('Invitacion enviada a $email')),
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
              child: const Text('Enviar invitacion',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrgSelector extends ConsumerWidget {
  const _OrgSelector({
    required this.orgs,
    required this.selectedOrgId,
    this.currentRole,
    required this.onSelected,
  });

  final List<OrganizationWithRole> orgs;
  final String? selectedOrgId;
  final MemberRole? currentRole;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedOrgWithRole = orgs.firstWhere(
      (o) => o.organization.id == selectedOrgId,
      orElse: () => orgs.first,
    );
    final org = selectedOrgWithRole.organization;
    final logoAsync = ref.watch(orgLogoUrlProvider(org.logoUrl));
    final logoUrl = logoAsync.whenOrNull(data: (url) => url);

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
            // Org logo or initial
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage:
                  logoUrl != null ? NetworkImage(logoUrl) : null,
              child: logoUrl == null
                  ? Text(
                      org.name.isNotEmpty ? org.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Name + role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (orgs.length > 1)
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isDense: true,
                        value: selectedOrgId,
                        dropdownColor: context.cardBg,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        items: orgs
                            .map<DropdownMenuItem<String>>(
                                (o) => DropdownMenuItem(
                                      value: o.organization.id,
                                      child: Text(o.organization.name),
                                    ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) onSelected(v);
                        },
                      ),
                    )
                  else
                    Text(
                      org.name,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                  // Role badge
                  if (currentRole != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currentRole!.displayName,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
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

class _UpcomingSessionsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgClassesAsync = ref.watch(orgClassesProvider);

    return orgClassesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e',
          style: const TextStyle(color: Colors.grey)),
      data: (classes) {
        if (classes.isEmpty) {
          return Card(
            color: context.cardBg,
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No hay clases creadas aun',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          );
        }

        return Card(
          color: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            side: BorderSide(color: context.divider),
          ),
          child: Column(
            children: classes
                .take(5)
                .map((c) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          c.title.isNotEmpty
                              ? c.title[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        c.title,
                        style: TextStyle(
                            color: context.textOnBg,
                            fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        c.isPublished ? 'Publicada' : 'Borrador',
                        style: TextStyle(
                          color: c.isPublished
                              ? AppColors.success
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.grey),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _EmptyOrgsCta extends StatelessWidget {
  const _EmptyOrgsCta();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined,
              size: 64, color: AppColors.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(
            'Aún no perteneces a ninguna organización',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea la tuya para administrar clases, eventos, '
            'profesores y entradas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),
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
