import 'package:flutter/material.dart';

import '../../../core/utils/class_presentation.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_access.dart';
import '../../../providers/dance_class_provider.dart';
import 'schedule_day_column.dart';
import 'schedule_header.dart';
import 'schedule_hours_column.dart';

/// Cuerpo de una grilla semanal: columna de horas + días con scroll
/// sincronizado. No trae header ni filtros; ocupa el alto disponible, así que
/// va dentro de un `Expanded` o como `body`.
class ScheduleGridBody extends StatefulWidget {
  const ScheduleGridBody({
    super.key,
    required this.entries,
    required this.onOpenClass,
    this.onAddClass,
    this.accessFor,
    this.showOrganization = false,
    this.genreColorMap = const {},
  });

  final List<OrgScheduleEntry> entries;
  final void Function(String classId) onOpenClass;
  final VoidCallback? onAddClass;

  /// Tipo de acceso del alumno por clase (solo en "Mis clases").
  final ClassAccess? Function(String classId)? accessFor;

  /// Muestra logo + nombre de la academia en cada tarjeta.
  final bool showOrganization;

  final Map<String, Color> genreColorMap;

  @override
  State<ScheduleGridBody> createState() => _ScheduleGridBodyState();
}

class _ScheduleGridBodyState extends State<ScheduleGridBody> {
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _hoursVerticalScroll = ScrollController();
  final ScrollController _gridVerticalScroll = ScrollController();
  bool _syncingVertical = false;

  static const double _timeColWidth = 54.0;
  static const double _minColWidth = 95.0;
  static const double _slotHeight = 92.0;
  static const double _headerHeight = 44.0;

  @override
  void initState() {
    super.initState();
    _hoursVerticalScroll.addListener(_syncFromHours);
    _gridVerticalScroll.addListener(_syncFromGrid);
  }

  void _syncFromHours() {
    if (_syncingVertical) return;
    _syncingVertical = true;
    if (_hoursVerticalScroll.hasClients && _gridVerticalScroll.hasClients) {
      if ((_hoursVerticalScroll.offset - _gridVerticalScroll.offset).abs() >
          0.5) {
        _gridVerticalScroll.jumpTo(_hoursVerticalScroll.offset);
      }
    }
    _syncingVertical = false;
  }

  void _syncFromGrid() {
    if (_syncingVertical) return;
    _syncingVertical = true;
    if (_hoursVerticalScroll.hasClients && _gridVerticalScroll.hasClients) {
      if ((_gridVerticalScroll.offset - _hoursVerticalScroll.offset).abs() >
          0.5) {
        _hoursVerticalScroll.jumpTo(_gridVerticalScroll.offset);
      }
    }
    _syncingVertical = false;
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _hoursVerticalScroll.dispose();
    _gridVerticalScroll.dispose();
    super.dispose();
  }

  int _parseHour(String timeStr) {
    try {
      final clean = timeStr.trim().split(' ')[0].split('+')[0];
      return int.parse(clean.split(':')[0]);
    } catch (_) {
      return 12;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;

    final hours =
        entries.map((e) => _parseHour(e.schedule.startTime)).toSet().toList()
          ..sort();

    final activeDays = entries.map((e) => e.schedule.dayOfWeek).toSet();
    final days = weekDays.where((day) => activeDays.contains(day.$1)).toList();

    if (hours.isEmpty || days.isEmpty) {
      return const SizedBox.shrink();
    }

    // La grilla tiene alto fijo por franja: acotamos el escalado de texto para
    // que no desborde con tipografía grande del sistema.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth - _timeColWidth;
          // Si las columnas entran, se reparten todo el ancho disponible (en
          // horizontal se ve la semana completa sin franjas vacías); si no,
          // se usa el mínimo legible y la grilla scrollea.
          final rawColWidth = availableWidth / days.length;
          final colWidth = rawColWidth >= _minColWidth
              ? rawColWidth
              : _minColWidth;
          final totalDaysWidth = colWidth * days.length;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _timeColWidth,
                child: Column(
                  children: [
                    Container(
                      height: _headerHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        border: Border(
                          right: BorderSide(color: context.divider, width: 1.2),
                          bottom: BorderSide(
                            color: context.divider,
                            width: 1.2,
                          ),
                        ),
                      ),
                      child: Text(
                        'HORA',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _hoursVerticalScroll,
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          children: List.generate(hours.length, (index) {
                            final hour = hours[index];
                            final isBigGap =
                                index > 0 && (hour - hours[index - 1]) > 1;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isBigGap) const _GapRow(),
                                SizedBox(
                                  height: _slotHeight,
                                  child: ScheduleHoursColumn(
                                    hour: hour,
                                    width: _timeColWidth,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontalScroll,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: totalDaysWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScheduleHeader(
                          colWidth: colWidth,
                          daysOfWeek: days,
                          headerHeight: _headerHeight,
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _gridVerticalScroll,
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              children: List.generate(hours.length, (index) {
                                final hour = hours[index];
                                final isBigGap =
                                    index > 0 && (hour - hours[index - 1]) > 1;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isBigGap) const _GapRow(),
                                    SizedBox(
                                      height: _slotHeight,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: days.map((day) {
                                          return ScheduleDayColumn(
                                            dayOfWeek: day.$1,
                                            hour: hour,
                                            entries: entries,
                                            width: colWidth,
                                            genreColorMap: widget.genreColorMap,
                                            onOpenClass: widget.onOpenClass,
                                            onAddClass: widget.onAddClass,
                                            accessFor: widget.accessFor,
                                            showOrganization:
                                                widget.showOrganization,
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      color: context.cardBg.withValues(alpha: 0.4),
      child: Center(
        child: Icon(
          Icons.more_horiz,
          size: 14,
          color: context.textMuted.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
