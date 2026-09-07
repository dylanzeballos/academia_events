import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event_model.dart';
import 'event_preview_sheet.dart';
import 'week_day_header.dart';

/// Rango horario a mostrar. En vista de semana (7 dias) se recorta al tramo
/// donde hay eventos (con margen de 1 h) para no dejar horas vacias; en vista
/// de dia se respeta el rango configurado (0-24 por defecto).
///
/// Usa los tramos YA recortados por día ([DateFormatter.clampRangeToDayMinutes])
/// para que un evento multi-día (sáb 20:00 → dom 12:00) compute bien la parte
/// de cada día (sáb [20:00–24:00] → min 20 max 24; dom [00:00–12:00] → min 0
/// max 12) y el timeline cubra ambas partes.
(int, int) _effectiveHourRange(
  List<DateTime> weekDays,
  List<EventModel> events,
  int requestedStart,
  int requestedEnd,
) {
  if (weekDays.length == 1) {
    return (requestedStart, requestedEnd);
  }
  var minHour = 24;
  var maxHour = 0;
  var hasEvents = false;
  for (final event in events) {
    for (final day in weekDays) {
      final range = DateFormatter.clampRangeToDayMinutes(
        event.startTime,
        event.endTime,
        day,
      );
      if (range == null) continue;
      hasEvents = true;
      final (startMin, endMin) = range;
      final startHour = startMin ~/ 60;
      // endMin ya es exclusivo (1440 = fin de día); redondea hacia arriba para
      // que el tramo que toca la hora quede dentro del timeline.
      final endHour = (endMin / 60).ceil();
      if (startHour < minHour) minHour = startHour;
      if (endHour > maxHour) maxHour = endHour;
    }
  }
  if (!hasEvents) {
    return (requestedStart, requestedEnd);
  }
  var start = (minHour - 1).clamp(0, 23);
  var end = (maxHour + 1).clamp(1, 24);
  if (end <= start) {
    end = start + 1;
  }
  return (start.toInt(), end.toInt());
}

/// Ancho de la columna de etiquetas de hora. La cabecera de dias usa el mismo
/// offset para quedar alineada con la grilla.
const double _timelineLabelWidth = 44.0;

/// Ancho mínimo de cada columna de día. Se ocultan las columnas sin eventos
/// (cuando la semana tiene al menos uno), así en general los días con eventos
/// caben sin scroll horizontal. El nombre rotado solo necesita ~16 px de
/// ancho, por eso se puede ser angosto.
const double _minDayColumnWidth = 64.0;

/// Vista de semana compacta (los 7 días visibles a la vez, estilo Google
/// Calendar con columnas). Cada día es una columna; los eventos se posicionan
/// por hora dentro de un canvas de alto fijo.
///
/// La escala del timeline se recalcula según el alto disponible para que la
/// semana entre ENTERA sin scroll vertical: las horas con eventos reciben más
/// alto y las horas vacías se comprimen (ver [_TimelineScale]). Etiquetas de
/// hora y eventos comparten la misma escala, así siempre cuadran entre sí.
///
/// Soporta:
/// - Escala ajustada a pantalla por defecto (sin scroll vertical).
/// - Pinch-to-zoom para ampliar por encima del ajuste (ahí reaparece el
///   scroll vertical, solo si el usuario hace zoom-in).
class WeekColumns extends ConsumerStatefulWidget {
  const WeekColumns({
    super.key,
    required this.weekDays,
    required this.events,
    required this.selectedDay,
    required this.heightPerHour,
    required this.onDaySelected,
    this.autoScrollToEarliest = false,
    this.showNowLine = false,
    this.showDayStrip = false,
    this.startHour = 0,
    this.endHour = 24,
  });

  final List<DateTime> weekDays;
  final List<EventModel> events;
  final DateTime selectedDay;
  final double heightPerHour;
  final ValueChanged<DateTime> onDaySelected;

  /// Si es `true`, al montar o al cambiar el primer día de [weekDays], la
  /// vista se desplaza automáticamente al primer evento del día (margen de
  /// 1 h) para que los eventos nocturnos (19:00, etc.) no queden fuera de
  /// pantalla. La vista de semana lo deja en `false`.
  final bool autoScrollToEarliest;

