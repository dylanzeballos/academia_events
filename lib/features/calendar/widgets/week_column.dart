import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../providers/events_provider.dart';
import '../../../../data/models/event_model.dart';
import 'event_preview_sheet.dart';

/// Vista de semana compacta (los 7 días visibles a la vez, estilo Google
/// Calendar con columnas). Cada día es una columna; los eventos se posicionan
/// por hora dentro de un canvas de alto fijo.
///
/// Soporta:
/// - Scroll vertical por horas.
/// - Pinch-to-zoom para ampliar/reducir el alto por hora.
/// - Deslizar horizontalmente para cambiar de semana.
/// - Tocar una columna para abrir la vista de día.
class WeekColumns extends ConsumerStatefulWidget {
  const WeekColumns({
    super.key,
    required this.weekDays,
    required this.events,
    required this.selectedDay,
    required this.heightPerHour,
    required this.onDaySelected,
  });

  final List<DateTime> weekDays;
  final List<EventModel> events;
  final DateTime selectedDay;
  final double heightPerHour;
  final ValueChanged<DateTime> onDaySelected;

  @override
  ConsumerState<WeekColumns> createState() => _WeekColumnsState();
}

class _WeekColumnsState extends ConsumerState<WeekColumns> {
  final ScrollController _scrollController = ScrollController();

  /// Alto por hora actual (modificable con pinch-to-zoom).
  double _heightPerHour = 48;
  static const double _minHeightPerHour = 24;
  static const double _maxHeightPerHour = 160;

  /// Punteros activos y separación previa, para el pinch-to-zoom manual.
  final Map<int, Offset> _points = {};
  double? _lastSpacing;

  void _onPointerDown(PointerDownEvent event) {
    _points[event.pointer] = event.position;
    _lastSpacing = null;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_points.containsKey(event.pointer)) return;
    _points[event.pointer] = event.position;

    if (_points.length < 2) {
      _lastSpacing = null;
      return;
    }

    final ps = _points.values.take(2).toList();
    final spacing = (ps[0] - ps[1]).distance;
    final previous = _lastSpacing;
    _lastSpacing = spacing;

    if (previous == null || previous <= 0 || spacing <= 0) return;

    final target = (_heightPerHour * spacing / previous).clamp(
      _minHeightPerHour,
      _maxHeightPerHour,
    );

