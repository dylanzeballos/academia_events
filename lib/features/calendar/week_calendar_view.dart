import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/event_model.dart';
import '../../../providers/events_provider.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../public/widgets/event_filters_bar.dart';
import '../public/widgets/organization_carousel.dart';
import 'widgets/week_column.dart';

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
    final weekDays = DateFormatter.consecutiveDays(selectedWeek, 7);

    if (_focusedDay != null && !_showList) {
      return eventsAsync.when(
        loading: () => const Scaffold(body: LoadingIndicator()),
        error: (e, _) => Scaffold(
          body: AppErrorState(message: friendlyError(e)),
        ),
        data: (allEvents) => _DayView(
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
                    return _WeekEventList(events: allEvents);
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: const OrganizationCarouselSearchBar(),
                        ),
                        SizedBox(
                          height: 160,
                          child: OrganizationCarousel(
                            height: 160,
                            expandedHeight: 160,
                            autoPlayInterval: const Duration(seconds: 4),
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

class _DayView extends StatelessWidget {
  const _DayView({
    required this.day,
    required this.events,
    required this.onClose,
    required this.onChanged,
  });

  final DateTime day;
  final List<EventModel> events;
  final VoidCallback onClose;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final dayEvents = events
        .where((e) => DateFormatter.rangeCoversDay(e.startTime, e.endTime, day))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a la semana',
          icon: const Icon(Icons.arrow_back),
          onPressed: onClose,
        ),
        title: Text(
          DateFormatter.capitalize(DateFormatter.fullDate(day)),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Día anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(day.subtract(const Duration(days: 1))),
          ),
          IconButton(
            tooltip: 'Día siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(day.add(const Duration(days: 1))),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              dayEvents.isEmpty
                  ? 'Sin eventos'
                  : '${dayEvents.length} '
                      '${dayEvents.length == 1 ? 'evento' : 'eventos'}',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: WeekColumns(
              weekDays: [day],
              events: events,
              selectedDay: day,
              heightPerHour: 60,
              autoScrollToEarliest: dayEvents.isNotEmpty,
              showNowLine: true,
              onDaySelected: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekEventList extends StatelessWidget {
  const _WeekEventList({required this.events});

  final List<EventModel> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          'No hay eventos para esta semana',
          style: TextStyle(color: context.textOnBg.withValues(alpha: 0.7)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _WeekEventListTile(event: events[index]),
    );
  }
}

class _WeekEventListTile extends StatelessWidget {
  const _WeekEventListTile({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.colorForOrganization(event.organizationId);
    final genres = event.danceCategoryNames.isNotEmpty
        ? event.danceCategoryNames.take(2).join(' · ')
        : event.categoryName;
    final location =
        event.location?.locationName ??
        event.location?.city?.name ??
        event.location?.municipality?.name;

    return Card(
      margin: EdgeInsets.zero,
      color: context.cardBg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        onTap: () => context.push('${AppRoutes.eventDetail}/${event.id}'),
        child: SizedBox(
          height: 144,
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: double.infinity,
                child:
                    event.coverImageUrl != null &&
                        event.coverImageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: event.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            _EventImageFallback(accent: accent),
                      )
                    : _EventImageFallback(accent: accent),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (event.organizationName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          event.organizationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const Spacer(),
                      _EventInfoLine(
                        icon: Icons.calendar_today_outlined,
                        text: DateFormatter.fullDate(event.startTime),
                      ),
                      const SizedBox(height: 3),
                      _EventInfoLine(
                        icon: Icons.schedule_outlined,
                        text: DateFormatter.timeRange(
                          event.startTime,
                          event.endTime,
                        ),
                      ),
                      if (location != null && location.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _EventInfoLine(
                          icon: Icons.location_on_outlined,
                          text: location,
                        ),
                      ],
                      if (genres != null && genres.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          genres,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textOnBg.withValues(alpha: 0.62),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventInfoLine extends StatelessWidget {
  const _EventInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textOnBg.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventImageFallback extends StatelessWidget {
  const _EventImageFallback({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: accent.withValues(alpha: 0.22),
      child: Center(child: Icon(Icons.event_rounded, size: 38, color: accent)),
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
            onPressed: () => ref
                .read(selectedWeekProvider.notifier)
                .setWeek(DateTime.now()),
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
