import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../calendar/widgets/column/timeline_scale.dart';
import 'class_create_view.dart';
import 'class_detail_view.dart';

class ClassListView extends ConsumerStatefulWidget {
  const ClassListView({super.key});

  @override
  ConsumerState<ClassListView> createState() => _ClassListViewState();
}

class _ClassListViewState extends ConsumerState<ClassListView> {
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _headerScroll = ScrollController();
  bool _syncingScroll = false;
  bool _isLandscape = false;
  bool _fitToScreen = false;

  static const double _timeColWidth = 58.0;
  static const double _defaultColWidth = 145.0;
  static const int _startHour = 7;
  static const int _endHour = 23;

  // 1 = Lun ... 6 = Sáb, 0 = Dom (Postgres day_of_week)
  static const List<(int, String, String)> _daysOfWeek = [
    (1, 'LUN', 'LUNES'),
    (2, 'MAR', 'MARTES'),
    (3, 'MIÉ', 'MIÉRCOLES'),
    (4, 'JUE', 'JUEVES'),
    (5, 'VIE', 'VIERNES'),
    (6, 'SÁB', 'SÁBADO'),
    (0, 'DOM', 'DOMINGO'),
  ];

  @override
  void initState() {
    super.initState();
    _horizontalScroll.addListener(_syncH);
    _headerScroll.addListener(_syncH);
  }

  void _syncH() {
    if (_syncingScroll) return;
    _syncingScroll = true;
    if (_horizontalScroll.hasClients && _headerScroll.hasClients) {
      if ((_horizontalScroll.offset - _headerScroll.offset).abs() > 0.5) {
        _headerScroll.jumpTo(_horizontalScroll.offset);
      }
    }
    _syncingScroll = false;
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    _headerScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escucha el provider que une las clases con sus horarios semanales
    final scheduleEntriesAsync = ref.watch(orgWeeklyScheduleEntriesProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageClasses ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0F121A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141824),
        elevation: 0,
        title: const Text(
          'Horario',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: _fitToScreen ? 'Modo Scroll' : 'Ajustar a pantalla',
            icon: Icon(
              _fitToScreen ? Icons.view_column_outlined : Icons.fit_screen_outlined,
              color: Colors.white70,
            ),
            onPressed: () => setState(() => _fitToScreen = !_fitToScreen),
          ),
          IconButton(
            tooltip: _isLandscape ? 'Modo Vertical' : 'Pantalla Completa Horizontal',
            icon: Icon(
              _isLandscape ? Icons.screen_lock_portrait : Icons.screen_rotation_outlined,
              color: AppColors.primary,
            ),
            onPressed: _toggleOrientation,
          ),
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              ref.invalidate(orgClassesProvider);
              ref.invalidate(orgWeeklyScheduleEntriesProvider);
            },
          ),
        ],
      ),
      body: scheduleEntriesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return _buildEmptyState(canManage);
          }

          final scale = TimelineScale(
            startHour: _startHour,
            endHour: _endHour,
            activeHours: {for (var h = _startHour; h < _endHour; h++) h},
            availableHeight: 0,
            activePxPerHour: 80.0,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final availableGridWidth = constraints.maxWidth - _timeColWidth;
              final colWidth = _fitToScreen
                  ? math.max(availableGridWidth / _daysOfWeek.length, 120.0)
                  : _defaultColWidth;
              final totalGridWidth = colWidth * _daysOfWeek.length;

              return Column(
                children: [
                  // ── Cabecera: HORA + Días ──
                  Container(
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFF171B26),
                      border: Border(bottom: BorderSide(color: Color(0xFF222738), width: 1.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: _timeColWidth,
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF202638),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule, size: 10, color: Colors.white70),
                                SizedBox(width: 3),
                                Text(
                                  'HORA',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _headerScroll,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                              width: totalGridWidth,
                              child: Row(
                                children: _daysOfWeek.map((d) {
                                  return SizedBox(
                                    width: colWidth,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          d.$2,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          d.$3,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.45),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 9,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
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

                  // ── Grilla con Horas y Columnas de Clases ──
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _verticalScroll,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        height: scale.totalHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: _timeColWidth,
                              child: _DarkTimelineLabels(scale: scale),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _horizontalScroll,
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: SizedBox(
                                  width: totalGridWidth,
                                  child: Row(
                                    children: _daysOfWeek.map((dayDef) {
                                      final dayInt = dayDef.$1;
                                      final dayEntries = entries.where((e) {
                                        return e.schedule.dayOfWeek == dayInt;
                                      }).toList();

                                      return SizedBox(
                                        width: colWidth,
                                        child: _DarkScheduleDayColumn(
                                          dayOfWeek: dayInt,
                                          entries: dayEntries,
                                          scale: scale,
                                          onAddClass: canManage
                                              ? (h) async {
                                                  await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => const ClassCreateView(),
                                                    ),
                                                  );
                                                  ref.invalidate(orgClassesProvider);
                                                  ref.invalidate(orgWeeklyScheduleEntriesProvider);
                                                }
                                              : null,
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
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClassCreateView()),
                );
                ref.invalidate(orgClassesProvider);
                ref.invalidate(orgWeeklyScheduleEntriesProvider);
              },
              backgroundColor: const Color(0xFFE85D04),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyState(bool canManage) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_view_week, size: 60, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text(
            'Sin clases registradas',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Crea clases recurrentes para armar tu horario.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
          if (canManage) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClassCreateView()),
                );
                ref.invalidate(orgClassesProvider);
                ref.invalidate(orgWeeklyScheduleEntriesProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Crear Clase'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE85D04)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DarkTimelineLabels extends StatelessWidget {
  const _DarkTimelineLabels({required this.scale});

  final TimelineScale scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141824),
        border: Border(right: BorderSide(color: Color(0xFF222738), width: 1.2)),
      ),
      child: Stack(
        children: List.generate(scale.totalHours + 1, (i) {
          final hour = scale.startHour + i;
          final top = scale.topAt(hour);
          final isHighlighted = hour == 19;

          return Positioned(
            top: top + 4,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    color: isHighlighted ? const Color(0xFFFF7A00) : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${(hour + 1).toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isHighlighted)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF7A00),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _DarkScheduleDayColumn extends StatelessWidget {
  const _DarkScheduleDayColumn({
    required this.dayOfWeek,
    required this.entries,
    required this.scale,
    this.onAddClass,
  });

  final int dayOfWeek;
  final List<OrgScheduleEntry> entries;
  final TimelineScale scale;
  final void Function(int hour)? onAddClass;

  int _timeToMinutes(String rawTime) {
    try {
      final clean = rawTime.trim().split(' ')[0].split('+')[0];
      final parts = clean.split(':');
      final h = int.parse(parts[0]);
      final m = parts.length > 1 ? int.parse(parts[1]) : 0;
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF1E2333), width: 0.8)),
      ),
      child: Stack(
        children: [
          ...List.generate(scale.totalHours, (i) {
            final hour = scale.startHour + i;
            final top = scale.topAt(hour);
            final height = scale.pxPerHourAt(hour);

            return Positioned(
              top: top,
              left: 0,
              right: 0,
              height: height,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF1C2130), width: 0.7)),
                ),
                child: Center(
                  child: IconButton(
                    icon: Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    onPressed: onAddClass != null ? () => onAddClass!(hour) : null,
                  ),
                ),
              ),
            );
          }),

          ...entries.map((entry) {
            final s = entry.schedule;
            final startMin = _timeToMinutes(s.startTime);
            final endMin = _timeToMinutes(s.endTime);

            final top = scale.yForMinutes(startMin);
            final bottom = scale.yForMinutes(endMin > startMin ? endMin : startMin + 60);
            final height = math.max(bottom - top, 64.0);

            return Positioned(
              top: top + 2,
              left: 2,
              right: 2,
              height: height - 4,
              child: _DarkClassCard(entry: entry),
            );
          }),
        ],
      ),
    );
  }
}

