import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../calendar/widgets/week_day_header.dart';
import '../../../../data/models/public_event_model.dart';
import '../../../../providers/public_events_provider.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../widgets/event_search_bar.dart';
import '../widgets/event_filter_bottom_sheet.dart';
import '../widgets/public_week_columns.dart';
import '../widgets/active_filters_bar.dart';
import 'public_day_view.dart';

class PublicCalendarView extends ConsumerStatefulWidget {
  const PublicCalendarView({super.key});

  @override
  ConsumerState<PublicCalendarView> createState() => _PublicCalendarViewState();
}

class _PublicCalendarViewState extends ConsumerState<PublicCalendarView> {
  bool _showWeekView = true;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(publicSelectedDayProvider);
    final selectedWeek = ref.watch(publicSelectedWeekProvider);
    final eventsAsync = ref.watch(publicWeekEventsProvider);
    final filter = ref.watch(eventFiltersProvider);
    final weekDays = DateFormatter.weekDays(selectedWeek);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: _showWeekView ? _buildWeekTitle(weekDays) : const Text('Calendario'),
        centerTitle: !isDesktop,
        actions: [
          if (isDesktop) ...[
            const EventSearchBarDesktop(),
            const SizedBox(width: 16),
          ],
          IconButton(
            onPressed: () => setState(() => _showWeekView = !_showWeekView),
            icon: Icon(_showWeekView ? Icons.calendar_month : Icons.calendar_view_week),
            tooltip: _showWeekView ? 'Vista mes' : 'Vista semana',
          ),
          IconButton(
            onPressed: () => EventFilterBottomSheet.show(context),
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (filter.hasActiveFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Filtros',
          ),
        ],
        bottom: !isDesktop && !_showWeekView
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: EventSearchBar(
                    hintText: 'Buscar eventos...',
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  ),
                ),
              )
            : null,
      ),
      body: _showWeekView ? _buildWeekView(context, weekDays, selectedDay, selectedWeek, eventsAsync, isDesktop) : _buildMonthView(context),
    );
  }

  Widget _buildWeekTitle(List<DateTime> weekDays) {
    final first = weekDays.first;
    final last = weekDays.last;
    return Text(
      '${DateFormatter.dayMonth(first)} — ${DateFormatter.dayMonth(last)}',
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildWeekView(
    BuildContext context,
    List<DateTime> weekDays,
    DateTime selectedDay,
    DateTime selectedWeek,
    AsyncValue<List<PublicEventModel>> eventsAsync,
    bool isDesktop,
  ) {
    return Column(
      children: [
        // Week navigation header
        Container(
          color: context.cardBg,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingSmall,
            vertical: AppSizes.paddingSmall,
          ),
          child: Column(
            children: [
              // Navigation row
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: context.textOnBg),
                    onPressed: () =>
                        ref.read(publicSelectedWeekProvider.notifier).previousWeek(),
                    tooltip: 'Semana anterior',
                  ),
                  Expanded(
                    child: _showWeekView
                        ? _buildWeekTitle(weekDays)
                        : TextButton.icon(
                            onPressed: () => _showMonthPicker(context),
                            icon: Icon(Icons.calendar_today, size: 18, color: context.textOnBg),
                            label: Text(
                              '${DateFormatter.dayMonth(selectedWeek)} ${selectedWeek.year}',
                              style: TextStyle(
                                color: context.textOnBg,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: context.textOnBg),
                    onPressed: () =>
                        ref.read(publicSelectedWeekProvider.notifier).nextWeek(),
                    tooltip: 'Semana siguiente',
                  ),
                ],
              ),
              // Day headers
              Row(
                children: weekDays.map((day) {
                  final isSelected = day.year == selectedDay.year &&
                      day.month == selectedDay.month &&
                      day.day == selectedDay.day;
                  return Expanded(
                    child: WeekDayHeader(
                      day: day,
                      isSelected: isSelected,
                      onTap: () => _openDayView(day),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        Divider(height: 1, color: context.divider),

        // Filtros visibles encima del calendario
        const ActiveFiltersBar(),

        // Timeline
        Expanded(
          child: eventsAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingLarge),
                child: AppBanner(
                  message: 'Error cargando eventos: $e',
                  type: BannerType.error,
                  onDismiss: () => ref.invalidate(publicWeekEventsProvider),
                ),
              ),
            ),
            data: (allEvents) {
              // Muestra TODOS los días de la semana a la vez (incluidos los
              // que ya pasaron), igual que el calendario horario del
              // estudiante. Tocar un día abre su vista de día.
              return PublicWeekColumns(
                weekDays: weekDays,
                events: allEvents,
                selectedDay: selectedDay,
                onDaySelected: _openDayView,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthView(BuildContext context) {
    return _MonthCalendarView(
      onDaySelected: (day) {
        ref.read(publicSelectedDayProvider.notifier).setDay(day);
        setState(() => _showWeekView = true);
      },
    );
  }

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _MonthPickerSheet(
        onMonthSelected: (month) {
          final week = ref.read(publicSelectedWeekProvider);
          final newWeek = DateTime(week.year, month, 1);
          ref.read(publicSelectedWeekProvider.notifier).setWeek(newWeek);
          Navigator.pop(context);
        },
      ),
    );
  }

  /// Selecciona el día y abre la vista de día completa del calendario.
  void _openDayView(DateTime day) {
    ref.read(publicSelectedDayProvider.notifier).setDay(day);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PublicDayView()),
    );
  }
}

// ─────────────────────────────────────────────
// Selector de semana y vista en columnas (todos los días a la vez)
// ─────────────────────────────────────────────

class _MonthPickerSheet extends StatelessWidget {
  const _MonthPickerSheet({required this.onMonthSelected});

  final ValueChanged<int> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Seleccionar mes',
            style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge?.color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            childAspectRatio: 2.5,
            children: List.generate(12, (index) {
              return InkWell(
                onTap: () => onMonthSelected(index + 1),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    months[index],
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendarView extends ConsumerWidget {
  const _MonthCalendarView({required this.onDaySelected});

  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(publicSelectedDayProvider);
    final selectedWeek = ref.watch(publicSelectedWeekProvider);
    final eventsAsync = ref.watch(publicWeekEventsProvider);

    // Get the month of the selected week
    final monthStart = DateTime(selectedWeek.year, selectedWeek.month, 1);
    final monthEnd = DateTime(selectedWeek.year, selectedWeek.month + 1, 0);
    final firstWeekday = monthStart.weekday; // 1 = Monday
    final daysInMonth = monthEnd.day;

    return eventsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          child: AppBanner(
            message: 'Error cargando eventos: $e',
            type: BannerType.error,
            onDismiss: () => ref.invalidate(publicWeekEventsProvider),
          ),
        ),
      ),
      data: (allEvents) {
        // Group events by day (los multi-día aparecen en todos los días
        // que cubren dentro del mes).
        final eventsByDay = <int, List<PublicEventModel>>{};
        for (var day = 1; day <= daysInMonth; day++) {
          final dayDate = DateTime(selectedWeek.year, selectedWeek.month, day);
          for (final event in allEvents) {
            if (DateFormatter.rangeCoversDay(
              event.startTime,
              event.endTime,
              dayDate,
            )) {
              eventsByDay.putIfAbsent(day, () => []).add(event);
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Month header
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: context.textOnBg),
                    onPressed: () {
                      final newWeek = selectedWeek.subtract(const Duration(days: 30));
                      ref.read(publicSelectedWeekProvider.notifier).setWeek(newWeek);
                    },
                    tooltip: 'Mes anterior',
                  ),
                  Expanded(
                    child: Text(
                      '${_monthName(selectedWeek.month)} ${selectedWeek.year}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: context.textOnBg),
                    onPressed: () {
                      final newWeek = selectedWeek.add(const Duration(days: 30));
                      ref.read(publicSelectedWeekProvider.notifier).setWeek(newWeek);
                    },
                    tooltip: 'Mes siguiente',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Weekday headers
              Row(
                children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'].map((day) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              // Days grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: firstWeekday - 1 + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < firstWeekday - 1) {
                    return const SizedBox.shrink();
                  }

                  final day = index - (firstWeekday - 1) + 1;
                  final isToday = DateTime.now().year == selectedWeek.year &&
                      DateTime.now().month == selectedWeek.month &&
                      DateTime.now().day == day;
                  final isSelected = selectedDay.year == selectedWeek.year &&
                      selectedDay.month == selectedWeek.month &&
                      selectedDay.day == day;
                  final dayEvents = eventsByDay[day] ?? [];
                  final hasEvents = dayEvents.isNotEmpty;

                  return InkWell(
                    onTap: () => onDaySelected(DateTime(selectedWeek.year, selectedWeek.month, day)),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : isToday
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: AppColors.primary, width: 2)
                            : isToday
                                ? Border.all(color: AppColors.primary, width: 1)
                                : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : isToday
                                      ? AppColors.primary
                                      : context.textOnBg,
                              fontSize: 16,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (hasEvents) ...[
                            const SizedBox(height: 2),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: dayEvents.first.colorIndex < AppColors.calendarEventColors.length
                                    ? AppColors.calendarEventColors[dayEvents.first.colorIndex]
                                    : AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _monthName(int month) {
    const names = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return names[month - 1];
  }
}