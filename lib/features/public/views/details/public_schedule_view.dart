import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/dance_class_schedule_model.dart';
import '../../../../providers/dance_class_provider.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../academy/views/schedule/schedule_day_column.dart';
import '../../../academy/views/schedule/schedule_header.dart';
import '../../../academy/views/schedule/schedule_hours_column.dart';

// Provider exclusivo de consulta pública para esta pantalla
final publicOrgScheduleProvider =
  FutureProvider.family<List<OrgScheduleEntry>, String>((ref, orgId) async {
  if (orgId.trim().isEmpty) return [];
  final repo = ref.watch(danceClassRepositoryProvider);
  final classes = await repo.fetchOrganizationClasses(orgId);
  if (classes.isEmpty) return [];

  final entries = <OrgScheduleEntry>[];
  for (final danceClass in classes) {
    final schedules = await repo.fetchClassSchedules(danceClass.id);
    for (final s in schedules) {
      if (s.isActive) {
        entries.add(OrgScheduleEntry(schedule: s, danceClass: danceClass));
      }
    }
  }
  return entries;
});

class PublicScheduleView extends ConsumerStatefulWidget {
  const PublicScheduleView({
    super.key,
    required this.organizationId,
    required this.organizationName,
  });

  final String organizationId;
  final String organizationName;

  @override
  ConsumerState<PublicScheduleView> createState() => _PublicScheduleViewState();
}

class _PublicScheduleViewState extends ConsumerState<PublicScheduleView> {
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _hoursVerticalScroll = ScrollController();
  final ScrollController _gridVerticalScroll = ScrollController();
  bool _syncingVertical = false;
  bool _isLandscape = false;

  static const double _timeColWidth = 54.0;
  static const double _minColWidth = 100.0;
  static const double _slotHeight = 92.0;

  // Lista base con el orden cronológico semanal
  static const List<(int, String, String)> _allDaysOfWeek = [
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
    _hoursVerticalScroll.addListener(_syncFromHours);
    _gridVerticalScroll.addListener(_syncFromGrid);
  }

  void _syncFromHours() {
    if (_syncingVertical) return;
    _syncingVertical = true;
    if (_hoursVerticalScroll.hasClients && _gridVerticalScroll.hasClients) {
      if ((_hoursVerticalScroll.offset - _gridVerticalScroll.offset).abs() > 0.5) {
        _gridVerticalScroll.jumpTo(_hoursVerticalScroll.offset);
      }
    }
    _syncingVertical = false;
  }

  void _syncFromGrid() {
    if (_syncingVertical) return;
    _syncingVertical = true;
    if (_hoursVerticalScroll.hasClients && _gridVerticalScroll.hasClients) {
      if ((_gridVerticalScroll.offset - _hoursVerticalScroll.offset).abs() > 0.5) {
        _hoursVerticalScroll.jumpTo(_gridVerticalScroll.offset);
      }
    }
    _syncingVertical = false;
  }

  int _parseHour(String timeStr) {
    try {
      final clean = timeStr.trim().split(' ')[0].split('+')[0];
      return int.parse(clean.split(':')[0]);
    } catch (_) {
      return 12;
    }
  }