class _DarkClassCard extends ConsumerWidget {
  const _DarkClassCard({required this.entry});

  final OrgScheduleEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final danceClass = entry.danceClass;
    final schedule = entry.schedule;

    final titleLower = danceClass.title.toLowerCase();
    final bool isKizomba = titleLower.contains('kizomba') || titleLower.contains('urban');
    final bool isFree = titleLower.contains('práctica') || titleLower.contains('pista');

    final Color cardBg = isFree
        ? const Color(0xFF161A26)
        : isKizomba
            ? const Color(0xFF133444)
            : const Color(0xFF382319);

    final Color badgeBg = isFree
        ? Colors.transparent
        : isKizomba
            ? const Color(0xFF1EA7C7)
            : const Color(0xFFE85D04);

    final String categoryTag = isFree
        ? 'PRÁCTICA'
        : isKizomba
            ? 'KIZOMBA'
            : (titleLower.contains('bachata') ? 'BACHATA' : 'SALSA');

    final instructor = schedule.instructorName ?? danceClass.instructorName ?? 'Profesor';

    int durationMin = 60;
    try {
      final sParts = schedule.startTime.split(':');
      final eParts = schedule.endTime.split(':');
      final sM = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
      final eM = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
      if (eM > sM) durationMin = eM - sM;
    } catch (_) {}

    return GestureDetector(
      onTap: () async {
        ref.read(selectedClassIdProvider.notifier).select(danceClass.id);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClassDetailView()),
        );
        ref.invalidate(orgClassesProvider);
        ref.invalidate(orgWeeklyScheduleEntriesProvider);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFree ? const Color(0xFF262E42) : badgeBg.withValues(alpha: 0.35),
            width: 1.1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      categoryTag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${durationMin}m',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                danceClass.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    instructor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 8.5,
                    ),
                  ),
                ),
                if (danceClass.price > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${danceClass.price.toInt()} BOB',
                    style: const TextStyle(
                      color: Color(0xFFE85D04),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}