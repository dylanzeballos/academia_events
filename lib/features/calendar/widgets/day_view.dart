import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event_model.dart';
import 'week_column.dart';

/// Vista de un solo día (estilo Google Calendar).
///
/// Muestra la cabecera del día con navegación (anterior/siguiente) y el MISMO
/// pintado de la vista semanal: una columna de un solo día con timeline
/// completo de 0 a 24 h, las mismoas horas del costado que la semana y las
/// mismas tarjetas de evento ([WeekColumns] con su tarjeta por defecto).
///
/// Al abrir un día (o navegar con las flechas) la vista se desplaza
/// automáticamente al primer evento del día para que las clases/eventos
/// nocturnos (19:00, 16:00...) no queden fuera de pantalla.
class DayView extends StatelessWidget {
  const DayView({
    super.key,
    required this.events,
    required this.selectedDay,
    required this.onBack,
    this.onPreviousDay,
    this.onNextDay,
  });

  final List<EventModel> events;
  final DateTime selectedDay;
  final VoidCallback onBack;
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // SOLO eventos y clases de este día (rangeCoversDay para que un evento
    // multi-día también aparezca en los días que cubre).
    final dayEvents = events
        .where(
          (e) => DateFormatter.rangeCoversDay(
            e.startTime,
            e.endTime,
            selectedDay,
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Cabecera del día ───────────────────────────────────
            _DayHeader(
              day: selectedDay,
              eventCount: dayEvents.length,
              onBack: onBack,
              onPreviousDay: onPreviousDay,
              onNextDay: onNextDay,
            ),
            Divider(height: 1, color: context.divider),
            // ── Columna de un día (idéntica al render de la semana) ──
            Expanded(
              child: WeekColumns(
                weekDays: [selectedDay],
                events: events,
                selectedDay: selectedDay,
                heightPerHour: 52,
                onDaySelected: (_) {},
                onSwipeLeft: onNextDay,
                onSwipeRight: onPreviousDay,
                autoScrollToEarliest: true,
                showNowLine: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Cabecera del día
// ─────────────────────────────────────────────
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.eventCount,
    required this.onBack,
    this.onPreviousDay,
    this.onNextDay,
  });

  final DateTime day;
  final int eventCount;
  final VoidCallback onBack;
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      color: isDark ? AppColors.background : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: onBack,
            tooltip: 'Volver a la semana',
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.chevron_left, color: textColor),
            onPressed: onPreviousDay,
            tooltip: 'Día anterior',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  DateFormatter.fullDate(day),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  eventCount == 0
                      ? 'Sin eventos'
                      : eventCount == 1
                      ? '1 evento'
                      : '$eventCount eventos',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: textColor),
            onPressed: onNextDay,
            tooltip: 'Día siguiente',
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}