import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';
import 'week_column.dart';

class DayView extends StatelessWidget {
  const DayView({
    super.key,
    required this.day,
    required this.events,
    required this.onClose,
    required this.onChanged,
  });

  final DateTime day;
  final List<EventModel> events;
  final VoidCallback onClose;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final dayEvents = events
        .where((e) => DateFormatter.rangeCoversDay(e.startTime, e.endTime, day))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a la semana',
          icon: const Icon(Icons.arrow_back),
          onPressed: onClose,
        ),
        title: Text(
          DateFormatter.capitalize(DateFormatter.fullDate(day)),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Día anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(day.subtract(const Duration(days: 1))),
          ),
          IconButton(
            tooltip: 'Día siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(day.add(const Duration(days: 1))),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              dayEvents.isEmpty
                  ? 'Sin eventos'
                  : '${dayEvents.length} '
                      '${dayEvents.length == 1 ? 'evento' : 'eventos'}',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: WeekColumns(
              weekDays: [day],
              events: events,
              selectedDay: day,
              heightPerHour: 60,
              autoScrollToEarliest: dayEvents.isNotEmpty,
              showNowLine: true,
              onDaySelected: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}