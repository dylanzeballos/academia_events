import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';
import '../event_preview_sheet.dart';
import 'timeline_indicators.dart';
import 'timeline_scale.dart';

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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

  static const double _minSingleCardHeight = 65.0;

  @override
  Widget build(BuildContext context) {
    // 1. Filtrar eventos del día y ordenar por hora de inicio
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

    // 2. Agrupar eventos que chocan/solapan en clústeres
    final clusters = <_EventCluster>[];
    for (final item in dayEvents) {
      if (clusters.isEmpty) {
        clusters.add(_EventCluster(item.startMin, item.endMin, [item.event]));
      } else {
        final last = clusters.last;
        // Si el evento inicia antes o justo cuando termina el grupo previo -> se fusiona
        if (item.startMin < last.endMin) {
          last.endMin = math.max(last.endMin, item.endMin);
          last.events.add(item.event);
        } else {
          clusters.add(_EventCluster(item.startMin, item.endMin, [item.event]));
        }
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
            // Líneas divisorias de horas
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

            // Renderizado de las tarjetas agrupadas
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final blocks = <Widget>[];

                  for (final cluster in clusters) {
                    final top = scale.yForMinutes(cluster.startMin);
                    final bottomByTime = scale.yForMinutes(cluster.endMin);
                    final minHeight = _minSingleCardHeight * cluster.events.length;
                    final height = math.max(bottomByTime - top, minHeight);

                    blocks.add(
                      Positioned(
                        top: top,
                        left: 2,
                        right: 2,
                        height: height,
                        child: _MergedClusterCard(
                          events: cluster.events,
                          totalDurationHeight: height,
                        ),
                      ),
                    );
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
}

class _EventCluster {
  _EventCluster(this.startMin, this.endMin, this.events);
  int startMin;
  int endMin;
  final List<EventModel> events;
}

/// Contenedor unificado: abarca desde el primer inicio hasta el último fin
class _MergedClusterCard extends StatelessWidget {
  const _MergedClusterCard({
    required this.events,
    required this.totalDurationHeight,
  });

  final List<EventModel> events;
  final double totalDurationHeight;

  @override
  Widget build(BuildContext context) {
    final firstEvent = events.first;
    final primaryColor = AppColors.colorForOrganization(firstEvent.organizationId);

    return Container(
      width: double.infinity,
      height: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A24).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.65),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < events.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.8,
                color: primaryColor.withValues(alpha: 0.25),
              ),
            Expanded(
              child: _InnerEventRow(
                event: events[i],
                isSingle: events.length == 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila interior con el estilo visual original
class _InnerEventRow extends StatelessWidget {
  const _InnerEventRow({
    required this.event,
    required this.isSingle,
  });

  final EventModel event;
  final bool isSingle;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.colorForOrganization(event.organizationId);
    final price = event.startingPrice;
    final priceLabel = price != null ? '\$${price.toInt()} USD' : 'Free';

    return InkWell(
      onTap: () => EventPreviewSheet.show(context, event),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Fila superior: Hora + Organización
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _hhmm(event.startTime),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                if (event.organizationName.isNotEmpty)
                  Expanded(
                    child: Text(
                      event.organizationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.95),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),

            // Título
            Text(
              event.title,
              maxLines: isSingle ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),

            // Subtítulo / Descripción
            if (isSingle && (event.description?.isNotEmpty ?? false))
              Text(
                event.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFD37B58),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),

            // Precio + Flecha
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  priceLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 12,
                  color: color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}