import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_model.dart';
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

  static const double _timeColWidth = 62.0;
  static const double _defaultColWidth = 120.0;
  static const int _startHour = 15;
  static const int _endHour = 23;

  static const List<(int, String, String)> _daysOfWeek = [
    (1, 'LUN', 'LUNES'),
    (2, 'MAR', 'MARTES'),
    (3, 'MIÉ', 'MIÉRCOLES'),
    (4, 'JUE', 'JUEVES'),
    (5, 'VIE', 'VIERNES'),
    (6, 'SÁB', 'SÁBADO'),
    (7, 'DOM', 'DOMINGO'),
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
    if ((_horizontalScroll.offset - _headerScroll.offset).abs() > 0.5) {
      if (_horizontalScroll.hasClients && _headerScroll.hasClients) {
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
    final classesAsync = ref.watch(orgClassesProvider);
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
            onPressed: () => ref.invalidate(orgClassesProvider),
          ),
        ],
      ),
      body: classesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
        data: (classes) {
          if (classes.isEmpty) {
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
                  ? (availableGridWidth / _daysOfWeek.length).clamp(70.0, 300.0)
                  : _defaultColWidth;
              final totalGridWidth = colWidth * _daysOfWeek.length;

              return Column(
                children: [
                  // ── Fila superior: Chip "HORA" + Cabecera de días ──
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF202638),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule, size: 11, color: Colors.white70),
                                SizedBox(width: 3),
                                Text(
                                  'HORA',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
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
                            physics: _fitToScreen ? const NeverScrollableScrollPhysics() : null,
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

                  // ── Grilla con horas laterales y tarjetas de clases ──
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _verticalScroll,
                      child: SizedBox(
                        height: scale.totalHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Columna de Horas laterales
                            SizedBox(
                              width: _timeColWidth,
                              child: _DarkTimelineLabels(scale: scale),
                            ),
                            // Columnas de días
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _horizontalScroll,
                                scrollDirection: Axis.horizontal,
                                physics: _fitToScreen ? const NeverScrollableScrollPhysics() : null,
                                child: SizedBox(
                                  width: totalGridWidth,
                                  child: Row(
                                    children: _daysOfWeek.map((dayDef) {
                                      final weekday = dayDef.$1;
                                      final dayClasses = classes.where((c) {
                                        final start = c.startTime;
                                        if (start == null) return false;
                                        return start.weekday == weekday;
                                      }).toList();

                                      return SizedBox(
                                        width: colWidth,
                                        child: _DarkScheduleDayColumn(
                                          weekday: weekday,
                                          classes: dayClasses,
                                          scale: scale,
                                          onAddClass: canManage
                                              ? (h) => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => const ClassCreateView(),
                                                    ),
                                                  )
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClassCreateView()),
              ),
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClassCreateView()),
              ),
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

// ─────────────────────────────────────────────
// ETIQUETAS LATERALES DE HORAS CON PUNTO
// ─────────────────────────────────────────────
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
          final isHighlighted = hour == 19; // Horario destacado con punto naranja

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

// ─────────────────────────────────────────────
// COLUMNA DE DÍA
// ─────────────────────────────────────────────
class _DarkScheduleDayColumn extends StatelessWidget {
  const _DarkScheduleDayColumn({
    required this.weekday,
    required this.classes,
    required this.scale,
    this.onAddClass,
  });

  final int weekday;
  final List<ClassModel> classes;
  final TimelineScale scale;
  final void Function(int hour)? onAddClass;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF1E2333), width: 0.8)),
      ),
      child: Stack(
        children: [
          // Líneas y botón '+' para espacios vacíos
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

          // Tarjetas de clases
          ...classes.where((c) => c.startTime != null).map((cls) {
            final start = cls.startTime!;
            final end = cls.endTime ?? start.add(const Duration(hours: 1));

            final startMin = start.hour * 60 + start.minute;
            final endMin = end.hour * 60 + end.minute;

            final top = scale.yForMinutes(startMin);
            final height = math.max(scale.yForMinutes(endMin) - top, 72.0);

            return Positioned(
              top: top + 2,
              left: 3,
              right: 3,
              height: height - 4,
              child: _DarkClassCard(danceClass: cls),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TARJETA IDÉNTICA A LA IMAGEN
// ─────────────────────────────────────────────
class _DarkClassCard extends ConsumerWidget {
  const _DarkClassCard({required this.danceClass});

  final ClassModel danceClass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determinar temática cromática según el título o categoría
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
        ? 'PRÁCTICA LIBRE'
        : isKizomba
            ? 'KIZOMBA'
            : (titleLower.contains('bachata') ? 'BACHATA' : 'SALSA');

    final String instructor = danceClass.instructorName ?? 'Staff';

    return GestureDetector(
      onTap: () async {
        ref.read(selectedClassIdProvider.notifier).select(danceClass.id);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClassDetailView()),
        );
        ref.invalidate(orgClassesProvider);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFree
                ? const Color(0xFF262E42)
                : badgeBg.withValues(alpha: 0.35),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fila de Tags (Ej: SALSA | 75m) ──
            if (!isFree)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      categoryTag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '75m',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else
              Text(
                categoryTag,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),

            const SizedBox(height: 4),

            // ── Título del estilo / Nivel ──
            Expanded(
              child: Text(
                danceClass.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
            ),

            // ── Profesor / Sala / Pista ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isFree ? 'Pista Abierta' : instructor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isFree)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'S1',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}