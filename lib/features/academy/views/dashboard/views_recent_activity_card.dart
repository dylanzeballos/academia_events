import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../providers/organization_provider.dart';

class ViewsRecentActivityCard extends ConsumerWidget {
  const ViewsRecentActivityCard({
    super.key,
    required this.organizationId,
    this.maxItems = 10,
  });

  final String organizationId;
  final int maxItems;

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    return DateFormat('dd/MM/yy').format(dt.toLocal());
  }

  ({IconData icon, Color color}) _styleForType(String type) {
    switch (type) {
      case 'attendance':
        return (icon: Icons.qr_code_2_rounded, color: AppColors.success);
      case 'ticket_order':
        return (
          icon: Icons.confirmation_number_outlined,
          color: AppColors.secondary,
        );
      case 'instructor':
        return (icon: Icons.person_outline, color: AppColors.warning);
      case 'enrollment':
      default:
        return (
          icon: Icons.assignment_turned_in_outlined,
          color: AppColors.primary,
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync =
        ref.watch(organizationRecentActivityProvider(organizationId));

    return Card(
      color: context.cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: activityAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No se pudo cargar la actividad reciente.',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
        ),
        data: (rawItems) {
          final items = rawItems.take(maxItems).toList();

          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Aún no hay actividad reciente en esta academia.',
                  style: TextStyle(color: context.textMuted, fontSize: 13),
                ),
              ),
            );
          }

          return Column(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isLast = index == items.length - 1;
              final style = _styleForType(item.type);

              return Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: style.color.withValues(alpha: 0.15),
                      child: Icon(
                        style.icon,
                        size: 18,
                        color: style.color,
                      ),
                    ),
                    title: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(color: context.textOnBg, fontSize: 13),
                        children: [
                          TextSpan(
                            text: '${item.userName} ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: item.actionText,
                            style: TextStyle(color: context.textMuted),
                          ),
                        ],
                      ),
                    ),
                    trailing: Text(
                      _formatRelativeTime(item.occurredAt),
                      style: TextStyle(color: context.textMuted, fontSize: 11),
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 60, color: context.divider),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}