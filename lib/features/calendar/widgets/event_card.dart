import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event_model.dart';

/// Bloque de evento para el timeline: totalmente pintado con su color,
/// texto blanco y altura completa del tramo horario que ocupa.
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
        // Bloque sólido: pinta todo el tramo de tiempo que ocupa.
        decoration: BoxDecoration(
          color: _color,
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          boxShadow: [
            BoxShadow(
              color: _color.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: isShort
            ? _ShortContent(event: event)
            : _FullContent(event: event),
      ),
    );
  }
}

class _FullContent extends StatelessWidget {
  const _FullContent({required this.event});
  final EventModel event;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormatter.timeRange(event.startTime, event.endTime),
          style: const TextStyle(color: Colors.white, fontSize: 9.5),
        ),
        if (event.organizationName.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            event.organizationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
        if (event.location?.locationName != null) ...[
          const SizedBox(height: 1),
          Row(
            children: [
              const Icon(Icons.place, color: Colors.white70, size: 10),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  event.location!.locationName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ShortContent extends StatelessWidget {
  const _ShortContent({required this.event});
  final EventModel event;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '${DateFormatter.hourMin(event.startTime)} ${event.title}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.15,
        ),
      ),
    );
  }
}
