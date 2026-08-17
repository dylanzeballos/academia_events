import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event_model.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final EventModel event;
  final VoidCallback? onTap;

  Color get _color {
    final colors = AppColors.calendarEventColors;
    return colors[event.colorIndex % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final durationMin =
        DateFormatter.durationMinutes(event.startTime, event.endTime);
    final isShort = durationMin < 45;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          border: Border(left: BorderSide(color: _color, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: isShort
            ? _ShortContent(event: event, color: _color)
            : _FullContent(event: event, color: _color),
      ),
    );
  }
}

class _FullContent extends StatelessWidget {
  const _FullContent({required this.event, required this.color});
  final EventModel event;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormatter.timeRange(event.startTime, event.endTime),
          style: const TextStyle(color: Colors.white60, fontSize: 9),
        ),
        if (event.organizationName.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            event.organizationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
        ],
      ],
    );
  }
}

class _ShortContent extends StatelessWidget {
  const _ShortContent({required this.event, required this.color});
  final EventModel event;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${event.title} · ${DateFormatter.hourMin(event.startTime)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
