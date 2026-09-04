import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/dance_class_schedule_model.dart';

/// Resultado del diálogo de horario. Cuando [id] no es nulo se trata de una
/// edición de un horario existente; si es nulo es un horario nuevo.
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

/// Diálogo reutilizable para crear o editar un horario recurrente.
///
/// Permite elegir día, hora inicio/fin y un rango de fechas opcional
/// (inicio/fin de la recurrencia). [existing] es el horario a editar (nulo
/// para uno nuevo). [classStart]/[classEnd] acotan las fechas mínimas/máximas.
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
          title: Text(
            existing == null ? 'Agregar horario' : 'Editar horario',
            style: TextStyle(color: context.textOnBg),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: dayOfWeek,
                  dropdownColor: context.cardBg,
                  style: TextStyle(color: context.textOnBg),
                  decoration: const InputDecoration(labelText: 'Día'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Lunes')),
                    DropdownMenuItem(value: 2, child: Text('Martes')),
                    DropdownMenuItem(value: 3, child: Text('Miércoles')),
                    DropdownMenuItem(value: 4, child: Text('Jueves')),
                    DropdownMenuItem(value: 5, child: Text('Viernes')),
                    DropdownMenuItem(value: 6, child: Text('Sábado')),
                    DropdownMenuItem(value: 0, child: Text('Domingo')),
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
                        decoration: const InputDecoration(labelText: 'Hora inicio'),
                        items: List.generate(24, (i) => DropdownMenuItem(
                          value: i,
                          child: Text(i.toString().padLeft(2, '0')),
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
                        decoration: const InputDecoration(labelText: 'Min'),
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
                        decoration: const InputDecoration(labelText: 'Hora fin'),
                        items: List.generate(24, (i) => DropdownMenuItem(
                          value: i,
                          child: Text(i.toString().padLeft(2, '0')),
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
                        decoration: const InputDecoration(labelText: 'Min'),
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
                  style: TextStyle(color: context.textOnBg, fontSize: 12, fontWeight: FontWeight.w500),
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
              child: const Text('Cancelar'),
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
                style: const TextStyle(color: AppColors.primary),
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