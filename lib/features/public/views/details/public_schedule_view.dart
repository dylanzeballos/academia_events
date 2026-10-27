// lib/features/organization/views/details/public_schedule_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../providers/dance_class_provider.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../academy/views/schedule/schedule_header.dart';
import '../../../academy/views/schedule/schedule_hours_column.dart';

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
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horario Semanal',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: context.textOnBg,
              ),
            ),
            Text(
              widget.organizationName,
              style: TextStyle(fontSize: 11, color: context.textMuted),
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
            icon: Icon(Icons.refresh, color: context.textOnBg),
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
              style: TextStyle(color: context.textMuted),
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
                        color: context.textMuted.withValues(alpha: 0.4),
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
                      Text(
                        'Esta academia no tiene clases programadas en este momento.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            final activeHoursList = entries
                .map((e) => _parseHour(e.schedule.startTime))
                .toSet()
                .toList()
              ..sort();

            final activeDaysSet = entries.map((e) => e.schedule.dayOfWeek).toSet();
            final dynamicDaysOfWeek = _allDaysOfWeek
                .where((dayTuple) => activeDaysSet.contains(dayTuple.$1))
                .toList();

            final daysToDisplay = dynamicDaysOfWeek.isNotEmpty
                ? dynamicDaysOfWeek
                : _allDaysOfWeek;

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
                    SizedBox(
                      width: _timeColWidth,
                      child: Column(
                        children: [
                          Container(
                            height: headerHeight,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              border: Border(
                                right: BorderSide(color: context.divider, width: 1.2),
                                bottom: BorderSide(color: context.divider, width: 1.2),
                              ),
                            ),
                            child: Text(
                              'HORA',
                              style: TextStyle(
                                color: context.textMuted,
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
                                children: List.generate(activeHoursList.length, (index) {
                                  final hour = activeHoursList[index];
                                  final isBigGap = index > 0 &&
                                      (hour - activeHoursList[index - 1]) > 1;

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isBigGap)
                                        Container(
                                          height: 24,
                                          color: context.cardBg.withValues(alpha: 0.5),
                                          child: Center(
                                            child: Icon(
                                              Icons.more_horiz,
                                              size: 14,
                                              color: context.textMuted.withValues(alpha: 0.3),
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
                                daysOfWeek: daysToDisplay,
                                headerHeight: headerHeight,
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: _gridVerticalScroll,
                                  physics: const ClampingScrollPhysics(),
                                  child: Column(
                                    children: List.generate(activeHoursList.length, (index) {
                                      final hour = activeHoursList[index];
                                      final isBigGap = index > 0 &&
                                          (hour - activeHoursList[index - 1]) > 1;

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isBigGap)
                                            Container(
                                              height: 24,
                                              color: context.cardBg.withValues(alpha: 0.3),
                                              child: Center(
                                                child: Container(
                                                  height: 1,
                                                  margin: const EdgeInsets.symmetric(horizontal: 10),
                                                  color: context.divider,
                                                ),
                                              ),
                                            ),
                                          Container(
                                            height: _slotHeight,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: context.divider.withValues(alpha: 0.6),
                                                  width: 0.8,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: daysToDisplay.map((dayDef) {
                                                return _PublicScheduleDayColumn(
                                                  dayOfWeek: dayDef.$1,
                                                  hour: hour,
                                                  entries: entries,
                                                  width: colWidth,
                                                  genreColorMap: genreColorMap,
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
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: context.divider.withValues(alpha: 0.6),
              width: 0.7,
            ),
          ),
        ),
      );
    }

    final tag = _extractGenre(match.danceClass.title);
    final color = genreColorMap[tag] ?? AppColors.primary;
    final instructor =
        match.schedule.instructorName ??
        match.danceClass.instructorName ??
        'Profesor';

    // ── FILTRAMOS TODAS LAS SESIONES DE ESTA MISMA CLASE ──
    final allSchedulesForThisClass = entries
        .where((e) => e.danceClass.id == match.danceClass.id)
        .map((e) => e.schedule)
        .toList()
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: context.divider.withValues(alpha: 0.6),
            width: 0.7,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
      child: _PublicScheduleClassCard(
        classId: match.danceClass.id,
        title: match.danceClass.title,
        startTime: match.schedule.startTime,
        allSchedules: allSchedulesForThisClass,
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
    required this.classId,
    required this.title,
    required this.startTime,
    required this.allSchedules,
    required this.instructor,
    required this.price,
    required this.themeColor,
    required this.styleTag,
  });

  final String classId;
  final String title;
  final String startTime;
  final List<dynamic> allSchedules; // Lista con todos los días de esta clase
  final String instructor;
  final double price;
  final Color themeColor;
  final String styleTag;

  void _showEnrollConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                styleTag,
                style: TextStyle(
                  color: themeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profesor: $instructor',
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
            if (price > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Precio: ${price.toInt()} BOB',
                style: TextStyle(
                  color: themeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: 14),

            // ── LISTA DE TODOS LOS DÍAS Y HORAS DE ESTA CLASE ──
            Text(
              'Días y horarios disponibles:',
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.scaffoldBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                border: Border.all(color: context.divider),
              ),
              child: Column(
                children: allSchedules.map((s) {
                  final sTime = s.startTime.toString().substring(0, 5);
                  final eTime = s.endTime != null
                      ? s.endTime.toString().substring(0, 5)
                      : '';
                  final range = eTime.isNotEmpty ? '$sTime - $eTime' : sTime;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: themeColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.dayName,
                          style: TextStyle(
                            color: context.textOnBg,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          range,
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),
            Text(
              '¿Deseas inscribirte a esta clase o elegir tu paquete de sesiones?',
              style: TextStyle(color: context.textOnBg, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
            label: const Text('Inscribirme'),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.push('${AppRoutes.enrollClassDetail}/$classId');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        onTap: () => _showEnrollConfirmDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.5),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
                          color: AppColors.onPrimary,
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
                      color: context.textMuted,
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
                  style: TextStyle(
                    color: context.textOnBg,
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
                        color: context.textMuted,
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
        ),
      ),
    );
  }
}