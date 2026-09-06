import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../providers/events_provider.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../public/widgets/active_filters_bar.dart';
import 'widgets/day_view.dart';
import 'widgets/week_column.dart';

/// Calendar view estilo Google Calendar.
///
/// Muestra directamente los 7 días arriba (sin botones de nav).
/// Se desliza horizontalmente para cambiar de semana.
/// Al tocar un día se hace una transición lateral a vista de día.
class WeekCalendarView extends ConsumerStatefulWidget {
  const WeekCalendarView({super.key});

  @override
  ConsumerState<WeekCalendarView> createState() => _WeekCalendarViewState();
}

class _WeekCalendarViewState extends ConsumerState<WeekCalendarView> {
  /// Controla la dirección de la animación al entrar a día.
  bool _slideForward = true;

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final eventsAsync = ref.watch(weekEventsProvider);
    // Ventana móvil: comienza en el día de referencia (hoy por defecto) y
    // muestra los próximos 6 días, así siempre se ven clases/eventos futuros.
    final weekDays = DateFormatter.consecutiveDays(selectedWeek, 7);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: solo los 7 días, swipeable ─────────────────
            _WeekDayStrip(
              weekDays: weekDays,
              selectedDay: selectedDay,
              onDaySelected: (day) {
                final current = ref.read(selectedDayProvider);
                _slideForward = !day.isBefore(current);
                ref.read(selectedDayProvider.notifier).setDay(day);
                _enterDayView(context);
              },
              onSwipeLeft: () =>
                  ref.read(selectedWeekProvider.notifier).nextWeek(),
              onSwipeRight: () =>
                  ref.read(selectedWeekProvider.notifier).previousWeek(),
            ),

            Divider(height: 1, color: context.divider),

            // ── Filtros ───────────────────────────────────────────
            const ActiveFiltersBar(),

            // ── Contenido: semana ─────────────────────────────────
            Expanded(
              child: eventsAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.paddingLarge),
                    child: AppBanner(
                      message: 'Error cargando eventos: $e',
                      type: BannerType.error,
                    ),
                  ),
                ),
                data: (allEvents) {
                  return WeekColumns(
                    weekDays: weekDays,
                    events: allEvents,
                    selectedDay: selectedDay,
                    heightPerHour: 48,
                    onDaySelected: (day) {
                      final current = ref.read(selectedDayProvider);
                      _slideForward = !day.isBefore(current);
                      ref.read(selectedDayProvider.notifier).setDay(day);
                      _enterDayView(context);
                    },
                    onSwipeLeft: () =>
                        ref.read(selectedWeekProvider.notifier).nextWeek(),
                    onSwipeRight: () =>
                        ref.read(selectedWeekProvider.notifier).previousWeek(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _enterDayView(BuildContext context) {
    // Ancla la ventana de datos al día seleccionado para que la vista de día
    // (que es multi-día) siempre tenga el rango completo cargado.
    final day = ref.read(selectedDayProvider);
    ref.read(selectedWeekProvider.notifier).setWeek(day);
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => const _DayViewWrapper(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final offset = _slideForward
              ? const Offset(1.0, 0.0)
              : const Offset(-1.0, 0.0);
          return SlideTransition(
            position: Tween<Offset>(begin: offset, end: Offset.zero)
                .animate(curved),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// Wrapper para la vista de día que escucha los providers.
class _DayViewWrapper extends ConsumerWidget {
  const _DayViewWrapper();

  void _changeDay(WidgetRef ref, int days) {
    final current = ref.read(selectedDayProvider);
    final newDay = current.add(Duration(days: days));
    _setDay(ref, newDay);
  }

  void _setDay(WidgetRef ref, DateTime day) {
    ref.read(selectedDayProvider.notifier).setDay(day);
    // Con la ventana móvil, el inicio de la ventana SIEMPRE sigue al día
    // seleccionado para que los próximos eventos se carguen correctamente.
    ref.read(selectedWeekProvider.notifier).setWeek(day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final eventsAsync = ref.watch(weekEventsProvider);

    return eventsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (allEvents) {
        return DayView(
          events: allEvents,
          selectedDay: selectedDay,
          onBack: () => Navigator.of(context).pop(),
          onPreviousDay: () => _changeDay(ref, -1),
          onNextDay: () => _changeDay(ref, 1),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Strip de 7 días estilo Google Calendar
// ─────────────────────────────────────────────
class _WeekDayStrip extends StatefulWidget {
  const _WeekDayStrip({
    required this.weekDays,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  final List<DateTime> weekDays;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  @override
  State<_WeekDayStrip> createState() => _WeekDayStripState();
}

class _WeekDayStripState extends State<_WeekDayStrip> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find the current week's Monday to check if "today" is in this week
    final weekMonday = widget.weekDays.first;
    final weekSunday = widget.weekDays.last;
    final isTodayInWeek = !now.isBefore(weekMonday) && !now.isAfter(weekSunday);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -200) {
          widget.onSwipeLeft();
        } else if (v > 200) {
          widget.onSwipeRight();
        }
      },
      child: Container(
        color: isDark ? AppColors.background : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: widget.weekDays.map((day) {
            final isToday = isTodayInWeek &&
                day.year == now.year &&
                day.month == now.month &&
                day.day == now.day;
            final isSelected = day.year == widget.selectedDay.year &&
                day.month == widget.selectedDay.month &&
                day.day == widget.selectedDay.day;

            return Expanded(
              child: GestureDetector(
                onTap: () => widget.onDaySelected(day),
                child: _DayChip(
                  day: day,
                  isToday: isToday,
                  isSelected: isSelected,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Chip individual de día estilo Google Calendar.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.isToday,
    required this.isSelected,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = AppColors.primary;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final mutedColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Day abbreviation: L, M, X, J, V, S, D
        Text(
          DateFormatter.shortDay(day).substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isToday ? selectedColor : mutedColor,
          ),
        ),
        const SizedBox(height: 4),
        // Day number inside a circle
        Container(
          width: 36,
          height: 36,
          decoration: isSelected
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: selectedColor,
                )
              : isToday
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedColor,
                        width: 1.5,
                      ),
                    )
                  : null,
          alignment: Alignment.center,
          child: Text(
            DateFormatter.dayNumber(day),
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected || isToday
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: isSelected
                  ? Colors.white
                  : isToday
                      ? selectedColor
                      : textColor,
            ),
          ),
        ),
      ],
    );
  }
}
