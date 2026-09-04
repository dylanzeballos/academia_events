import 'package:flutter/material.dart';

import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event_model.dart';
import 'event_card.dart';
import 'event_preview_sheet.dart';

/// Resultado del layout: a qué columna pertenece cada evento y
/// cuántas columnas tiene su grupo.
class _EventLayout {
  const _EventLayout(this.event, this.column, this.totalColumns);

  final EventModel event;
  final int column;
  final int totalColumns;
}

/// Timeline vertical de un día (estilo Google Calendar).
///
/// Algoritmo de solapamiento por clústeres:
/// 1. Los eventos se ordenan por hora de inicio.
/// 2. Se forman clústeres: eventos conectados transitoriamente por
///    solapamiento (A solapa con B, B con C ⇒ A,B,C en el mismo clúster).
/// 3. Dentro de cada clúster se asignan columnas reales: cada evento toma
///    la primera columna libre (que no esté ocupada por un evento que lo
///    solape). El ancho del clúster es el total de columnas usadas.
/// 4. Resultado: los eventos simultáneos se muestran lado a lado y NUNCA
///    se dibujan encima unos de otros.
class WeekTimeline extends StatelessWidget {
  const WeekTimeline({
    super.key,
    required this.events,
    required this.date,
  });

  final List<EventModel> events;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return _EmptyDay(date: date);

    // Rango de horas: solo las horas con eventos (con un margen de 1h por
    // cada lado). Así las horas vacías NO se muestran ni marcan, y los
    // eventos quedan más grandes y legibles.
    var startHour = 23;
    var endHour = 0;
    for (final e in events) {
      final s = e.startTime.hour;
      final e2 = (e.endTime.minute > 0 ? e.endTime.hour + 1 : e.endTime.hour);
      if (s < startHour) startHour = s;
      if (e2 > endHour) endHour = e2;
    }
    startHour = (startHour - 1).clamp(0, 23);
    endHour = (endHour + 1).clamp(1, 24);
    final totalHours = endHour - startHour;
    if (totalHours <= 0) return _EmptyDay(date: date);

    final layouts = _layoutEvents(events);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        if (availableHeight <= 0) return const SizedBox.shrink();

        // Alto por hora para que TODO el rango quepa sin scroll.
        final pixelPerHour = availableHeight / totalHours;

        return Container(
          color: context.scaffoldBg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Columna de etiquetas de hora ──────────────────────
              SizedBox(
                width: 48,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: context.scaffoldBg),
                    ),
                    ...List.generate(totalHours + 1, (i) {
                      final minute = startHour * 60 + i * 60;
                      return Positioned(
                        top: i * pixelPerHour - 7,
                        left: 0,
                        right: 4,
                        child: Text(
                          _hourLabel(minute),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // ── Área de eventos + líneas de hora ─────────────────
              Expanded(
                child: Stack(
                  children: [
                    // Franjas de hora alternadas (muy sutiles, como Google
                    // Calendar) + línea fina por hora: fondo neutro, no
                    // "horas marcadas".
                    ...List.generate(totalHours, (i) {
                      return Positioned(
                        top: i * pixelPerHour,
                        left: 0,
                        right: 0,
                        height: pixelPerHour,
                        child: i.isOdd
                            ? ColoredBox(
                                color: context.divider.withValues(alpha: 0.5),
                              )
                            : const SizedBox.shrink(),
                      );
                    }),
                    ...List.generate(totalHours + 1, (i) {
                      return Positioned(
                        top: i * pixelPerHour,
                        left: 0,
                        right: 0,
                        child: Divider(
                          height: 1,
                          thickness: 0.5,
                          color: context.divider.withValues(alpha: 0.5),
                        ),
                      );
                    }),

                    // Indicador de "ahora"
                    _NowIndicator(
                      startHour: startHour,
                      endHour: endHour,
                      date: date,
                      pixelPerHour: pixelPerHour,
                    ),

                    // Eventos posicionados
                    ...layouts.map((layout) {
                      return _PositionedEvent(
                        layout: layout,
                        startHour: startHour,
                        pixelPerHour: pixelPerHour,
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }

  static String _hourLabel(int minuteOfDay) {
    final hour = minuteOfDay ~/ 60;
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  /// Asigna columna y total de columnas a cada evento del día.
  static List<_EventLayout> _layoutEvents(List<EventModel> events) {
    final sorted = [...events]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final layouts = <_EventLayout>[];
    var cluster = <EventModel>[];
    var clusterEnd = sorted.first.endTime;

    void flushCluster() {
      if (cluster.isEmpty) return;

      // Hora de fin del último evento colocado en cada columna.
      final columnEnds = <DateTime>[];
      final columns = <String, int>{};

      for (final e in cluster) {
        var col = 0;
        // La columna está ocupada si su último evento se solapa con este
        // (termina DESPUÉS de que empieza este). Los eventos consecutivos
        // que tocan borde (uno termina justo cuando empieza el otro) se
        // apilan en la misma columna, como en Google Calendar.
        while (col < columnEnds.length &&
            columnEnds[col].isAfter(e.startTime)) {
          col++;
        }
        if (col == columnEnds.length) {
          columnEnds.add(e.endTime);
        } else {
          columnEnds[col] = e.endTime;
        }
        columns[e.id] = col;
      }

      for (final e in cluster) {
        layouts.add(_EventLayout(e, columns[e.id]!, columnEnds.length));
      }
      cluster = [];
    }

    for (final e in sorted) {
      // Si empieza después de que termina TODO el clúster actual,
      // cierra el clúster y abre uno nuevo.
      if (cluster.isNotEmpty && !e.startTime.isBefore(clusterEnd)) {
        flushCluster();
      }
      if (e.endTime.isAfter(clusterEnd)) clusterEnd = e.endTime;
      cluster.add(e);
    }
    flushCluster();

    return layouts;
  }
}

// ─────────────────────────────────────────────
// Evento posicionado absolutamente
// ─────────────────────────────────────────────
class _PositionedEvent extends StatelessWidget {
  const _PositionedEvent({
    required this.layout,
    required this.startHour,
    required this.pixelPerHour,
  });

  final _EventLayout layout;
  final int startHour;
  final double pixelPerHour;

  @override
  Widget build(BuildContext context) {
    final event = layout.event;
    final startMin = DateFormatter.minutesFromMidnight(event.startTime);
    final endMin = DateFormatter.minutesFromMidnight(event.endTime);
    final timelineOrigin = startHour * 60;

    final top = (startMin - timelineOrigin) * pixelPerHour / 60;
    final height = (endMin - startMin) * pixelPerHour / 60;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final colWidth = totalWidth / layout.totalColumns;

        return Positioned(
          top: top,
          left: colWidth * layout.column,
          width: colWidth,
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: EventCard(
              event: event,
              onTap: () => EventPreviewSheet.show(context, event),
            ),
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
    required this.pixelPerHour,
  });

  final int startHour;
  final int endHour;
  final DateTime date;
  final double pixelPerHour;

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

    final top = (minutes - timelineStart) * pixelPerHour / 60;

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