  /// Muestra la línea roja de "ahora" en las columnas (solo vista de día).
  final bool showNowLine;

  /// Muestra la fila superior de dias (solo vista de semana) alineada con la
  /// grilla. La vista de dia la deja en false.
  final bool showDayStrip;

  /// Hora inicial del timeline. Por defecto 0 (toda las 24 h).
  final int startHour;

  /// Hora final (exclusiva) del timeline. Por defecto 24 (máximo).
  final int endHour;

  @override
  ConsumerState<WeekColumns> createState() => _WeekColumnsState();
}

class _WeekColumnsState extends ConsumerState<WeekColumns> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _hStripScrollController = ScrollController();
  bool _syncingHorizontal = false;

  /// Si ya se llegó al final del scroll horizontal (para ocultar el indicador
  /// de "desliza" que avisa que hay más días a la derecha).
  bool _atRightEdge = true;

  /// Multiplicador de zoom sobre la escala ajustada a pantalla. En la
  /// posición base (1x) la semana entra completa sin scroll; hacer zoom-in
  /// amplía por encima y habilita el scroll vertical.
  double _zoom = 1;
  static const double _minZoom = 1;
  static const double _maxZoom = 4;

  /// Escala calculada en el último layout (usada por [_scrollToEarliest]).
  _TimelineScale? _activeScale;

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

    final target = (_zoom * spacing / previous).clamp(
      _minZoom,
      _maxZoom,
    );

    if (target != _zoom) {
      setState(() => _zoom = target);
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
    _hScrollController.dispose();
    _hStripScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Mantiene la cabecera de días y la grilla alineadas mientras se desplaza
    // horizontalmente cuando los días no caben en pantalla.
    _hScrollController.addListener(_syncHorizontal);
    _hStripScrollController.addListener(_syncHorizontal);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRightEdge());
    if (widget.autoScrollToEarliest) {
      // Re-aplica tras un retraso: durante la transición de ruta la primera
      // pasada puede calcular un maxScrollExtent aún no definitivo.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEarliest());
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && widget.autoScrollToEarliest) _scrollToEarliest();
      });
    }
  }

  void _refreshRightEdge() {
    if (!mounted) return;
    if (!_hScrollController.hasClients) return;
    final maxExtent = _hScrollController.position.maxScrollExtent;
    final atRight = _hScrollController.offset >= maxExtent - 1;
    if (atRight != _atRightEdge) {
      setState(() => _atRightEdge = atRight);
    }
  }

  void _syncHorizontal() {
    if (_syncingHorizontal) return;
    if (!_hScrollController.hasClients || !_hStripScrollController.hasClients) {
      return;
    }
    _syncingHorizontal = true;
    if ((_hScrollController.offset - _hStripScrollController.offset).abs() >
        0.1) {
      _hStripScrollController.jumpTo(_hScrollController.offset);
    } else if ((_hStripScrollController.offset - _hScrollController.offset)
            .abs() >
        0.1) {
      _hScrollController.jumpTo(_hStripScrollController.offset);
    }
    _syncingHorizontal = false;

    // Ocultar el indicador de deslizar cuando se llega al final (o cuando no
    // hay scroll porque no sobra contenido).
    final maxExtent = _hScrollController.position.maxScrollExtent;
    final atRight = _hScrollController.offset >= maxExtent - 1;
    if (atRight != _atRightEdge) {
      setState(() => _atRightEdge = atRight);
    }
  }

  @override
  void didUpdateWidget(covariant WeekColumns oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.autoScrollToEarliest) return;
    if (oldWidget.weekDays.isEmpty || widget.weekDays.isEmpty) return;
    final dayChanged = !_isSameDay(
      oldWidget.weekDays.first,
      widget.weekDays.first,
    );
    if (dayChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEarliest());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRightEdge());
  }

  /// Posiciona la vista en el inicio del primer evento del día (con 1 h de
  /// margen). Si no hay eventos, vuelve a la medianoche.
  void _scrollToEarliest() {
    if (!_scrollController.hasClients) return;
    final day = widget.weekDays.first;

    final dayEvents =
        widget.events
            .where(
              (e) => DateFormatter.rangeCoversDay(e.startTime, e.endTime, day),
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (dayEvents.isEmpty) {
      _scrollController.jumpTo(0);
      return;
    }

    final first = dayEvents.first;
    final range = DateFormatter.clampRangeToDayMinutes(
      first.startTime,
      first.endTime,
      day,
    );
    final startMin =
        range?.$1 ?? DateFormatter.minutesFromMidnight(first.startTime);

    final scale = _activeScale;
    double target = 0;
    if (scale != null) {
      // Margen de 1 h antes del primer evento (sin salir del rango del eje).
      final start = math.max(startMin - 60, scale.startHour * 60);
      target = scale.yForMinutes(start);
    }
    _scrollController.jumpTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  List<EventModel> get events => widget.events;
  DateTime get selectedDay => widget.selectedDay;
  List<DateTime> get weekDays => widget.weekDays;
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
            (e) => DateFormatter.rangeCoversDay(e.startTime, e.endTime, day),
          )
          .toList();
    }

    // Rango de horas del timeline: semana y día usan 0-24 por defecto.
    final (int startHour, int endHour) = _effectiveHourRange(
      weekDays,
      events,
      widget.startHour,
      widget.endHour,
    );

    // Horas con actividad en cualquier columna: la escala da más alto a estas
    // horas y comprime las vacías.
    final activeHours = <int>{};
    for (final day in weekDays) {
      for (final event in dayEvents[day.weekday] ?? const <EventModel>[]) {
        final range = DateFormatter.clampRangeToDayMinutes(
          event.startTime,
          event.endTime,
          day,
        );
        if (range == null) continue;
        final (startMin, endMin) = range;
        for (var h = startMin ~/ 60; h * 60 < endMin; h++) {
          activeHours.add(h);
        }
      }
    }

    // Solo se muestran las columnas de días CON eventos para aprovechar el
    // espacio y evitar scroll horizontal cuando la semana no está llena. Si la
    // semana no tiene ningún evento, se muestran todos los días tal cual.
    final eventDays = weekDays
        .where((day) => (dayEvents[day.weekday] ?? const []).isNotEmpty)
        .toList();
    final daysToRender = eventDays.isEmpty
        ? weekDays
        : List<DateTime>.unmodifiable(eventDays);

    // Ancho de la columna de etiquetas de hora (más estrecha que en día)
    const labelWidth = _timelineLabelWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final timeColumnWidth = labelWidth;
        final gridWidth = availableWidth - timeColumnWidth;
        // Columna nunca por debajo de [_minDayColumnWidth]: si los 7 días no
        // caben, la grilla y la cabecera se desplazan en horizontal (shared
        // [_hScrollController]) para que el nombre del evento se lea bien.
        final colWidth = math.max(
          gridWidth / daysToRender.length,
          _minDayColumnWidth,
        );
        final totalDaysWidth = colWidth * daysToRender.length;

        // Aviso de "deslizar" solo cuando sobran columnas y aún no se llegó al
        // final del scroll horizontal.
        final overflows = totalDaysWidth > gridWidth;
        final showSlideHint = overflows && !_atRightEdge;

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showDayStrip && weekDays.length > 1)
                  _buildDayStrip(daysToRender, colWidth),
                Expanded(
                  // Listener: captura el pinch-to-zoom SIN entrar al arena de
                  // gestos (no bloquea el scroll de 1 dedo ni la rueda).
                  child: Listener(
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerCancel,
                    // LayoutBuilder interior: mide SOLO el alto disponible de
                    // la grilla (descontada la cabecera de días) y ajusta la
                    // escala de tiempo para que la semana entre completa.
                    child: LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final scale = _TimelineScale(
                          startHour: startHour,
                          endHour: endHour,
                          activeHours: activeHours,
                          availableHeight: innerConstraints.maxHeight,
                          activePxPerHour: widget.heightPerHour,
                          zoom: _zoom,
                        );
                        _activeScale = scale;

                        return SingleChildScrollView(
                          controller: _scrollController,
                          child: SizedBox(
                            height: scale.totalHeight,
                            width: availableWidth,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Etiquetas de hora (escala ajustada) ──
                                SizedBox(
                                  width: timeColumnWidth,
                                  child: _TimeLabels(scale: scale),
                                ),
                                // ── Columnas de días (scroll horizontal) ──
                                Expanded(
                                  child: SingleChildScrollView(
                                    controller: _hScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: totalDaysWidth,
                                      child: Row(
                                        children: daysToRender.map((day) {
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
                                                  dayEvents[day.weekday] ??
                                                  const [],
                                              scale: scale,
                                              showNowLine: widget.showNowLine,
                                              onTap: () =>
                                                  _enterDayView(day),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            // Indicador en el borde derecho: avisa que hay más días a la
            // derecha deslizando. Se oculta al llegar al final.
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: _RightSlideHint(visible: showSlideHint),
            ),
          ],
        );
      },
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Cabecera de dias dentro de [WeekColumns]: comparte el mismo offset de
  /// etiquetas de hora y el mismo scroll horizontal que la grilla, asi los
  /// chips quedan exactamente alineados con sus columnas.
  Widget _buildDayStrip(List<DateTime> visibleDays, double colWidth) {
    return SingleChildScrollView(
      controller: _hStripScrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: _timelineLabelWidth),
          ...visibleDays.map(
            (day) => SizedBox(
              width: colWidth,
              child: WeekDayHeader(
                day: day,
                isSelected: _isSameDay(day, widget.selectedDay),
                onTap: () => widget.onDaySelected(day),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Escala de tiempo adaptativa
// ─────────────────────────────────────────────
/// Escala de tiempo que reparte el alto disponible de la pantalla entre las
/// horas de forma proporcional a su actividad, para que la semana entre
/// completa SIN scroll vertical (zoom = 1).
///
/// - Horas con eventos en cualquier columna ([activeHours]) reciben más
///   píxeles por hora; las horas vacías, el mínimo.
/// - Se parte de un "piso" (mínimo legible) y sobra el resto según el peso de
///   cada hora, llenando exactamente [availableHeight].
/// - Si ni los pisos caben (semana muy llena, p. ej. eventos de 00 a 14 más
///   otros por la noche), se comprime TODO uniformemente por debajo del piso.
/// - [zoom] escala por encima del ajuste (aparece scroll vertical únicamente
///   cuando el usuario hace zoom-in).
///
/// [topAt], [pxPerHourAt] y [yFor*] devuelven las posiciones según esta misma
/// escala, así las etiquetas de hora del costado y los eventos siempre cuadran
/// entre sí ("de acuerdo al horario del costado").
class _TimelineScale {
  _TimelineScale({
    required this.startHour,
    required this.endHour,
    required Set<int> activeHours,
    required double availableHeight,
    required double activePxPerHour,
    this.zoom = 1,
  }) {
    final n = endHour - startHour;
    if (n <= 0) {
      _perHour = const [];
      _top = const [0];
      return;
    }

    final base = <double>[];
    final floor = <double>[];
    for (var h = startHour; h < endHour; h++) {
      final active = activeHours.contains(h);
      final desired = active ? activePxPerHour : _inactiveBasePx;
      final f = active ? _activeFloorPx : _inactiveFloorPx;
      base.add(math.max(desired, f));
      floor.add(f);
    }

    final totalFloor = floor.fold(0.0, (sum, f) => sum + f);
    final peak = base.fold(0.0, (sum, b) => sum + b);
    final extraWeight = peak - totalFloor;

    double pxFor(int i) {
      if (availableHeight >= totalFloor) {
        if (extraWeight <= 0) return base[i];
        final leftover = availableHeight - totalFloor;
        return floor[i] + leftover * (base[i] - floor[i]) / extraWeight;
      }
      // Los pisos no alcanzan: se encoge todo uniformemente.
      return floor[i] * availableHeight / totalFloor;
    }

    _perHour = List<double>.generate(
      n,
      (i) => pxFor(i) * zoom,
      growable: false,
    );

    _top = List<double>.generate(n + 1, (i) {
      var y = 0.0;
      for (var j = 0; j < i; j++) {
        y += _perHour[j];
      }
      return y;
    });
  }

  final int startHour;
  final int endHour;
  final double zoom;

  /// Píxeles por hora de las horas vacías (las activas usan `activePxPerHour`).
  static const double _inactiveBasePx = 13;

  /// Mínimos legibles: aunque la semana esté llena, esto es lo que intenta
  /// mantener cada tipo de hora antes de comprimir por debajo.
  static const double _activeFloorPx = 24;
  static const double _inactiveFloorPx = 9;

  late final List<double> _perHour;
  late final List<double> _top;

  int get totalHours => endHour - startHour;
  double get totalHeight => _top.isEmpty ? 0 : _top.last;

  /// Píxeles acumulados desde el inicio del eje hasta la hora indicada (una
  /// frontera entre horas, por ejemplo 06:00).
  double topAt(int hour) => _top[hour - startHour];

  double pxPerHourAt(int hour) => _perHour[hour - startHour];

  /// Posición de una hora fraccionaria (p. ej. 6.5 = 06:30) dentro del eje.
  double yForHourFraction(double hour) {
    final local = hour - startHour;
    if (local <= 0) return 0;
    if (local >= totalHours) return totalHeight;
    final idx = local.floor();
    final frac = local - idx;
    return _top[idx] + _perHour[idx] * frac;
  }

  double yForMinutes(int minutes) => yForHourFraction(minutes / 60);
}

// ─────────────────────────────────────────────
// Etiquetas de hora de la columna izquierda
// ─────────────────────────────────────────────
/// Etiquetas "HH:00" ubicadas en la posición REAL de cada hora según la escala
/// adaptativa. En tramos muy comprimidos se saltan algunas etiquetas para que
/// el texto no se pise (jamás se falsifica la posición: siguen la escala).
class _TimeLabels extends StatelessWidget {
  const _TimeLabels({required this.scale});

  final _TimelineScale scale;

  /// Separación vertical mínima entre etiquetas mostradas (texto de 10 px).
  static const double _minLabelGap = 14;

  @override
  Widget build(BuildContext context) {
    if (scale.totalHours <= 0) return const SizedBox.shrink();

    final children = <Widget>[];
    final totalHours = scale.totalHours;
    for (var i = 0; i <= totalHours; i++) {
      final hour = scale.startHour + i;
      final isBoundary = i == 0 || i == totalHours;
      // Paso para saltar etiquetas cuando el tramo está comprimido.
      final segPx = i < totalHours
          ? scale.pxPerHourAt(hour)
          : scale.pxPerHourAt(hour - 1);
      final step = segPx >= _minLabelGap
          ? 1
          : (segPx >= _minLabelGap / 2 ? 2 : 3);
      if (!isBoundary && i % step != 0) continue;

      final top = scale.topAt(hour);
      // La última etiqueta se ancla por abajo para no salirse del eje.
      final y = isBoundary ? top - 11 : top + 1;
      children.add(
        Positioned(
          top: y,
          left: 0,
          right: 4,
          child: Text(
            '${hour.toString().padLeft(2, '0')}:00',
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ),
      );
    }

    return SizedBox(
      height: scale.totalHeight,
      child: Stack(children: children),
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
    required this.scale,
    required this.onTap,
    this.showNowLine = false,
  });

  final DateTime day;
  final bool isSelected;
  final List<EventModel> events;
  final _TimelineScale scale;
  final VoidCallback onTap;
  final bool showNowLine;

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
            // Líneas de hora (en su posición real según la escala)
            ...List.generate(scale.totalHours + 1, (i) {
              return Positioned(
                top: scale.topAt(scale.startHour + i),
                left: 0,
                right: 0,
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: context.divider.withValues(alpha: 0.4),
                ),
              );
            }),
            // Línea roja de "ahora" (solo vista de día)
            if (showNowLine)
              _NowIndicator(day: day, scale: scale),
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
                        final range = DateFormatter.clampRangeToDayMinutes(
                          event.startTime,
                          event.endTime,
                          day,
                        );
                        if (range == null) {
                          return const SizedBox.shrink();
                        }
                        final (startMin, endMin) = range;
                        final top = scale.yForMinutes(startMin);
                        final bottom = scale.yForMinutes(endMin);
                        final height = math.max(bottom - top, 1.0);
                        final itemWidth = colWidth / layout.totalColumns;

                        // Todos los eventos se dibujan como un bloque sólido que
                        // ocupa su tramo (recortado por día), con el nombre
                        // rotado 90° (de abajo hacia arriba) y letra grande.
                        // Cuando varios coinciden en la misma hora se colocan en
                        // COLUMNAS (ancho = columna / nº de eventos).

                        return Positioned(
                          top: top,
                          left: itemWidth * layout.column,
                          width: itemWidth,
                          height: height,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: _ColumnEventBlock(
                              event: event,
                              onTap: () => EventPreviewSheet.show(
                                context,
                                event,
                              ),
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

// ─────────────────────────────────────────────
// Línea roja de "hora actual" (solo vista de día)
// ─────────────────────────────────────────────
class _NowIndicator extends StatelessWidget {
  const _NowIndicator({required this.day, required this.scale});

  final DateTime day;
  final _TimelineScale scale;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (now.year != day.year || now.month != day.month || now.day != day.day) {
      return const SizedBox.shrink();
    }

    final minutes = DateFormatter.minutesFromMidnight(now);
    final timelineStart = scale.startHour * 60;
    final timelineEnd = scale.endHour * 60;

    if (minutes < timelineStart || minutes > timelineEnd) {
      return const SizedBox.shrink();
    }

    final top = scale.yForMinutes(minutes);

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
      final clusterStart = cluster.first.startTime;
      var clusterEndFinal = cluster.first.endTime;
      for (final e in cluster) {
        if (e.endTime.isAfter(clusterEndFinal)) clusterEndFinal = e.endTime;
      }

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

      for (var i = 0; i < cluster.length; i++) {
        final e = cluster[i];
        slots.add(
          WeekTimelineSlot(
            event: e,
            column: columns[e.id]!,
            totalColumns: columnEnds.length,
            clusterStart: clusterStart,
            clusterEnd: clusterEndFinal,
            clusterIndex: i,
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
    required this.clusterStart,
    required this.clusterEnd,
    required this.clusterIndex,
  });

  final EventModel event;
  final int column;
  final int totalColumns;

  /// Limites temporales del cluster al que pertenece el evento.
  final DateTime clusterStart;
  final DateTime clusterEnd;

  /// Orden del evento dentro de su cluster (por hora de inicio).
  final int clusterIndex;
}

/// Bloque de evento en la grilla semanal: un cuadrado sólido que ocupa el
/// tramo que el evento cubre en ese día (recortado por día para los multi-día),
/// con el nombre rotado 90° de abajo hacia arriba, letra grande y sin horas.
/// Cuando varios eventos coinciden en la misma hora, cada uno se dibuja en su
/// propia columna (ancho = columna / nº de eventos); si es único ocupa toda la
/// columna. El texto rotado se lee bien incluso en columnas angostas.
class _ColumnEventBlock extends StatelessWidget {
  const _ColumnEventBlock({required this.event, this.onTap});

  final EventModel event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.colorForOrganization(event.organizationId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.5 : 0.9),
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          border: Border.all(color: color.withValues(alpha: 0.9), width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
        child: Center(
          child: RotatedBox(
            // 270° de rotación → el texto se lee de abajo hacia arriba.
            quarterTurns: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Indicador "desliza para ver más días"
// ─────────────────────────────────────────────
/// Overlay fijo en el borde derecho de la grilla: un chevron con un pulso
/// suave que avisa que hay más columnas de días a la derecha. Se oculta al
/// llegar al final del scroll (o cuando no sobra contenido).
class _RightSlideHint extends StatefulWidget {
  const _RightSlideHint({required this.visible});

  final bool visible;

  @override
  State<_RightSlideHint> createState() => _RightSlideHintState();
}

class _RightSlideHintState extends State<_RightSlideHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.visible) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _RightSlideHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.visible && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.cardBg;

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Container(
          width: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                bg.withValues(alpha: 0.55),
              ],
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_controller.value);
              return Center(
                child: Transform.translate(
                  offset: Offset(3 * t, 0),
                  child: Opacity(
                    opacity: 0.35 + 0.65 * t,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: bg.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: context.textOnBg,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
