import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

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
        const Text(
          'Fecha y Hora',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today, color: AppColors.primary),
          title: const Text('Inicio del evento'),
          subtitle: Text(
            '${startDate.day}/${startDate.month}/${startDate.year} - ${startTime.format(context)}',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => onPickDateTime(isStart: true),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_busy, color: AppColors.primary),
          title: const Text('Fin del evento'),
          subtitle: Text(
            '${endDate.day}/${endDate.month}/${endDate.year} - ${endTime.format(context)}',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => onPickDateTime(isStart: false),
        ),
        const Divider(),
      ],
    );
  }
}