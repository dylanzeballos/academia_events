import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../classes/views/class_create_view.dart';
import 'schedule/schedule_day_column.dart';
import 'schedule/schedule_header.dart';
import 'schedule/schedule_hours_column.dart';

class AcademyClassesView extends ConsumerStatefulWidget {
  const AcademyClassesView({super.key});

  @override
  ConsumerState<AcademyClassesView> createState() => _AcademyClassesViewState();
}

class _AcademyClassesViewState extends ConsumerState<AcademyClassesView> {
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _hoursVerticalScroll = ScrollController();
  final ScrollController _gridVerticalScroll = ScrollController();
  bool _syncingVertical = false;
  bool _isLandscape = false;

  static const double _timeColWidth = 54.0;
  static const double _minColWidth = 95.0;
  static const double _slotHeight = 92.0;

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
    final scheduleEntriesAsync = ref.watch(orgWeeklyScheduleEntriesProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageClasses ?? false;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        if (mounted) context.go(AppRoutes.academyDashboard);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F121A),
        appBar: AppBar(
        backgroundColor: const Color(0xFF141824),
        elevation: 0,
        title: const Text(
          'Horario Semanal',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: _isLandscape ? 'Modo Vertical' : 'Rotar Horizontal',
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
        body: SafeArea(
          child: scheduleEntriesAsync.when(
          loading: () => const LoadingIndicator(),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
          ),
          data: (entries) {
            if (entries.isEmpty) return _buildEmptyState(context, canManage);

            final activeHoursList = entries
                .map((e) => _parseHour(e.schedule.startTime))
                .toSet()
                .toList()
              ..sort();

            // Asignación de colores dinámicos sin repetir entre géneros presentes
            final uniqueGenres = entries
                .map((e) => _extractGenre(e.danceClass.title))
                .toSet()
                .toList();

            const List<Color> dynamicPalette = [
              Color(0xFFEF4444), // Rojo
              Color(0xFF8B5CF6), // Violeta
              Color(0xFFF59E0B), // Ámbar
              Color(0xFF10B981), // Verde Esmeralda
              Color(0xFF06B6D4), // Cyan
              Color(0xFFEC4899), // Rosa
              Color(0xFF3B82F6), // Azul
              Color(0xFFF97316), // Naranja
              Color(0xFF14B8A6), // Turquesa
              Color(0xFFA855F7), // Púrpura
              Color(0xFF84CC16), // Lima
              Color(0xFF6366F1), // Índigo
            ];

            final Map<String, Color> genreColorMap = {
              for (int i = 0; i < uniqueGenres.length; i++)
                uniqueGenres[i]: dynamicPalette[i % dynamicPalette.length],
            };

            return LayoutBuilder(
              builder: (context, constraints) {
                const headerHeight = 44.0;
                final availableWidth = constraints.maxWidth - _timeColWidth;
                final colWidth =
                    (availableWidth / _daysOfWeek.length).clamp(_minColWidth, 180.0);
                final totalDaysWidth = colWidth * _daysOfWeek.length;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna fija de horas lateral
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
                                right: BorderSide(color: Color(0xFF222738), width: 1.2),
                                bottom: BorderSide(color: Color(0xFF222738), width: 1.2),
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
                                          color: const Color(0xFF0C0E14),
                                          child: Center(
                                            child: Icon(
                                              Icons.more_horiz,
                                              size: 14,
                                              color: Colors.white.withValues(alpha: 0.25),
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

                    // Matriz de días con cabecera y cuerpo sincronizados
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
                                daysOfWeek: _daysOfWeek,
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
                                              color: const Color(0xFF0C0E14),
                                              child: Center(
                                                child: Container(
                                                  height: 1,
                                                  margin: const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                                  color: Colors.white
                                                      .withValues(alpha: 0.05),
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
                                              children: _daysOfWeek.map((dayDef) {
                                                final dayInt = dayDef.$1;
                                                return ScheduleDayColumn(
                                                  dayOfWeek: dayInt,
                                                  hour: hour,
                                                  entries: entries,
                                                  width: colWidth,
                                                  genreColorMap: genreColorMap,
                                                  onAddClass: canManage
                                                      ? () async {
                                                          await Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) =>
                                                                  const ClassCreateView(),
                                                            ),
                                                          );
                                                          ref.invalidate(
                                                              orgClassesProvider);
                                                          ref.invalidate(
                                                              orgWeeklyScheduleEntriesProvider);
                                                        }
                                                      : null,
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
      floatingActionButton: (canManage && !_isLandscape)
          ? FloatingActionButton.small(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClassCreateView()),
                );
                ref.invalidate(orgClassesProvider);
                ref.invalidate(orgWeeklyScheduleEntriesProvider);
              },
              backgroundColor: const Color(0xFFE85D04),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            )
          : null,
          ),
            );
  }

  Widget _buildEmptyState(BuildContext context, bool canManage) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'Sin clases configuradas',
            style: TextStyle(
                color: context.textOnBg,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('Define qué días y horas abre cada clase.',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          if (canManage) ...[
            const SizedBox(height: 24),
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
              label: const Text('Crear clase y definir días'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE85D04)),
            ),
          ],
        ],
      ),
    );
  }
}