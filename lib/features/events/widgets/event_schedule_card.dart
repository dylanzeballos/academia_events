import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/event_model.dart';

class EventScheduleCard extends StatelessWidget {
  const EventScheduleCard({
    super.key,
    required this.event,
    required this.accentColor,
  });

  final EventModel event;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calendar_today_outlined, color: accentColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                _ScheduleRow(
                  icon: Icons.play_arrow_rounded,
                  label: 'Inicio',
                  value:
                      '${DateFormatter.fullDate(event.startTime)} · ${DateFormatter.hourMin(event.startTime)}',
                ),
                const SizedBox(height: 8),
                _ScheduleRow(
                  icon: Icons.stop_rounded,
                  label: 'Fin',
                  value:
                      '${DateFormatter.fullDate(event.endTime)} · ${DateFormatter.hourMin(event.endTime)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}