import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../providers/events_provider.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../public/widgets/active_filters_bar.dart';
import 'widgets/week_day_header.dart';
import 'widgets/week_timeline.dart';

class WeekCalendarView extends ConsumerWidget {
  const WeekCalendarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final eventsAsync = ref.watch(weekEventsProvider);
    final weekDays = DateFormatter.weekDays(selectedWeek);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Selector de semana y días ──────────────────────────
            _WeekNavigationHeader(
              weekDays: weekDays,
              selectedDay: selectedDay,
              onPreviousWeek: () =>
                  ref.read(selectedWeekProvider.notifier).previousWeek(),
              onNextWeek: () =>
                  ref.read(selectedWeekProvider.notifier).nextWeek(),
              onDaySelected: (day) =>
                  ref.read(selectedDayProvider.notifier).setDay(day),
            ),

            Divider(height: 1, color: context.divider),

            // ── Filtros visibles (público) ─────────────────────────
            const ActiveFiltersBar(),

            // ── Timeline ───────────────────────────────────────────
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
                  final dayEvents = allEvents
                      .where((e) =>
                          e.startTime.year == selectedDay.year &&
                          e.startTime.month == selectedDay.month &&
                          e.startTime.day == selectedDay.day)
                      .toList();

                  return WeekTimeline(
                    events: dayEvents,
                    date: selectedDay,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Header con navegación de semana + días
// ─────────────────────────────────────────────
class _WeekNavigationHeader extends StatelessWidget {
  const _WeekNavigationHeader({
    required this.weekDays,
    required this.selectedDay,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onDaySelected,
  });

  final List<DateTime> weekDays;
  final DateTime selectedDay;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    // "Ago 2026" — toma el mes del primer día visible
    final first = weekDays.first;
    final last = weekDays.last;
    final monthLabel =
        '${DateFormatter.dayMonth(first)} — ${DateFormatter.dayMonth(last)}';

    return Container(
      color: context.cardBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingSmall,
        vertical: AppSizes.paddingSmall,
      ),
      child: Column(
        children: [
          // Fila: ← rango → 
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: context.textOnBg),
                onPressed: onPreviousWeek,
                tooltip: 'Semana anterior',
              ),
              Expanded(
                child: Text(
                  monthLabel.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: context.textOnBg),
                onPressed: onNextWeek,
                tooltip: 'Semana siguiente',
              ),
            ],
          ),
          // Fila de 7 días
          Row(
            children: weekDays.map((day) {
              final isSelected = day.year == selectedDay.year &&
                  day.month == selectedDay.month &&
                  day.day == selectedDay.day;
              return Expanded(
                child: WeekDayHeader(
                  day: day,
                  isSelected: isSelected,
                  onTap: () => onDaySelected(day),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
