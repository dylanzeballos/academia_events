import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/theme_extensions.dart';
import '../../data/models/dance_class_session_model.dart';

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    this.onTap,
    this.trailing,
  });

  final DanceClassSessionModel session;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${session.sessionDate.day.toString().padLeft(2, '0')}/${session.sessionDate.month.toString().padLeft(2, '0')}/${session.sessionDate.year}';
    final startStr =
        '${session.startAt.hour.toString().padLeft(2, '0')}:${session.startAt.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${session.endAt.hour.toString().padLeft(2, '0')}:${session.endAt.minute.toString().padLeft(2, '0')}';

    Color statusColor;
    IconData statusIcon;
    switch (session.status) {
      case 'scheduled':
        statusColor = AppColors.primary;
        statusIcon = Icons.calendar_today;
        break;
      case 'completed':
        statusColor = AppColors.success;
        statusIcon = Icons.check;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusIcon = Icons.close;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      color: context.cardBg,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Icon(statusIcon, color: statusColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$startStr - $endStr',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    session.statusDisplayName,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
