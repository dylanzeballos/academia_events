import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../providers/dance_class_provider.dart';
import '../../../../shared/widgets/loading_indicator.dart';
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
            ? [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
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
            final activeHoursList =
                entries
                    .map((e) => _parseHour(e.schedule.startTime))
                    .toSet()
                    .toList()
                  ..sort();

            // 2. DÍAS DINÁMICOS: Conserva solo los días que tienen clases registradas
            final activeDaysSet = entries
                .map((e) => e.schedule.dayOfWeek)
                .toSet();
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
                                    final isBigGap =
                                        index > 0 &&
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
                                                color: Colors.white.withValues(
                                                  alpha: 0.25,
                                                ),
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
                                        final isBigGap =
                                            index > 0 &&
                                            (hour -
                                                    activeHoursList[index -
                                                        1]) >
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
                                                children: daysToDisplay.map((
                                                  dayDef,
                                                ) {
                                                  return _PublicScheduleDayColumn(
                                                    dayOfWeek: dayDef.$1,
                                                    hour: hour,
                                                    entries: entries,
                                                    width: colWidth,
                                                    genreColorMap:
                                                        genreColorMap,
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

class _PublicScheduleDayColumn extends StatelessWidget {
  const _PublicScheduleDayColumn({
    required this.dayOfWeek,
    required this.hour,
    required this.entries,
    required this.width,
    required this.genreColorMap,
  });

  final int dayOfWeek;
  final int hour;
  final List<OrgScheduleEntry> entries;
  final double width;
  final Map<String, Color> genreColorMap;

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

  @override
  Widget build(BuildContext context) {
    final match = entries.where((entry) {
      return entry.schedule.dayOfWeek == dayOfWeek &&
          _parseHour(entry.schedule.startTime) == hour;
    }).firstOrNull;

    if (match == null) {
      return Container(
        width: width,
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: Color(0xFF181D2A), width: 0.7),
          ),
        ),
      );
    }

    final tag = _extractGenre(match.danceClass.title);
    final color = genreColorMap[tag] ?? const Color(0xFF6366F1);
    final instructor =
        match.schedule.instructorName ??
        match.danceClass.instructorName ??
        'Profesor';

    return Container(
      width: width,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF181D2A), width: 0.7)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
      child: _PublicScheduleClassCard(
        title: match.danceClass.title,
        startTime: match.schedule.startTime,
        instructor: instructor,
        price: match.danceClass.price,
        themeColor: color,
        styleTag: tag,
      ),
    );
  }
}

class _PublicScheduleClassCard extends StatelessWidget {
  const _PublicScheduleClassCard({
    required this.title,
    required this.startTime,
    required this.instructor,
    required this.price,
    required this.themeColor,
    required this.styleTag,
  });

  final String title;
  final String startTime;
  final String instructor;
  final double price;
  final Color themeColor;
  final String styleTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.5),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 3,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    styleTag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                startTime.substring(0, 5),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                height: 1.15,
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
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 8,
                  ),
                ),
              ),
              if (price > 0)
                Text(
                  '${price.toInt()} Bs',
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
