import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../providers/events_provider.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../public/widgets/event_filters_bar.dart';
import '../public/widgets/organization_carousel.dart';
import 'widgets/week_column.dart';
import 'widgets/week_event_list.dart';
import 'widgets/day_view.dart';

/// Horario semanal con filtros y vistas de calendario o lista.
class WeekCalendarView extends ConsumerStatefulWidget {
  const WeekCalendarView({super.key});

  @override
  ConsumerState<WeekCalendarView> createState() => _WeekCalendarViewState();
}

class _WeekCalendarViewState extends ConsumerState<WeekCalendarView> {
  bool _showList = false;

  /// Día abierto en la vista de día (`null` = vista semanal).
  DateTime? _focusedDay;

  void _toggleView() {
    final showList = !_showList;
    setState(() => _showList = showList);
    if (showList) {
      ref.read(organizationCarouselSearchProvider.notifier).setQuery('');
    }
  }

  /// Abre la vista de día y ancla la ventana semanal a ese día.
  void _openDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    ref.read(selectedDayProvider.notifier).setDay(date);
    ref.read(selectedWeekProvider.notifier).setWeek(date);
    setState(() => _focusedDay = date);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final eventsAsync = ref.watch(weekEventsProvider);
    final selectedDayEvents = ref.watch(dayEventsProvider);
    final weekDays = DateFormatter.weekDays(selectedWeek);

    if (_focusedDay != null && !_showList) {
      return eventsAsync.when(
        loading: () => const Scaffold(body: LoadingIndicator()),
        error: (e, _) =>
            Scaffold(body: AppErrorState(message: friendlyError(e))),
        data: (allEvents) => DayView(
          day: _focusedDay!,
          events: allEvents,
          onClose: () => setState(() => _focusedDay = null),
          onChanged: _openDay,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
              child: Row(
                children: [
                  Text(
                    'Horario',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: _showList
                        ? 'Ver calendario semanal'
                        : 'Ver lista de eventos',
                    icon: Icon(
                      _showList
                          ? Icons.calendar_view_week_outlined
                          : Icons.view_list_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: _toggleView,
                  ),
                ],
              ),
            ),
            if (!_showList && selectedDayEvents.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: OrganizationCarouselSearchBar(),
              ),
            if (!_showList) _WeekNavigator(weekDays: weekDays),
            const EventFiltersBar(),
            Divider(height: 1, color: context.divider),
            Expanded(
              child: eventsAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.paddingLarge),
                    child: AppBanner(
                      message: 'Error cargando eventos. ${friendlyError(e)}',
                      type: BannerType.error,
                    ),
                  ),
                ),
                data: (allEvents) {
                  if (_showList) {
                    return WeekEventList(
                      selectedDay: selectedDay,
                      fallbackEvents: allEvents,
                    );
                  }
                  if (allEvents.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final carouselHeight = constraints.maxHeight - 12;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: OrganizationCarousel(
                            height: carouselHeight,
                            expandedHeight: carouselHeight,
                            autoPlayInterval: const Duration(seconds: 4),
                          ),
                        );
                      },
                    );
                  }
                  final calendar = WeekColumns(
                    weekDays: weekDays,
                    events: allEvents,
                    selectedDay: selectedDay,
                    heightPerHour: 48,
                    onDaySelected: _openDay,
                    showDayStrip: true,
                  );
                  if (selectedDayEvents.isEmpty) {
                    return Column(
                      children: [
                        Expanded(child: calendar),
                        SizedBox(
                          height: 172,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OrganizationCarousel(
                              height: 160,
                              expandedHeight: 160,
                              autoPlayInterval: const Duration(seconds: 4),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return calendar;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekNavigator extends ConsumerWidget {
  const _WeekNavigator({required this.weekDays});

  final List<DateTime> weekDays;

  String _label() {
    final first = weekDays.first;
    final last = weekDays.last;
    if (first.month == last.month && first.year == last.year) {
      return DateFormatter.capitalize(DateFormatter.monthYear(first));
    }
    final firstMonth = DateFormatter.capitalize(
      DateFormatter.shortMonth(first),
    );
    final lastMonth = DateFormatter.capitalize(DateFormatter.shortMonth(last));
    if (first.year == last.year) {
      return '$firstMonth - $lastMonth ${first.year}';
    }
    return '$firstMonth ${first.year} - $lastMonth ${last.year}';
  }

  String _rangeLabel() {
    final first = weekDays.first;
    final last = weekDays.last;
    return '${first.day} ${DateFormatter.shortMonth(first)} – '
        '${last.day} ${DateFormatter.shortMonth(last)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: context.cardBg,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Row(
        children: [
          _navButton(
            context,
            Icons.chevron_left,
            'Semana anterior',
            () => ref.read(selectedWeekProvider.notifier).previousWeek(),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(),
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _rangeLabel(),
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _navButton(
            context,
            Icons.chevron_right,
            'Semana siguiente',
            () => ref.read(selectedWeekProvider.notifier).nextWeek(),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () =>
                ref.read(selectedWeekProvider.notifier).setWeek(DateTime.now()),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Hoy'),
          ),
        ],
      ),
    );
  }

  Widget _navButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, color: context.textOnBg),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}
