import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/event_model.dart';
import 'column/day_column_body.dart';
import 'column/timeline_indicators.dart';
import 'column/timeline_labels.dart';
import 'column/timeline_scale.dart';
import 'week_day_header.dart';

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

const double _timelineLabelWidth = 44.0;
const double _minDayColumnWidth = 64.0;

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
  final bool autoScrollToEarliest;
  final bool showNowLine;
  final bool showDayStrip;
  final int startHour;
  final int endHour;

  @override
  ConsumerState<WeekColumns> createState() => _WeekColumnsState();
}

class _WeekColumnsState extends ConsumerState<WeekColumns> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _hStripScrollController = ScrollController();
  bool _syncingHorizontal = false;
  bool _atRightEdge = true;

  double _zoom = 1;
  static const double _minZoom = 1;
  static const double _maxZoom = 4;

  TimelineScale? _activeScale;

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

    final target = (_zoom * spacing / previous).clamp(_minZoom, _maxZoom);

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
    _hScrollController.addListener(_syncHorizontal);
    _hStripScrollController.addListener(_syncHorizontal);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRightEdge());
    if (widget.autoScrollToEarliest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEarliest());
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && widget.autoScrollToEarliest) _scrollToEarliest();
      });
    }
  }

  void _refreshRightEdge() {
    if (!mounted || !_hScrollController.hasClients) return;
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
    if ((_hScrollController.offset - _hStripScrollController.offset).abs() > 0.1) {
      _hStripScrollController.jumpTo(_hScrollController.offset);
    } else if ((_hStripScrollController.offset - _hScrollController.offset).abs() > 0.1) {
      _hScrollController.jumpTo(_hStripScrollController.offset);
    }
    _syncingHorizontal = false;

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
    final dayChanged = !_isSameDay(oldWidget.weekDays.first, widget.weekDays.first);
    if (dayChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEarliest());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRightEdge());
  }

  void _scrollToEarliest() {
    if (!_scrollController.hasClients) return;
    final day = widget.weekDays.first;

    final dayEvents = widget.events
        .where((e) => DateFormatter.rangeCoversDay(e.startTime, e.endTime, day))
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
    final startMin = range?.$1 ?? DateFormatter.minutesFromMidnight(first.startTime);

    final scale = _activeScale;
    double target = 0;
    if (scale != null) {
      final start = math.max(startMin - 60, scale.startHour * 60);
      target = scale.yForMinutes(start);
    }
    _scrollController.jumpTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final dayEvents = <int, List<EventModel>>{};
    for (final day in widget.weekDays) {
      dayEvents[day.weekday] = widget.events
          .where((e) => DateFormatter.rangeCoversDay(e.startTime, e.endTime, day))
          .toList();
    }

    final (int startHour, int endHour) = _effectiveHourRange(
      widget.weekDays,
      widget.events,
      widget.startHour,
      widget.endHour,
    );

    final activeHours = <int>{};
    for (final day in widget.weekDays) {
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

    final eventDays = widget.weekDays
        .where((day) => (dayEvents[day.weekday] ?? const []).isNotEmpty)
        .toList();
    final daysToRender = eventDays.isEmpty
        ? widget.weekDays
        : List<DateTime>.unmodifiable(eventDays);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final gridWidth = availableWidth - _timelineLabelWidth;
        final colWidth = math.max(
          gridWidth / daysToRender.length,
          _minDayColumnWidth,
        );
        final totalDaysWidth = colWidth * daysToRender.length;
        final overflows = totalDaysWidth > gridWidth;
        final showSlideHint = overflows && !_atRightEdge;

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showDayStrip && widget.weekDays.length > 1)
                  SingleChildScrollView(
                    controller: _hStripScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const SizedBox(width: _timelineLabelWidth),
                        ...daysToRender.map(
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
                  ),
                Expanded(
                  child: Listener(
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerCancel,
                    child: LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final scale = TimelineScale(
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
                                SizedBox(
                                  width: _timelineLabelWidth,
                                  child: TimelineLabels(scale: scale),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    controller: _hScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: totalDaysWidth,
                                      child: Row(
                                        children: daysToRender.map((day) {
                                          return SizedBox(
                                            width: colWidth,
                                            child: DayColumnBody(
                                              day: day,
                                              isSelected: _isSameDay(day, widget.selectedDay),
                                              events: dayEvents[day.weekday] ?? const [],
                                              scale: scale,
                                              showNowLine: widget.showNowLine,
                                              onTap: () => widget.onDaySelected(day),
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
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: RightSlideHint(visible: showSlideHint),
            ),
          ],
        );
      },
    );
  }
}