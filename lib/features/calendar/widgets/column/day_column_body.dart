import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';
import '../event_preview_sheet.dart';
import 'timeline_indicators.dart';
import 'timeline_scale.dart';

String _hhmmAtMinute(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

class DayColumnBody extends StatelessWidget {
  const DayColumnBody({
    super.key,
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
  final TimelineScale scale;
  final VoidCallback onTap;
  final bool showNowLine;

  static const double _minSingleCardHeight = 70.0;
  static const double _maxSingleCardHeight = 110.0;

  @override
  Widget build(BuildContext context) {
    final dayEvents = <_EventWithRange>[];
    for (final e in events) {
      final range = DateFormatter.clampRangeToDayMinutes(
        e.startTime,
        e.endTime,
        day,
      );
      if (range != null) {
        dayEvents.add(_EventWithRange(e, range.$1, range.$2));
      }
    }
    dayEvents.sort((a, b) => a.startMin.compareTo(b.startMin));

    final clusters = <_EventCluster>[];
    for (final item in dayEvents) {
      if (clusters.isEmpty) {
        clusters.add(_EventCluster(item.startMin, item.endMin, [item]));
      } else {
        final last = clusters.last;
        if (item.startMin < last.endMin) {
          last.endMin = math.max(last.endMin, item.endMin);
          last.events.add(item);
        } else {
          clusters.add(_EventCluster(item.startMin, item.endMin, [item]));
        }
      }
    }
    for (final cluster in clusters) {
      final laneEnds = <int>[];
      for (final event in cluster.events) {
        final availableLane = laneEnds.indexWhere(
          (laneEnd) => laneEnd <= event.startMin,
        );
        if (availableLane == -1) {
          event.laneIndex = laneEnds.length;
          laneEnds.add(event.endMin);
        } else {
          event.laneIndex = availableLane;
          laneEnds[availableLane] = event.endMin;
        }
      }
      for (final event in cluster.events) {
        event.laneCount = laneEnds.length;
      }
    }

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

            if (showNowLine) NowIndicator(day: day, scale: scale),

            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final blocks = <Widget>[];

                  for (
                    var clusterIndex = 0;
                    clusterIndex < clusters.length;
                    clusterIndex++
                  ) {
                    final cluster = clusters[clusterIndex];
                    for (final eventRange in cluster.events) {
                      final top = scale.yForMinutes(eventRange.startMin);
                      final bottom = scale.yForMinutes(eventRange.endMin);
                      final calculatedHeight = bottom - top;
                      final minHeight = eventRange.laneCount > 1
                          ? 46.0 * scale.zoom
                          : _minSingleCardHeight * scale.zoom;
                      final desiredHeight = calculatedHeight.clamp(
                        minHeight,
                        _maxSingleCardHeight * scale.zoom,
                      );
                      final nextInLane = cluster.events
                          .where(
                            (other) =>
                                other.laneIndex == eventRange.laneIndex &&
                                other.startMin >= eventRange.endMin,
                          )
                          .map((other) => other.startMin)
                          .fold<int?>(null, (next, start) {
                            if (next == null || start < next) return start;
                            return next;
                          });
                      final nextClusterStart =
                          clusterIndex + 1 < clusters.length
                          ? clusters[clusterIndex + 1].startMin
                          : null;
                      final nextStart = nextInLane == null
                          ? nextClusterStart
                          : nextClusterStart == null
                          ? nextInLane
                          : math.min(nextInLane, nextClusterStart);
                      final availableBeforeNext = nextStart == null
                          ? double.infinity
                          : scale.yForMinutes(nextStart) - top - 4 * scale.zoom;
                      final height = math.min(
                        desiredHeight,
                        availableBeforeNext,
                      );
                      final laneWidth =
                          constraints.maxWidth / eventRange.laneCount;

                      blocks.add(
                        Positioned(
                          top: top + 2 * scale.zoom,
                          left:
                              laneWidth * eventRange.laneIndex + 2 * scale.zoom,
                          width: math
                              .max(1, laneWidth - 4 * scale.zoom)
                              .toDouble(),
                          height: math
                              .max(1, height - 2 * scale.zoom)
                              .toDouble(),
                          child: _EventClusterCard(
                            eventRange: eventRange,
                            zoom: scale.zoom,
                          ),
                        ),
                      );
                    }
                  }

                  return ClipRect(child: Stack(children: blocks));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventWithRange {
  _EventWithRange(this.event, this.startMin, this.endMin);
  final EventModel event;
  final int startMin;
  final int endMin;
  int laneIndex = 0;
  int laneCount = 1;
}

class _EventCluster {
  _EventCluster(this.startMin, this.endMin, this.events);
  int startMin;
  int endMin;
  final List<_EventWithRange> events;
}

class _EventClusterCard extends StatelessWidget {
  const _EventClusterCard({required this.eventRange, required this.zoom});

  final _EventWithRange eventRange;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final eventColor =
        AppColors.calendarEventColors[eventRange.laneIndex %
            AppColors.calendarEventColors.length];
    return Container(
      width: double.infinity,
      height: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          eventColor.withValues(alpha: 0.22),
          context.cardBg,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall * zoom),
        border: Border.all(
          color: eventColor.withValues(alpha: 0.9),
          width: 1.5 * zoom,
        ),
        boxShadow: [
          BoxShadow(
            color: eventColor.withValues(alpha: 0.16),
            blurRadius: 4 * zoom,
            offset: Offset(0, zoom),
          ),
        ],
      ),
      child: _InnerEventRow(
        eventRange: eventRange,
        isSingle: true,
        eventColor: eventColor,
        zoom: zoom,
      ),
    );
  }
}

class _InnerEventRow extends StatelessWidget {
  const _InnerEventRow({
    required this.eventRange,
    required this.isSingle,
    required this.eventColor,
    required this.zoom,
  });

  final _EventWithRange eventRange;
  final bool isSingle;
  final Color eventColor;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final event = eventRange.event;
    final color = eventColor;
    final price = event.startingPrice;
    final priceLabel = price != null ? '\$${price.toInt()} Bs' : 'Free';
    final timeRange =
        '${_hhmmAtMinute(eventRange.startMin)} - ${_hhmmAtMinute(eventRange.endMin)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 58 * zoom ||
            constraints.maxWidth < 110 * zoom;
        return InkWell(
          onTap: () => EventPreviewSheet.show(context, event),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (compact ? 5 : 7) * zoom,
              vertical: (compact ? 2 : 5) * zoom,
            ),
            child: compact
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeRange,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 8 * zoom,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 9 * zoom,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5 * zoom,
                              vertical: 2 * zoom,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusSmall * zoom,
                              ),
                            ),
                            child: Text(
                              timeRange,
                              style: TextStyle(
                                color: context.scaffoldBg,
                                fontSize: 9 * zoom,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          SizedBox(width: 5 * zoom),
                          if (event.organizationName.isNotEmpty)
                            Expanded(
                              child: Text(
                                event.organizationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: color.withValues(alpha: 0.95),
                                  fontSize: 10 * zoom,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        event.title,
                        maxLines: isSingle ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 11 * zoom,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      if (isSingle && (event.description?.isNotEmpty ?? false))
                        Text(
                          event.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 9 * zoom,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            priceLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 10 * zoom,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 12 * zoom,
                            color: color,
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
