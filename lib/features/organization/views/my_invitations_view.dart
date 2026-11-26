// lib/features/organization/views/my_invitations_view.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/display_labels.dart';
import '../../../core/utils/public_urls.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/organization_invitation_model.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';

class MyInvitationsView extends ConsumerWidget {
  const MyInvitationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(myInvitationsProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          'Mis invitaciones',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar invitaciones',
            icon: Icon(Icons.refresh_rounded, color: context.textMuted),
            onPressed: () => ref.invalidate(myInvitationsProvider),
          ),
        ],
      ),
      body: invitationsAsync.when(
        loading: () => const _InvitationsSkeleton(),
        error: (e, _) => AppErrorState(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(myInvitationsProvider),
        ),
        data: (invitations) {
          if (invitations.isEmpty) {
            return _EmptyState(
              onRefresh: () async => ref.invalidate(myInvitationsProvider),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(myInvitationsProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: invitations.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ListHeader(count: invitations.length);
                }
                final invitation = invitations[index - 1];
                return _InvitationCard(invitation: invitation);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invitaciones pendientes',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == 1
                ? 'Una academia espera tu respuesta.'
                : '$count academias esperan tu respuesta.',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationCard extends ConsumerStatefulWidget {
  const _InvitationCard({required this.invitation});

  final OrganizationInvitationModel invitation;

  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

enum _InvitationAction { accept, decline }

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  _InvitationAction? _busy;
  String? _error;

  String get _organizationName =>
      widget.invitation.organizationName ?? 'Organización';

  String get _initial {
    final name = _organizationName.trim();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  Future<void> _accept() async {
    final ok = await showAppConfirm(
      context,
      title: 'Aceptar invitación',
      message: '¿Unirte a $_organizationName?',
      confirmLabel: 'Aceptar',
      icon: Icons.group_add_outlined,
    );
    if (!ok || !mounted) return;

    setState(() {
      _busy = _InvitationAction.accept;
      _error = null;
    });

    try {
      final result = await ref
          .read(organizationRepositoryProvider)
          .acceptInvitation(widget.invitation.id);
      if (!mounted) return;

      final error = result['error'];
      if (error != null) {
        setState(() {
          _busy = null;
          _error = friendlyError(error);
        });
        return;
      }

      ref.invalidate(myInvitationsProvider);
      ref.invalidate(myOrganizationsProvider);
      AppFeedback.success(context, 'Te uniste a $_organizationName.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _decline() async {
    final ok = await showAppConfirm(
      context,
      title: 'Rechazar invitación',
      message: '¿Rechazar la invitación de $_organizationName?',
      confirmLabel: 'Rechazar',
      isDangerous: true,
    );
    if (!ok || !mounted) return;

    setState(() {
      _busy = _InvitationAction.decline;
      _error = null;
    });

    try {
      await ref
          .read(organizationRepositoryProvider)
          .declineInvitation(widget.invitation.id);
      if (!mounted) return;

      ref.invalidate(myInvitationsProvider);
      AppFeedback.info(context, 'Invitación rechazada.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitation = widget.invitation;
    final busy = _busy != null;
    final role = DisplayLabels.role(invitation.role);

    return Semantics(
      container: true,
      label: 'Invitación de $_organizationName como $role',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrganizationAvatar(
                  initial: _initial,
                  logoUrl: invitation.organizationLogoUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _organizationName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (invitation.inviterName != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 14,
                              color: context.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Invitado por ${invitation.inviterName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.badge_outlined,
                  label: role,
                  color: AppColors.primary,
                ),
                if (invitation.expiresAt != null)
                  _MetaChip(
                    icon: Icons.schedule_rounded,
                    label: _expiryLabel(invitation.expiresAt!),
                    color: _expiryColor(invitation.expiresAt!),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _decline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: busy
                            ? context.divider
                            : AppColors.error.withValues(alpha: 0.7),
                      ),
                      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMedium,
                        ),
                      ),
                    ),
                    icon: _busy == _InvitationAction.decline
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.error,
                            ),
                          )
                        : const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : _accept,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMedium,
                        ),
                      ),
                    ),
                    icon: _busy == _InvitationAction.accept
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _expiryLabel(DateTime expiresAt) {
    final now = DateTime.now();
    final days = expiresAt.difference(now).inDays;

    if (expiresAt.isBefore(now)) return 'Venció';
    if (days == 0) return 'Vence hoy';
    if (days == 1) return 'Vence mañana';
    if (days < 7) return 'Vence en $days días';

    return 'Vence el ${DateFormat('d MMM', 'es').format(expiresAt)}';
  }

  Color _expiryColor(DateTime expiresAt) {
    final days = expiresAt.difference(DateTime.now()).inDays;
    if (expiresAt.isBefore(DateTime.now()) || days <= 2) {
      return AppColors.warning;
    }
    return context.textMuted;
  }
}

class _OrganizationAvatar extends StatelessWidget {
  const _OrganizationAvatar({required this.initial, this.logoUrl});

  final String initial;
  final String? logoUrl;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final url = organizationLogoUrl(logoUrl);
    if (url == null) return _fallback(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        placeholder: (_, _) => _fallback(context),
        errorWidget: (_, _, _) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(32),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 64
                      ? constraints.maxHeight - 64
                      : 0,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          size: 34,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No tenés invitaciones pendientes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          'Cuando una academia te invite, la vas a ver acá '
                          'para aceptar o rechazar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.tonalIcon(
                        onPressed: onRefresh,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, AppSizes.buttonHeight),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Actualizar'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InvitationsSkeleton extends StatelessWidget {
  const _InvitationsSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = context.divider.withValues(alpha: 0.45);

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonLine(width: 140, color: block),
                        const SizedBox(height: 8),
                        _SkeletonLine(width: 100, color: block),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SkeletonLine(width: 170, height: 24, color: block),
              const SizedBox(height: 20),
              _SkeletonLine(width: double.infinity, height: 48, color: block),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.width,
    required this.color,
    this.height = 12,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
