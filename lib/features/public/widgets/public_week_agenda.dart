// lib/features/public/widgets/public_week_agenda.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/public_event_model.dart';

class PublicWeekAgenda extends StatelessWidget {
  const PublicWeekAgenda({
    super.key,
    required this.weekDays,
    required this.events,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final List<DateTime> weekDays;
  final List<PublicEventModel> events;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final eventsByDay = <DateTime, List<PublicEventModel>>{};
    for (final day in weekDays) {
      final dayEvents = events
          .where(
            (e) => DateFormatter.rangeCoversDay(e.startTime, e.endTime, day),
          )
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      eventsByDay[day] = dayEvents;
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          for (var i = 0; i < weekDays.length; i++) ...[
            _AgendaDaySection(
              day: weekDays[i],
              isSelected: _isSameDay(weekDays[i], selectedDay),
              events: eventsByDay[weekDays[i]]!,
              onDaySelected: () => onDaySelected(weekDays[i]),
            ),
            if (i != weekDays.length - 1)
              Divider(height: 1, color: context.divider),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _AgendaDaySection extends StatelessWidget {
  const _AgendaDaySection({
    required this.day,
    required this.isSelected,
    required this.events,
    required this.onDaySelected,
  });

  final DateTime day;
  final bool isSelected;
  final List<PublicEventModel> events;
  final VoidCallback onDaySelected;

  bool get _isToday {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final headerColor = isSelected || _isToday
        ? AppColors.primary
        : context.textOnBg;

    return Container(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onDaySelected,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
              child: Row(
                children: [
                  Text(
                    DateFormatter.shortDay(day).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: headerColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormatter.dayNumber(day),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                  if (_isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusSmall),
                      ),
                      child: const Text(
                        'Hoy',
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 18, color: context.textMuted),
                ],
              ),
            ),
          ),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'Sin eventos',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            )
          else
            for (final event in events) _AgendaEventTile(event: event),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _AgendaEventTile extends StatelessWidget {
  const _AgendaEventTile({required this.event});

  final PublicEventModel event;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.colorForOrganization(event.organizationId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: InkWell(
        onTap: () => context.push(
          '${AppRoutes.publicEventDetailBase}/${event.id}',
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormatter.hourMin(event.startTime),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.textOnBg,
                      ),
                    ),
                    Text(
                      DateFormatter.hourMin(event.endTime),
                      style: TextStyle(
                        fontSize: 10,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textOnBg,
                      ),
                    ),
                    if (event.organizationName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.organizationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}