    if (target != _heightPerHour) {
      setState(() => _heightPerHour = target);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _points.remove(event.pointer);
    _lastSpacing = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _points.remove(event.pointer);
    _lastSpacing = null;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<EventModel> get events => widget.events;
  DateTime get selectedDay => widget.selectedDay;
  List<DateTime> get weekDays => widget.weekDays;
  double get heightPerHour => _heightPerHour;
  ValueChanged<DateTime> get onDaySelected => widget.onDaySelected;

  void _enterDayView(DateTime day) {
    if (Navigator.of(context).mounted) {
      onDaySelected(day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = <int, List<EventModel>>{};
    for (final day in weekDays) {
      dayEvents[day.weekday] = events
          .where(
            (e) =>
                e.startTime.year == day.year &&
                e.startTime.month == day.month &&
                e.startTime.day == day.day,
          )
          .toList();
    }

    // Rango de horas global: de 0 a 24 siempre (para que las columnas se
    // alineen). El canvas interno usa un contenedor con alto fijo y scroll.
    const startHour = 0;
    const endHour = 24;
    final totalHours = endHour - startHour;
    final canvasHeight = totalHours * _heightPerHour;

    // Ancho de la columna de etiquetas de hora (más estrecha que en día)
    const labelWidth = 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final timeColumnWidth = labelWidth;
              final gridWidth = availableWidth - timeColumnWidth;
              final colWidth = gridWidth / weekDays.length;

              // Listener: captura el pinch-to-zoom SIN entrar al arena de
              // gestos (no bloquea el scroll de 1 dedo ni la rueda).
              return Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Deslizar horizontal para cambiar de semana
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity ?? 0;
                    if (v < -200) {
                      ref.read(selectedWeekProvider.notifier).nextWeek();
                    } else if (v > 200) {
                      ref.read(selectedWeekProvider.notifier).previousWeek();
                    }
                  },
                  // UN único scroll vertical: etiquetas de hora + grid de días
                  // comparten el mismo scroll position, por lo que SIEMPRE se
                  // mueven juntas al hacer scroll (rueda o dedo).
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: SizedBox(
                      height: canvasHeight,
                      width: availableWidth,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Etiquetas de hora ─────────────────────────
                          SizedBox(
                            width: timeColumnWidth,
                            child: _TimeLabels(
                              startHour: startHour,
                              totalHours: totalHours,
                              heightPerHour: _heightPerHour,
                            ),
                          ),
                          // ── Columnas de días ─────────────────────────
                          Expanded(
                            child: SizedBox(
                              width: gridWidth,
                              child: Row(
                                children: weekDays.map((day) {
                                  final isSelected = _isSameDay(
                                    day,
                                    selectedDay,
                                  );
                                  return SizedBox(
                                    width: colWidth,
                                    child: _DayColumnBody(
                                      day: day,
                                      isSelected: isSelected,
                                      events:
                                          dayEvents[day.weekday] ?? const [],
                                      startHour: startHour,
                                      totalHours: totalHours,
                                      heightPerHour: _heightPerHour,
                                      onTap: () => _enterDayView(day),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────
// Etiquetas de hora de la columna izquierda
// ─────────────────────────────────────────────
class _TimeLabels extends StatelessWidget {
  const _TimeLabels({
    required this.startHour,
    required this.totalHours,
    required this.heightPerHour,
  });

  final int startHour;
  final int totalHours;
  final double heightPerHour;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: totalHours * heightPerHour,
      child: Stack(
        children: List.generate(totalHours, (i) {
          final hour = startHour + i;
          return Positioned(
            top: i * heightPerHour + 2,
            left: 0,
            right: 4,
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Cuerpo de una columna de día
// ─────────────────────────────────────────────
class _DayColumnBody extends StatelessWidget {
  const _DayColumnBody({
    required this.day,
    required this.isSelected,
    required this.events,
    required this.startHour,
    required this.totalHours,
    required this.heightPerHour,
    required this.onTap,
  });

  final DateTime day;
  final bool isSelected;
  final List<EventModel> events;
  final int startHour;
  final int totalHours;
  final double heightPerHour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layouts = WeekTimelineLayout.layout(events);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          border: Border(
            left: BorderSide(color: context.divider.withValues(alpha: 0.4)),
          ),
        ),
        child: Stack(
          children: [
            // Líneas de hora
            ...List.generate(totalHours + 1, (i) {
              return Positioned(
                top: i * heightPerHour,
                left: 0,
                right: 0,
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: context.divider.withValues(alpha: 0.4),
                ),
              );
            }),
            // Eventos (ancho proporcional al número de columnas del clúster)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final colWidth = constraints.maxWidth;
                  return ClipRect(
                    child: Stack(
                      children: layouts.map((layout) {
                        final event = layout.event;
                        final startMin = DateFormatter.minutesFromMidnight(
                          event.startTime,
                        );
                        final endMin = DateFormatter.minutesFromMidnight(
                          event.endTime,
                        );
                        final timelineOrigin = startHour * 60;
                        final top =
                            (startMin - timelineOrigin) * heightPerHour / 60;
                        final height = (endMin - startMin) * heightPerHour / 60;
                        final itemWidth = colWidth / layout.totalColumns;

                        return Positioned(
                          top: top,
                          left: itemWidth * layout.column,
                          width: itemWidth,
                          height: height,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: _WeekEventTile(
                              event: event,
                              onTap: () =>
                                  EventPreviewSheet.show(context, event),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reutiliza el algoritmo de layout por clústeres del timeline de día,
/// expuesto de forma pública para la vista de semana.
class WeekTimelineLayout {
  static List<WeekTimelineSlot> layout(List<EventModel> events) {
    final sorted = [...events]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final slots = <WeekTimelineSlot>[];

    if (sorted.isEmpty) return slots;

    var cluster = <EventModel>[];
    var clusterEnd = sorted.first.endTime;

    void flushCluster() {
      if (cluster.isEmpty) return;
      final columnEnds = <DateTime>[];
      final columns = <String, int>{};

      for (final e in cluster) {
        var col = 0;
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
        slots.add(
          WeekTimelineSlot(
            event: e,
            column: columns[e.id]!,
            totalColumns: columnEnds.length,
          ),
        );
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

    return slots;
  }
}

class WeekTimelineSlot {
  const WeekTimelineSlot({
    required this.event,
    required this.column,
    required this.totalColumns,
  });

  final EventModel event;
  final int column;
  final int totalColumns;
}

/// Bloque compacto de evento para la vista de semana.
///
/// A diferencia de la tarjeta usada en la vista de día, este tile está
/// pensado para columnas muy estrechas y tramos cortos: no muestra filas fijas
/// que desborden el alto disponible, sino una pastilla de color con el título
/// (solo si hay margen) y acento lateral. Envuelto en [FittedBox]/recorte para
/// que NUNCA genere errores de overflow y nunca se dibuje encima del vecino.
class _WeekEventTile extends StatelessWidget {
  const _WeekEventTile({required this.event, this.onTap});

  final EventModel event;
  final VoidCallback? onTap;

  Color get _color {
    final colors = AppColors.calendarEventColors;
    return colors[event.colorIndex % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white : Colors.black87;
    final veryShort = event.endTime.difference(event.startTime).inMinutes < 30;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          border: Border.all(color: _color.withValues(alpha: 0.75), width: 1),
        ),
        child: Row(
          children: [
            // Franja de acento vertical
            Container(width: 3, color: _color),
            const SizedBox(width: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      veryShort ? '' : event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}
