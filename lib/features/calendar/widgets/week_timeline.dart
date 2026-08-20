import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event_model.dart';
import 'event_card.dart';

/// Timeline vertical de un día.
///
/// Algoritmo de solapamiento:
/// 1. Se detectan grupos de eventos que se solapan entre sí.
/// 2. Dentro de cada grupo, el ancho disponible se divide por igual
///    entre todos los miembros.
/// 3. Cada evento ocupa la columna correspondiente a su [colorIndex]
///    módulo el tamaño del grupo.
/// 4. El resultado es que dos eventos simultáneos se muestran lado a lado,
///    nunca encima del otro.
class WeekTimeline extends StatelessWidget {
  const WeekTimeline({
    super.key,
    required this.events,
    required this.date,
    this.startHour = 6,
    this.endHour = 23,
  });

  final List<EventModel> events;
  final DateTime date;
  final int startHour;
  final int endHour;

  double get _totalHeight =>
      (endHour - startHour) * AppSizes.calendarHourHeight;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return _EmptyDay(date: date);

    final groupSizes = _computeGroupSizes(events);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: SizedBox(
        height: _totalHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Columna de etiquetas de hora ──────────────────────
            SizedBox(
              width: 48,
              child: Stack(
                children: List.generate(endHour - startHour, (i) {
                  final hour = startHour + i;
                  return Positioned(
                    top: i * AppSizes.calendarHourHeight - 7,
                    left: 0,
                    right: 4,
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Área de eventos + líneas de hora ─────────────────
            Expanded(
              child: Stack(
                children: [
                  // Líneas horizontales por hora
                  ...List.generate(endHour - startHour, (i) {
                    return Positioned(
                      top: i * AppSizes.calendarHourHeight,
                      left: 0,
                      right: 0,
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: context.divider,
                      ),
                    );
                  }),

                  // Indicador de "ahora"
                  _NowIndicator(
                    startHour: startHour,
                    endHour: endHour,
                    date: date,
                  ),

                  // Eventos posicionados
                  ...events.map((event) {
                    return _PositionedEvent(
                      event: event,
                      startHour: startHour,
                      groupSize: groupSizes[event.id] ?? 1,
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// Para cada evento devuelve cuántos eventos se solapan con él
  /// (incluido él mismo). Ese número es el ancho de columna que usa.
  Map<String, int> _computeGroupSizes(List<EventModel> events) {
    final result = <String, int>{};
    for (final event in events) {
      final overlapping =
          events.where((e) => e.overlapsWith(event)).length;
      result[event.id] = overlapping;
    }
    return result;
  }
}

// ─────────────────────────────────────────────
// Evento posicionado absolutamente
// ─────────────────────────────────────────────
class _PositionedEvent extends StatelessWidget {
  const _PositionedEvent({
    required this.event,
    required this.startHour,
    required this.groupSize,
  });

  final EventModel event;
  final int startHour;
  final int groupSize;

  @override
  Widget build(BuildContext context) {
    final startMin = DateFormatter.minutesFromMidnight(event.startTime);
    final endMin = DateFormatter.minutesFromMidnight(event.endTime);
    final timelineOrigin = startHour * 60;

    final top =
        (startMin - timelineOrigin) * AppSizes.calendarHourHeight / 60;
    final height = ((endMin - startMin) * AppSizes.calendarHourHeight / 60)
        .clamp(AppSizes.calendarHourHeight * 0.35, double.infinity);

    // columna dentro del grupo
    final colIndex = event.colorIndex % groupSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final colWidth = totalWidth / groupSize;

        return Positioned(
          top: top,
          left: colWidth * colIndex,
          width: colWidth,
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: EventCard(event: event),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Línea roja de "hora actual"
// ─────────────────────────────────────────────
class _NowIndicator extends StatelessWidget {
  const _NowIndicator({
    required this.startHour,
    required this.endHour,
    required this.date,
  });

  final int startHour;
  final int endHour;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Solo mostrar si la fecha del timeline es hoy
    if (now.year != date.year ||
        now.month != date.month ||
        now.day != date.day) {
      return const SizedBox.shrink();
    }

    final minutes = DateFormatter.minutesFromMidnight(now);
    final timelineStart = startHour * 60;
    final timelineEnd = endHour * 60;

    if (minutes < timelineStart || minutes > timelineEnd) {
      return const SizedBox.shrink();
    }

    final top =
        (minutes - timelineStart) * AppSizes.calendarHourHeight / 60;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
          ),
          Expanded(
            child: Container(height: 1.5, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Estado vacío
// ─────────────────────────────────────────────
class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 56,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin eventos el ${DateFormatter.fullDate(date)}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
