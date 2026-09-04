import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/public_event_model.dart';

/// Resultado del layout: a qué columna pertenece cada evento y
/// cuántas columnas tiene su grupo.
class _EventLayout {
  const _EventLayout(this.event, this.column, this.totalColumns);

  final PublicEventModel event;
  final int column;
  final int totalColumns;
}

/// Timeline vertical de un día (estilo Google Calendar) para la vista pública.
///
/// - Solo renderiza el rango de horas comprendido entre el primer evento y el
///   último (con un margen de 1 hora), ocultando las franjas vacías.
/// - Usa [LayoutBuilder] para ajustarse al alto disponible y NO desplazarse.
class PublicWeekTimeline extends StatelessWidget {
  const PublicWeekTimeline({
    super.key,
    required this.events,
    required this.date,
  });

  final List<PublicEventModel> events;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return _EmptyDay(date: date);

    // Rango de horas: solo las horas con eventos (margen de 1h por lado).
    // Las horas vacías NO se muestran ni marcan; los eventos quedan grandes.
    int startMin = 23 * 60 + 59;
    int endMin = 0;
    for (final e in events) {
      final s = DateFormatter.minutesFromMidnight(e.startTime);
      final e2 = DateFormatter.minutesFromMidnight(e.endTime);
      if (s < startMin) startMin = s;
      if (e2 > endMin) endMin = e2;
    }
    startMin = (startMin ~/ 60 - 1).clamp(0, 23) * 60;
    endMin = (endMin / 60).ceil().clamp(1, 24) * 60;

    final layouts = _layoutEvents(events);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final totalMinutes = (endMin - startMin);
        if (totalMinutes <= 0) return const SizedBox.shrink();

        // Alto por minuto para que todo el rango quepa sin scroll.
        final pixelPerMinute = availableHeight / totalMinutes;

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
                    ...List.generate(
                      (totalMinutes / 60).ceil() + 1,
                      (i) {
                        final minute = startMin + i * 60;
                        final top = (i * 60) * pixelPerMinute;
                        return Positioned(
                          top: top,
                          left: 0,
                          right: 4,
                          child: Transform.translate(
                            offset: const Offset(0, -7),
                            child: Text(
                              _hourLabel(minute),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Área de eventos + líneas de hora ─────────────────
              Expanded(
                child: Stack(
                  children: [
                    // Franjas de hora alternadas (sutiles) + línea fina:
                    // fondo neutro, no "horas marcadas".
                    ...List.generate((totalMinutes / 60).ceil(), (i) {
                      return Positioned(
                        top: i * 60 * pixelPerMinute,
                        left: 0,
                        right: 0,
                        height: 60 * pixelPerMinute,
                        child: i.isOdd
                            ? ColoredBox(
                                color: context.divider.withValues(alpha: 0.5),
                              )
                            : const SizedBox.shrink(),
                      );
                    }),
                    ...List.generate((totalMinutes / 60).ceil() + 1, (i) {
                      return Positioned(
                        top: i * 60 * pixelPerMinute,
                        left: 0,
                        right: 0,
                        child: Divider(
                          height: 1,
                          thickness: 0.5,
                          color: context.divider.withValues(alpha: 0.5),
                        ),
                      );
                    }),

                    // Eventos posicionados
                    ...layouts.map((layout) {
                      return _PositionedEvent(
                        layout: layout,
                        startMin: startMin,
                        pixelPerMinute: pixelPerMinute,
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
  static List<_EventLayout> _layoutEvents(List<PublicEventModel> events) {
    final sorted = [...events]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final layouts = <_EventLayout>[];
    var cluster = <PublicEventModel>[];
    var clusterEnd = sorted.first.endTime;

    void flushCluster() {
      if (cluster.isEmpty) return;

      final columnEnds = <DateTime>[];
      final columns = <String, int>{};

      for (final e in cluster) {
        var col = 0;
        // La columna está ocupada si su último evento se solapa con este
        // (termina DESPUÉS de que empieza). Los consecutivos que tocan
        // borde se apilan en la misma columna, como en Google Calendar.
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
    required this.startMin,
    required this.pixelPerMinute,
  });

  final _EventLayout layout;
  final int startMin;
  final double pixelPerMinute;

  @override
  Widget build(BuildContext context) {
    final event = layout.event;
    final startMinOfDay = DateFormatter.minutesFromMidnight(event.startTime);
    final endMinOfDay = DateFormatter.minutesFromMidnight(event.endTime);

    final top = (startMinOfDay - startMin) * pixelPerMinute;
    final height = (endMinOfDay - startMinOfDay) * pixelPerMinute;

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
            child: _PublicEventCard(
              event: event,
              onTap: () => context.push(
                '${AppRoutes.publicEventDetailBase}/${event.id}',
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Bloque de evento público
// ─────────────────────────────────────────────
class _PublicEventCard extends StatelessWidget {
  const _PublicEventCard({required this.event, required this.onTap});

  final PublicEventModel event;
  final VoidCallback onTap;

  Color get _color => AppColors.calendarEventColors[
      event.colorIndex % AppColors.calendarEventColors.length];

  @override
  Widget build(BuildContext context) {
    final durationMin =
        DateFormatter.durationMinutes(event.startTime, event.endTime);
    final isShort = durationMin < 45;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          border: Border.all(
            color: _color.withValues(alpha: 0.65),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: isShort
            ? _ShortContent(event: event, color: _color)
            : _FullContent(event: event, color: _color),
      ),
    );
  }
}

class _FullContent extends StatelessWidget {
  const _FullContent({required this.event, required this.color});
  final PublicEventModel event;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      DateFormatter.timeRange(event.startTime, event.endTime),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
                if (event.organizationName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.apartment, size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.organizationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                if (event.location?.locationName != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.place, size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!.locationName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortContent extends StatelessWidget {
  const _ShortContent({required this.event, required this.color});
  final PublicEventModel event;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final durationMin =
        DateFormatter.durationMinutes(event.startTime, event.endTime);
    final isVeryShort = durationMin < 20;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(width: 4, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormatter.timeRange(event.startTime, event.endTime),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isVeryShort ? 11 : 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isVeryShort) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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
          Icon(
            Icons.calendar_today_outlined,
            size: 56,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Sin eventos el ${DateFormatter.fullDate(date)}',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}