import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../providers/events_provider.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../public/widgets/event_filters_bar.dart';
import 'widgets/week_column.dart';

/// Calendar view estilo Google Calendar.
///
/// Muestra SIEMPRE los 7 días (lun a dom) de la semana seleccionada. La
/// navegación entre semanas usa flechas (anterior/siguiente) y una cabecera
/// con el mes/año; no hay gesto de deslizar ni entrada a vista de día.
class WeekCalendarView extends ConsumerWidget {
  const WeekCalendarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final eventsAsync = ref.watch(weekEventsProvider);
    // Semana completa anclada al lunes.
    final weekDays = DateFormatter.weekDays(selectedWeek);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Cabecera de navegación por semana ─────────────────
            _WeekNavigator(weekDays: weekDays),
            const EventFiltersBar(),

            Divider(height: 1, color: context.divider),

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
                    onDaySelected: (day) =>
                        ref.read(selectedDayProvider.notifier).setDay(day),
                    showDayStrip: true,
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

/// Barra de navegación semanal: flecha atrás, mes/año en el centro y flecha
/// adelante. Las flechas cambian de semana (lun a lun).
class _WeekNavigator extends ConsumerWidget {
  const _WeekNavigator({required this.weekDays});

  final List<DateTime> weekDays;

  String _label() {
    final first = weekDays.first;
    final last = weekDays.last;
    if (first.month == last.month && first.year == last.year) {
      return DateFormatter.capitalize(DateFormatter.monthYear(first));
    }
    final a = DateFormatter.capitalize(DateFormatter.shortMonth(first));
    final b = DateFormatter.capitalize(DateFormatter.shortMonth(last));
    if (first.year == last.year) {
      return '$a – $b ${first.year}';
    }
    return '$a ${first.year} – $b ${last.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: context.cardBg,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Semana anterior',
            onPressed: () =>
                ref.read(selectedWeekProvider.notifier).previousWeek(),
          ),
          Expanded(
            child: Text(
              _label(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Semana siguiente',
            onPressed: () =>
                ref.read(selectedWeekProvider.notifier).nextWeek(),
          ),
        ],
      ),
    );
  }
}