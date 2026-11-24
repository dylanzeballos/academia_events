import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

import '../../../providers/notification_provider.dart';
import '../../../data/models/notification_model.dart';

class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final repo = ref.read(notificationRepositoryProvider);
    final currentUser = Supabase.instance.client.auth.currentUser;

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
          TextButton.icon(
            onPressed: () async {
              if (currentUser != null) {
                await repo.markAllAsRead(currentUser.id);
              }
            },
            icon: const Icon(
              Icons.done_all_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            label: const Text(
              'Leído todo',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    'Estás al día',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No tienes nuevas notificaciones por ahora.',
                    style: TextStyle(color: context.textMuted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final item = notifications[index];
              return _NotificationCard(
                notification: item,
                onTap: () async {
                  if (!item.isRead) {
                    await repo.markAsRead(item.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime.toLocal());

    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return DateFormat('dd/MM/yyyy - HH:mm').format(dateTime.toLocal());
  }

  IconData _iconForType(String type) {
    if (type.startsWith('subscription_')) return Icons.card_membership_rounded;
    if (type.startsWith('event_')) return Icons.confirmation_number_rounded;
    if (type.startsWith('class_')) return Icons.school_rounded;
    return Icons.notifications_active_rounded;
  }

  Color _accentColor(String type) {
    if (type.startsWith('subscription_')) return AppColors.warning;
    if (type.startsWith('event_')) return AppColors.primary;
    if (type.startsWith('class_')) return AppColors.secondary;
    return AppColors.primary;
  }

  String _categoryLabel(String type) {
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
                // Icono con contenedor circular
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
                // Contenido textual
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
