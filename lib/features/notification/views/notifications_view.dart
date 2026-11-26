import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

import '../../../providers/notification_provider.dart';
import '../../../data/models/notification_model.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_feedback.dart';

bool _isInvitationNotification(NotificationModel notification) {
  final data = notification.data;
  return notification.type == 'organization_invitation' ||
      data?['route'] == 'my_invitations' ||
      data?['invitation_id'] != null;
}

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  bool _onlyUnread = false;
  final Set<String> _hidden = <String>{};

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(effectiveNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final currentUser = Supabase.instance.client.auth.currentUser;
    final actions = ref.read(notificationActionsProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Centro de Avisos',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: context.cardBg,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Marcar todo como leído',
            icon: const Icon(
              Icons.done_all_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            onPressed: unreadCount == 0 || currentUser == null
                ? null
                : () => actions.markAllAsRead(currentUser.id),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones de avisos',
            icon: Icon(Icons.more_vert_rounded, color: context.textMuted),
            onSelected: (value) {
              if (value == 'clear') {
                final current =
                    ref.read(effectiveNotificationsProvider).asData?.value ??
                    const <NotificationModel>[];
                _confirmClearAll(context, actions, currentUser?.id, current);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    color: AppColors.error,
                  ),
                  title: Text('Limpiar todos los avisos'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error al cargar avisos: $err',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted),
            ),
          ),
        ),
        data: (allNotifications) {
          final notifications = allNotifications
              .where((n) => !_hidden.contains(n.id))
              .toList();
          final unread = notifications.where((n) => !n.isRead).length;
          final visible = _onlyUnread
              ? notifications.where((n) => !n.isRead).toList()
              : notifications;

          return Column(
            children: [
              if (notifications.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text('Todas (${notifications.length})'),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('No leídas ($unread)'),
                        ),
                      ],
                      selected: {_onlyUnread},
                      onSelectionChanged: (value) {
                        setState(() => _onlyUnread = value.first);
                      },
                    ),
                  ),
                ),
              Expanded(
                child: visible.isEmpty
                    ? _EmptyState(
                        onlyUnread: _onlyUnread,
                        hasAny: notifications.isNotEmpty,
                        onShowAll: () => setState(() => _onlyUnread = false),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: const _DeleteBackground(),
                            confirmDismiss: (_) => showAppConfirm(
                              context,
                              title: 'Eliminar aviso',
                              message:
                                  '¿Eliminar este aviso? No se puede deshacer.',
                              confirmLabel: 'Eliminar',
                              isDangerous: true,
                            ),
                            onDismissed: (_) {
                              setState(() => _hidden.add(item.id));
                              actions.deleteNotification(item.id);
                            },
                            child: _NotificationCard(
                              notification: item,
                              onTap: () async {
                                if (!item.isRead) {
                                  await actions.markAsRead(item.id);
                                }
                                if (!context.mounted) return;
                                if (_isInvitationNotification(item)) {
                                  context.push(AppRoutes.myInvitations);
                                }
                              },
                              onToggleRead: () {
                                if (item.isRead) {
                                  actions.markAsUnread(item.id);
                                } else {
                                  actions.markAsRead(item.id);
                                }
                              },
                              onDelete: () async {
                                final confirmed = await showAppConfirm(
                                  context,
                                  title: 'Eliminar aviso',
                                  message: '¿Eliminar este aviso? No se puede deshacer.',
                                  confirmLabel: 'Eliminar',
                                  isDangerous: true,
                                );
                                if (confirmed) {
                                  setState(() => _hidden.add(item.id));
                                  actions.deleteNotification(item.id);
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    NotificationActions actions,
    String? userId,
    List<NotificationModel> notifications,
  ) async {
    if (userId == null) return;
    final confirmed = await showAppConfirm(
      context,
      title: 'Limpiar todos los avisos',
      message:
          'Se eliminarán todos los avisos de hoy. Esta acción no se puede '
          'deshacer.',
      confirmLabel: 'Eliminar',
      isDangerous: true,
    );
    if (!confirmed) return;

    setState(() => _hidden.addAll(notifications.map((n) => n.id)));
    await actions.deleteAll(userId);
    if (!context.mounted) return;
    AppFeedback.info(context, 'Avisos eliminados.');
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: AppColors.error,
        size: 24,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onlyUnread,
    required this.hasAny,
    required this.onShowAll,
  });

  final bool onlyUnread;
  final bool hasAny;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final title = onlyUnread && hasAny
        ? 'No tenés avisos sin leer'
        : 'Estás al día';
    final message = onlyUnread && hasAny
        ? 'Probá con el filtro Todas para ver tus avisos de hoy.'
        : 'No tenés avisos por ahora. Los avisos se reinician cada día.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.cardBg,
                border: Border.all(color: context.divider, width: 1),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 52,
                color: context.textMuted.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (onlyUnread && hasAny) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onShowAll,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: const Text('Ver todas'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onToggleRead,
    required this.onDelete,
  });

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime.toLocal());

    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return DateFormat('HH:mm').format(dateTime.toLocal());
  }

  IconData _iconForType(String type) {
    if (type.startsWith('organization_invitation')) {
      return Icons.mark_email_unread_rounded;
    }
    if (type.startsWith('subscription_')) return Icons.card_membership_rounded;
    if (type.startsWith('event_')) return Icons.confirmation_number_rounded;
    if (type.startsWith('class_')) return Icons.school_rounded;
    return Icons.notifications_active_rounded;
  }

  Color _accentColor(String type) {
    if (type.startsWith('organization_invitation')) return AppColors.secondary;
    if (type.startsWith('subscription_')) return AppColors.warning;
    if (type.startsWith('event_')) return AppColors.primary;
    if (type.startsWith('class_')) return AppColors.secondary;
    return AppColors.primary;
  }

  String _categoryLabel(String type) {
    if (type.startsWith('organization_invitation')) return 'Invitación';
    if (type.startsWith('subscription_')) return 'Membresía';
    if (type.startsWith('event_')) return 'Evento';
    if (type.startsWith('class_')) return 'Clase';
    return 'Sistema';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(notification.type);
    final icon = _iconForType(notification.type);
    final isUnread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isUnread
            ? (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : Colors.white)
            : context.cardBg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUnread
                    ? accent.withValues(alpha: 0.45)
                    : context.divider,
                width: isUnread ? 1.4 : 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _categoryLabel(notification.type),
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTime(notification.createdAt),
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                          PopupMenuButton<String>(
                            tooltip: 'Opciones del aviso',
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: context.textMuted,
                            ),
                            onSelected: (value) {
                              if (value == 'toggle') {
                                onToggleRead();
                              } else if (value == 'delete') {
                                onDelete();
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    isUnread
                                        ? Icons.drafts_outlined
                                        : Icons.mark_email_unread_outlined,
                                  ),
                                  title: Text(
                                    isUnread
                                        ? 'Marcar como leída'
                                        : 'Marcar como no leída',
                                  ),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.error,
                                  ),
                                  title: Text('Eliminar aviso'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.title,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 14,
                          fontWeight: isUnread
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: isUnread
                              ? context.textOnBg.withValues(alpha: 0.8)
                              : context.textMuted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
