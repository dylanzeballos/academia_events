import 'package:flutter/material.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

class EventScheduleForm extends StatelessWidget {
  const EventScheduleForm({
    super.key,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.onPickDateTime,
  });

  final DateTime startDate;
  final TimeOfDay startTime;
  final DateTime endDate;
  final TimeOfDay endTime;
  final void Function({required bool isStart}) onPickDateTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Fecha y Hora',
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today, color: AppColors.primary),
          title: Text('Inicio del evento', style: TextStyle(color: context.textOnBg)),
          subtitle: Text(
            '${startDate.day}/${startDate.month}/${startDate.year} - ${startTime.format(context)}',
            style: TextStyle(color: context.textMuted),
          ),
          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: context.textMuted),
          onTap: () => onPickDateTime(isStart: true),
        ),
        Divider(color: context.divider),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_busy, color: AppColors.primary),
          title: Text('Fin del evento', style: TextStyle(color: context.textOnBg)),
          subtitle: Text(
            '${endDate.day}/${endDate.month}/${endDate.year} - ${endTime.format(context)}',
            style: TextStyle(color: context.textMuted),
          ),
          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: context.textMuted),
          onTap: () => onPickDateTime(isStart: false),
        ),
        Divider(color: context.divider),
      ],
    );
  }
}