  String _extractGenre(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return 'CLASE';
    return clean.split(RegExp(r'\s+')).first.toUpperCase();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      SystemChrome.setPreferredOrientations(
        _isLandscape
            ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
            : [DeviceOrientation.portraitUp],
      );
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _horizontalScroll.dispose();
    _hoursVerticalScroll.dispose();
    _gridVerticalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheduleEntriesAsync = ref.watch(
      publicOrgScheduleProvider(widget.organizationId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F121A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141824),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Horario Semanal',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              widget.organizationName,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isLandscape ? 'Modo Vertical' : 'Rotar Horizontal',
            icon: Icon(
              _isLandscape
                  ? Icons.screen_lock_portrait
                  : Icons.screen_rotation_outlined,
              color: AppColors.primary,
            ),
            onPressed: _toggleOrientation,
          ),
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              ref.invalidate(publicOrgScheduleProvider(widget.organizationId));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: scheduleEntriesAsync.when(
          loading: () => const LoadingIndicator(),
          error: (e, _) => Center(
            child: Text(
              'Error al cargar horario: $e',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sin horarios disponibles',
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Esta academia no tiene clases programadas en este momento.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            // 1. Horas activas
            final activeHoursList = entries
                .map((e) => _parseHour(e.schedule.startTime))
                .toSet()
                .toList()
              ..sort();

            // 2. DÍAS DINÁMICOS: Conserva solo los días que tienen clases registradas
            final activeDaysSet = entries.map((e) => e.schedule.dayOfWeek).toSet();
            final dynamicDaysOfWeek = _allDaysOfWeek
                .where((dayTuple) => activeDaysSet.contains(dayTuple.$1))
                .toList();

            final daysToDisplay = dynamicDaysOfWeek.isNotEmpty
                ? dynamicDaysOfWeek
                : _allDaysOfWeek;

            // 3. Paleta de colores
            final uniqueGenres = entries
                .map((e) => _extractGenre(e.danceClass.title))
                .toSet()
                .toList();

            const List<Color> dynamicPalette = [
              Color(0xFFEF4444),
              Color(0xFF8B5CF6),
              Color(0xFFF59E0B),
              Color(0xFF10B981),
              Color(0xFF06B6D4),
              Color(0xFFEC4899),
              Color(0xFF3B82F6),
              Color(0xFFF97316),
              Color(0xFF14B8A6),
              Color(0xFFA855F7),
              Color(0xFF84CC16),
              Color(0xFF6366F1),
            ];

            final Map<String, Color> genreColorMap = {
              for (int i = 0; i < uniqueGenres.length; i++)
                uniqueGenres[i]: dynamicPalette[i % dynamicPalette.length],
            };

            return LayoutBuilder(
              builder: (context, constraints) {
                const headerHeight = 44.0;
                final availableWidth = constraints.maxWidth - _timeColWidth;
                final colWidth = (availableWidth / daysToDisplay.length)
                  .clamp(_minColWidth, 220.0)
                  .toDouble();
                final totalDaysWidth = colWidth * daysToDisplay.length;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna de Horas
                    SizedBox(
                      width: _timeColWidth,
                      child: Column(
                        children: [
                          Container(
                            height: headerHeight,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFF171B26),
                              border: Border(
                                right: BorderSide(
                                  color: Color(0xFF222738),
                                  width: 1.2,
                                ),
                                bottom: BorderSide(
                                  color: Color(0xFF222738),
                                  width: 1.2,
                                ),
                              ),
                            ),
                            child: const Text(
                              'HORA',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _hoursVerticalScroll,
                              physics: const ClampingScrollPhysics(),
                              child: Column(
                                children: List.generate(
                                  activeHoursList.length,
                                  (index) {
                                    final hour = activeHoursList[index];
                                    final isBigGap = index > 0 &&
                                        (hour - activeHoursList[index - 1]) > 1;

                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isBigGap)
                                          Container(
                                            height: 24,
                                            color: const Color(0xFF0C0E14),
                                            child: Center(
                                              child: Icon(
                                                Icons.more_horiz,
                                                size: 14,
                                                color: Colors.white
                                                    .withValues(alpha: 0.25),
                                              ),
                                            ),
                                          ),
                                        SizedBox(
                                          height: _slotHeight,
                                          child: ScheduleHoursColumn(
                                            hour: hour,
                                            width: _timeColWidth,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Matriz Semanal (Solo los días con clases, onAddClass: null)
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
                                daysOfWeek: daysToDisplay,
                                headerHeight: headerHeight,
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: _gridVerticalScroll,
                                  physics: const ClampingScrollPhysics(),
                                  child: Column(
                                    children: List.generate(
                                      activeHoursList.length,
                                      (index) {
                                        final hour = activeHoursList[index];
                                        final isBigGap = index > 0 &&
                                            (hour - activeHoursList[index - 1]) >
                                                1;

                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isBigGap)
                                              Container(
                                                height: 24,
                                                color: const Color(0xFF0C0E14),
                                                child: Center(
                                                  child: Container(
                                                    height: 1,
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                    ),
                                                    color: Colors.white
                                                        .withValues(
                                                      alpha: 0.05,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Container(
                                              height: _slotHeight,
                                              decoration: const BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Color(0xFF1C2130),
                                                    width: 0.8,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: daysToDisplay
                                                    .map((dayDef) {
                                                  return ScheduleDayColumn(
                                                    dayOfWeek: dayDef.$1,
                                                    hour: hour,
                                                    entries: entries,
                                                    width: colWidth,
                                                    genreColorMap:
                                                        genreColorMap,
                                                    onAddClass: null,
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
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
      ),
    );
  }
}