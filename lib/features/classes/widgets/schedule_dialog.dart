// lib/features/classes/widgets/schedule_dialog.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/dance_class_schedule_model.dart';

class ScheduleDialogResult {
  const ScheduleDialogResult({
    this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.startDate,
    this.endDate,
    this.instructorId,
    this.isActive = true,
  });

  final String? id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? instructorId;
  final bool isActive;

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'start_date': startDate?.toIso8601String().split('T')[0],
        'end_date': endDate?.toIso8601String().split('T')[0],
        'instructor_id': instructorId,
        'is_active': isActive,
      };
}

Future<ScheduleDialogResult?> showScheduleDialog(
  BuildContext context, {
  DanceClassScheduleModel? existing,
  DateTime? classStart,
  DateTime? classEnd,
}) {
  final initialDay = existing?.dayOfWeek ?? 1;
  final startHour = existing != null ? _hourOf(existing.startTime) : 19;
  final startMinute = existing != null ? _minuteOf(existing.startTime) : 0;
  final endHour = existing != null ? _hourOf(existing.endTime) : 20;
  final endMinute = existing != null ? _minuteOf(existing.endTime) : 30;

  int dayOfWeek = initialDay;
  int sHour = startHour;
  int sMinute = startMinute;
  int eHour = endHour;
  int eMinute = endMinute;
  DateTime? startDate = existing?.startDate;
  DateTime? endDate = existing?.endDate;
  String? instructorId = existing?.instructorId;

  return showDialog<ScheduleDialogResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final firstDate = classStart ?? DateTime.now();
        final lastDate = classEnd ?? DateTime.now().add(const Duration(days: 365));

        return AlertDialog(
          backgroundColor: context.cardBg,
          title: Text(
            existing == null ? 'Agregar horario' : 'Editar horario',
            style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: dayOfWeek,
                  dropdownColor: context.cardBg,
                  style: TextStyle(color: context.textOnBg),
                  decoration: InputDecoration(
                    labelText: 'Día',
                    labelStyle: TextStyle(color: context.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      borderSide: BorderSide(color: context.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      borderSide: BorderSide(color: context.divider),
                    ),
                  ),
                  items: [
                    for (final entry in const [
                      (1, 'Lunes'),
                      (2, 'Martes'),
                      (3, 'Miércoles'),
                      (4, 'Jueves'),
                      (5, 'Viernes'),
                      (6, 'Sábado'),
                      (0, 'Domingo'),
                    ])
                      DropdownMenuItem(
                        value: entry.$1,
                        child: Text(entry.$2, style: TextStyle(color: context.textOnBg)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => dayOfWeek = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: sHour,
                        dropdownColor: context.cardBg,
                        style: TextStyle(color: context.textOnBg),
                        decoration: InputDecoration(
                          labelText: 'Hora inicio',
                          labelStyle: TextStyle(color: context.textMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            borderSide: BorderSide(color: context.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            borderSide: BorderSide(color: context.divider),
                          ),
                        ),
                        items: List.generate(24, (i) => DropdownMenuItem(
                          value: i,
                          child: Text(i.toString().padLeft(2, '0'), style: TextStyle(color: context.textOnBg)),
                        )),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => sHour = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: sMinute,
                        dropdownColor: context.cardBg,
                        style: TextStyle(color: context.textOnBg),
                        decoration: InputDecoration(
                          labelText: 'Min',
                          labelStyle: TextStyle(color: context.textMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            borderSide: BorderSide(color: context.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            borderSide: BorderSide(color: context.divider),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('00')),
                          DropdownMenuItem(value: 15, child: Text('15')),
                          DropdownMenuItem(value: 30, child: Text('30')),
                          DropdownMenuItem(value: 45, child: Text('45')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => sMinute = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: eHour,
                        dropdownColor: context.cardBg,
                        style: TextStyle(color: context.textOnBg),
                        decoration: InputDecoration(
                          labelText: 'Hora fin',
                          labelStyle: TextStyle(color: context.textMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            borderSide: BorderSide(color: context.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            borderSide: BorderSide(color: context.divider),
                          ),
                        ),
                        items: List.generate(24, (i) => DropdownMenuItem(
                          value: i,
                          child: Text(i.toString().padLeft(2, '0'), style: TextStyle(color: context.textOnBg)),
                        )),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => eHour = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: eMinute,
                        dropdownColor: context.cardBg,
                        style: TextStyle(color: context.textOnBg),
                        decoration: InputDecoration(
                          labelText: 'Min',
                          labelStyle: TextStyle(color: context.textMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            borderSide: BorderSide(color: context.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            borderSide: BorderSide(color: context.divider),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('00')),
                          DropdownMenuItem(value: 15, child: Text('15')),
                          DropdownMenuItem(value: 30, child: Text('30')),
                          DropdownMenuItem(value: 45, child: Text('45')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => eMinute = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Rango de fechas (opcional)',
                  style: TextStyle(color: context.textOnBg, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? firstDate,
                            firstDate: firstDate,
                            lastDate: lastDate,
                          );
                          if (picked != null) {
                            setDialogState(() => startDate = picked);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textOnBg,
                          side: BorderSide(color: context.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                          ),
                        ),
                        child: Text(
                          startDate == null
                              ? 'Inicio'
                              : '${startDate!.day.toString().padLeft(2, '0')}/${startDate!.month.toString().padLeft(2, '0')}/${startDate!.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? firstDate,
                            firstDate: firstDate,
                            lastDate: lastDate,
                          );
                          if (picked != null) {
                            setDialogState(() => endDate = picked);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textOnBg,
                          side: BorderSide(color: context.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                          ),
                        ),
                        child: Text(
                          endDate == null
                              ? 'Fin'
                              : '${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  ScheduleDialogResult(
                    id: existing?.id,
                    dayOfWeek: dayOfWeek,
                    startTime:
                        '${sHour.toString().padLeft(2, '0')}:${sMinute.toString().padLeft(2, '0')}:00',
                    endTime:
                        '${eHour.toString().padLeft(2, '0')}:${eMinute.toString().padLeft(2, '0')}:00',
                    startDate: startDate,
                    endDate: endDate,
                    instructorId: instructorId,
                    isActive: existing?.isActive ?? true,
                  ),
                );
              },
              child: Text(
                existing == null ? 'Agregar' : 'Guardar',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ),
  );
}

int _hourOf(String time) => int.parse(time.split(':')[0]);

int _minuteOf(String time) {
  final parts = time.split(':');
  return parts.length > 1 ? int.parse(parts[1]) : 0;
}