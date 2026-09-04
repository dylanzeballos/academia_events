import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event_model.dart';
import 'event_preview_sheet.dart';
import 'week_column.dart';

/// Vista de un solo día (estilo Google Calendar).
///
/// Se abre con una transición lateral desde la semana. Muestra una cabecera
/// con el nombre del día y la fecha, y un timeline vertical completo de
/// 0 a 24 h con líneas de hora, indicador de "ahora" y eventos no
/// solapados (mismo algoritmo de clústeres, nunca se superponen).
///
/// El grid de horarios se puede ampliar/reducir con pinch-to-zoom.
class DayView extends StatefulWidget {
  const DayView({
    super.key,
    required this.events,
    required this.selectedDay,
    required this.onBack,
  });

  final List<EventModel> events;
  final DateTime selectedDay;
  final VoidCallback onBack;

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  final ScrollController _scrollController = ScrollController();

  /// Alto por hora actual (modificable con pinch-to-zoom).
  double _heightPerHour = 52;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Solo eventos de este día
    final dayEvents = widget.events
        .where(
          (e) =>
              e.startTime.year == widget.selectedDay.year &&
              e.startTime.month == widget.selectedDay.month &&
              e.startTime.day == widget.selectedDay.day,
        )
        .toList();

    // Timeline de 0 a 24 h
    const startHour = 0;
    const endHour = 24;
    final totalHours = endHour - startHour;
    final canvasHeight = totalHours * _heightPerHour;

    final layouts = WeekTimelineLayout.layout(dayEvents);

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Cabecera del día ───────────────────────────────────
            _DayHeader(
              day: widget.selectedDay,
              eventCount: dayEvents.length,
              onBack: widget.onBack,
            ),
            Divider(height: 1, color: context.divider),
            Expanded(
              // Listener: captura el pinch-to-zoom SIN entrar al arena de
              // gestos (no bloquea el scroll de 1 dedo ni la rueda).
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                // UN único scroll vertical: etiquetas de hora + timeline
                // comparten el mismo scroll position.
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: SizedBox(
                    height: canvasHeight,
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Etiquetas de hora ─────────────────
                        SizedBox(
                          width: 48,
                          child: _DayTimeLabels(
                            startHour: startHour,
                            totalHours: totalHours,
                            heightPerHour: _heightPerHour,
                          ),
                        ),
                        // ── Timeline de eventos ──────────────
                        Expanded(
                          child: _DayTimelineBody(
                            day: widget.selectedDay,
                            layouts: layouts,
                            startHour: startHour,
                            totalHours: totalHours,
                            heightPerHour: _heightPerHour,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
  });

  final DateTime day;
  final int eventCount;
  final VoidCallback onBack;

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
            icon: Icon(Icons.chevron_left, color: textColor),
            onPressed: onBack,
            tooltip: 'Volver a la semana',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Etiquetas de hora para el día
// ─────────────────────────────────────────────
class _DayTimeLabels extends StatelessWidget {
  const _DayTimeLabels({
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
// Cuerpo del timeline del día
// ─────────────────────────────────────────────
class _DayTimelineBody extends StatelessWidget {
  const _DayTimelineBody({
    required this.day,
    required this.layouts,
    required this.startHour,
    required this.totalHours,
    required this.heightPerHour,
  });

  final DateTime day;
  final List<WeekTimelineSlot> layouts;
  final int startHour;
  final int totalHours;
  final double heightPerHour;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.scaffoldBg,
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

          // Indicador de "ahora"
          _NowIndicator(
            startHour: startHour,
            endHour: totalHours,
            day: day,
            heightPerHour: heightPerHour,
          ),

          // Eventos (posición absoluta, recortados para que NUNCA se
          // solapen ni desborden sobre la columna vecina)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                return ClipRect(
                  child: Stack(
                    children: layouts.map((slot) {
                      final event = slot.event;
                      final startMin = DateFormatter.minutesFromMidnight(
                        event.startTime,
                      );
                      final endMin = DateFormatter.minutesFromMidnight(
                        event.endTime,
                      );
                      final top =
                          (startMin - startHour * 60) * heightPerHour / 60;
                      final height = (endMin - startMin) * heightPerHour / 60;
                      final colWidth = totalWidth / slot.totalColumns;

                      return Positioned(
                        top: top,
                        left: colWidth * slot.column,
                        width: colWidth,
                        height: height,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: _DayEventTile(
                            event: event,
                            onTap: () => EventPreviewSheet.show(context, event),
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
    required this.day,
    required this.heightPerHour,
  });

  final int startHour;
  final int endHour;
  final DateTime day;
  final double heightPerHour;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (now.year != day.year || now.month != day.month || now.day != day.day) {
      return const SizedBox.shrink();
    }

    final minutes = DateFormatter.minutesFromMidnight(now);
    final timelineStart = startHour * 60;
    final timelineEnd = endHour * 60;

    if (minutes < timelineStart || minutes > timelineEnd) {
      return const SizedBox.shrink();
    }

    final top = (minutes - timelineStart) * heightPerHour / 60;

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
          Expanded(child: Container(height: 1.5, color: Colors.red)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tarjeta compacta de evento del día
// ─────────────────────────────────────────────
/// Bloque de evento de la vista de día.
///
/// Muestra título + franja horaria. Siempre se recorta al alto disponible y
/// se ajusta con [FittedBox] en columnas estrechas, de modo que los eventos
/// simultáneos quedan lado a lado y nunca se solapan ni desbordan.
class _DayEventTile extends StatelessWidget {
  const _DayEventTile({required this.event, this.onTap});

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

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          border: Border.all(color: _color.withValues(alpha: 0.65), width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Center(
            // Escala el contenido si no cabe: NUNCA genera overflow.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Franja de acento lateral
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormatter.timeRange(
                            event.startTime,
                            event.endTime,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
