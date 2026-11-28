// lib/features/calendar/week_calendar_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/public_urls.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/event_model.dart';
import '../../../data/models/public_event_data.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/public_events_provider.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../public/widgets/event_filters_bar.dart';
import 'widgets/event_preview_sheet.dart';
import 'widgets/week_column.dart';

enum _ScheduleView { agenda, week }

/// Horario semanal con una agenda tipo feed y una grilla semanal opcional.
class WeekCalendarView extends ConsumerStatefulWidget {
  const WeekCalendarView({super.key});

  @override
  ConsumerState<WeekCalendarView> createState() => _WeekCalendarViewState();
}

class _WeekCalendarViewState extends ConsumerState<WeekCalendarView> {
  _ScheduleView _view = _ScheduleView.agenda;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _selectDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    ref.read(selectedDayProvider.notifier).setDay(date);
    ref.read(selectedWeekProvider.notifier).setWeek(date);
  }

  void _shiftWeek(int delta) {
    final currentWeek = ref.read(selectedWeekProvider);
    final nextWeek = currentWeek.add(Duration(days: 7 * delta));
    ref.read(selectedWeekProvider.notifier).setWeek(nextWeek);

    final days = DateFormatter.weekDays(nextWeek);
    final currentDay = ref.read(selectedDayProvider);
    final index = (currentDay.weekday - 1).clamp(0, days.length - 1);
    ref.read(selectedDayProvider.notifier).setDay(days[index]);
  }

  void _goToday() {
    final now = DateTime.now();
    ref.read(selectedWeekProvider.notifier).setWeek(now);
    ref.read(selectedDayProvider.notifier).setDay(now);
  }

  Future<void> _refresh() async {
    ref.invalidate(weekEventsProvider);
    ref.invalidate(dayEventsProvider);
    ref.invalidate(organizationsWithEventsProvider);
    try {
      await ref.read(weekEventsProvider.future);
    } catch (_) {
      // El error se muestra en la vista.
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final eventsAsync = ref.watch(weekEventsProvider);
    final filters = ref.watch(eventFiltersProvider);
    final weekDays = DateFormatter.weekDays(selectedWeek);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, selectedWeek),
            _weekNavigator(context, weekDays),
            if (_view == _ScheduleView.agenda)
              _weekStrip(context, weekDays, selectedDay),
            _viewSwitcher(context),
            const _AcademyStrip(),
            const EventFiltersBar(),
            Divider(height: 1, color: context.divider),
            Expanded(
              child: eventsAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.paddingLarge),
                    child: AppErrorState(
                      message: 'No se pudo cargar el horario. $e',
                      onRetry: _refresh,
                    ),
                  ),
                ),
                data: (events) {
                  final dayEvents = _eventsForDay(events, selectedDay);
                  if (_view == _ScheduleView.week) {
                    return WeekColumns(
                      weekDays: weekDays,
                      events: events,
                      selectedDay: selectedDay,
                      heightPerHour: 48,
                      onDaySelected: _selectDay,
                      autoScrollToEarliest: true,
                      showNowLine: true,
                      showDayStrip: true,
                    );
                  }
                  return _AgendaView(
                    day: selectedDay,
                    events: dayEvents,
                    hasActiveFilters: filters.hasActiveFilters,
                    onRefresh: _refresh,
                    onClearFilters: () =>
                        ref.read(eventFiltersProvider.notifier).reset(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, DateTime selectedWeek) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Horario',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatter.capitalize(
                    DateFormatter.monthYear(selectedWeek),
                  ),
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar horario',
            icon: const Icon(Icons.refresh_rounded),
            color: context.textMuted,
            onPressed: _refresh,
          ),
          TextButton(
            onPressed: _goToday,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('Hoy'),
          ),
        ],
      ),
    );
  }

  Widget _weekNavigator(BuildContext context, List<DateTime> weekDays) {
    final first = weekDays.first;
    final last = weekDays.last;
    final range = first.month == last.month
        ? '${first.day} – ${last.day} de ${DateFormatter.capitalize(DateFormatter.monthYear(first))}'
        : '${first.day} ${DateFormatter.shortMonth(first)} – '
              '${last.day} ${DateFormatter.shortMonth(last)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Semana anterior',
            icon: const Icon(Icons.chevron_left_rounded),
            color: context.textOnBg,
            onPressed: () => _shiftWeek(-1),
          ),
          Expanded(
            child: Text(
              range,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Semana siguiente',
            icon: const Icon(Icons.chevron_right_rounded),
            color: context.textOnBg,
            onPressed: () => _shiftWeek(1),
          ),
        ],
      ),
    );
  }

  Widget _weekStrip(
    BuildContext context,
    List<DateTime> weekDays,
    DateTime selectedDay,
  ) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: SizedBox(
        height: 66,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              for (final day in weekDays)
                Expanded(
                  child: _DayChip(
                    day: day,
                    selected: _sameDay(day, selectedDay),
                    today: _sameDay(day, DateTime.now()),
                    onTap: () => _selectDay(day),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _viewSwitcher(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _ViewSwitcher(
              value: _view,
              onChanged: (value) => setState(() => _view = value),
            ),
          ),
        ],
      ),
    );
  }

  List<EventModel> _eventsForDay(List<EventModel> events, DateTime day) {
    return events
        .where(
          (event) =>
              DateFormatter.rangeCoversDay(event.startTime, event.endTime, day),
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = selected ? AppColors.onPrimary : context.textOnBg;
    final mutedColor = selected
        ? AppColors.onPrimary.withValues(alpha: 0.8)
        : context.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${DateFormatter.shortDay(day)} ${day.day}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : today
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : today
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : context.divider,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormatter.shortDay(day).substring(0, 2),
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: today
                        ? (selected ? AppColors.onPrimary : AppColors.primary)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.value, required this.onChanged});

  final _ScheduleView value;
  final ValueChanged<_ScheduleView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.surfaceHeader,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        children: [
          _tab(
            context,
            value: _ScheduleView.agenda,
            icon: Icons.view_agenda_outlined,
            label: 'Agenda',
          ),
          _tab(
            context,
            value: _ScheduleView.week,
            icon: Icons.calendar_view_week_outlined,
            label: 'Semana',
          ),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context, {
    required _ScheduleView value,
    required IconData icon,
    required String label,
  }) {
    final selected = this.value == value;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected ? context.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: context.textOnBg.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppColors.primary : context.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? context.textOnBg : context.textMuted,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademyStrip extends ConsumerWidget {
  const _AcademyStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgs =
        ref.watch(organizationsWithEventsProvider).value ??
        const <OrganizationWithEventCount>[];
    final memberOrgs = orgs
        .where((organization) => organization.hasMembership)
        .toList();
    if (memberOrgs.isEmpty) return const SizedBox.shrink();

    final selected = ref.watch(eventFiltersProvider).organizationId;
    final notifier = ref.read(eventFiltersProvider.notifier);

    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
        children: [
          _AcademyAvatar(
            label: 'Todas',
            icon: Icons.grid_view_rounded,
            selected: selected == null,
            onTap: () => notifier.setOrganizationId(null),
          ),
          for (final organization in memberOrgs) ...[
            const SizedBox(width: 10),
            _AcademyAvatar(
              label: organization.name,
              logoUrl: organization.logoUrl,
              selected: selected == organization.id,
              onTap: () => notifier.setOrganizationId(
                selected == organization.id ? null : organization.id,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AcademyAvatar extends StatelessWidget {
  const _AcademyAvatar({
    required this.label,
    required this.selected,
    required this.onTap,
    this.logoUrl,
    this.icon,
  });

  final String label;
  final String? logoUrl;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = organizationLogoUrl(logoUrl);
    final initial = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: SizedBox(
        width: 66,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.10),
                  border: Border.all(
                    color: selected ? AppColors.primary : context.divider,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: ClipOval(
                  child: url == null
                      ? Center(
                          child: icon != null
                              ? Icon(icon, size: 22, color: AppColors.primary)
                              : Text(
                                  initial,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.primary : context.textMuted,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaView extends StatelessWidget {
  const _AgendaView({
    required this.day,
    required this.events,
    required this.hasActiveFilters,
    required this.onRefresh,
    required this.onClearFilters,
  });

  final DateTime day;
  final List<EventModel> events;
  final bool hasActiveFilters;
  final Future<void> Function() onRefresh;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          children: [
            AppEmptyState(
              icon: hasActiveFilters
                  ? Icons.filter_alt_off_outlined
                  : Icons.event_busy_outlined,
              title: hasActiveFilters
                  ? 'No hay eventos con estos filtros'
                  : 'Sin eventos este día',
              message: hasActiveFilters
                  ? 'Hay eventos en la semana, pero no coinciden con los filtros activos.'
                  : 'Probá con otro día de la semana o deslizá para actualizar.',
              actionLabel: hasActiveFilters ? 'Limpiar filtros' : null,
              onAction: hasActiveFilters ? onClearFilters : null,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 28),
        itemCount: events.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _AgendaHeader(day: day, count: events.length);
          }
          final event = events[index - 1];
          return _AgendaEventRow(
            event: event,
            day: day,
            isLast: index == events.length,
          );
        },
      ),
    );
  }
}

class _AgendaHeader extends StatelessWidget {
  const _AgendaHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEEE d MMMM', 'es').format(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormatter.capitalize(label),
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            count == 1 ? '1 evento' : '$count eventos',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaEventRow extends StatelessWidget {
  const _AgendaEventRow({
    required this.event,
    required this.day,
    required this.isLast,
  });

  final EventModel event;
  final DateTime day;
  final bool isLast;

  String _hhmm(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _startLabel() {
    if (event.startTime.isBefore(day)) return '00:00';
    return _hhmm(event.startTime);
  }

  String _endLabel() {
    final nextDay = DateTime(
      day.year,
      day.month,
      day.day,
    ).add(const Duration(days: 1));
    if (!event.endTime.isBefore(nextDay)) return '24:00';
    return _hhmm(event.endTime);
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.colorForOrganization(event.organizationId);
    final intersectsNextDay =
        !_sameDay(event.startTime, day) || !_sameDay(event.endTime, day);

    return _AgendaEventCard(
      event: event,
      color: color,
      startLabel: _startLabel(),
      endLabel: _endLabel(),
      intersectsNextDay: intersectsNextDay,
    );
  }
}

class _AgendaEventCard extends StatelessWidget {
  const _AgendaEventCard({
    required this.event,
    required this.color,
    required this.startLabel,
    required this.endLabel,
    required this.intersectsNextDay,
  });

  final EventModel event;
  final Color color;
  final String startLabel;
  final String endLabel;
  final bool intersectsNextDay;

  @override
  Widget build(BuildContext context) {
    final price = event.startingPrice;
    final location =
        event.location?.locationName ??
        event.location?.city?.name ??
        event.location?.municipality?.name ??
        event.location?.addressLine1;
    final genres = event.danceCategoryNames.isNotEmpty
        ? event.danceCategoryNames.take(2).join(' · ')
        : event.categoryName;

    return Semantics(
      button: true,
      label:
          '${event.title}, ${event.organizationName}'
          '${price == null ? '' : ', desde Bs ${price.toInt()}'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => EventPreviewSheet.show(context, event),
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          child: Card(
            margin: EdgeInsets.zero,
            color: context.cardBg,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              side: BorderSide(color: context.divider),
            ),
            child: SizedBox(
              height: 144,
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    height: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (event.coverImageUrl != null &&
                            event.coverImageUrl!.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: event.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                _EventAgendaImageFallback(color: color),
                          )
                        else
                          _EventAgendaImageFallback(color: color),
                        if (intersectsNextDay)
                          Positioned(
                            left: 6,
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: context.scaffoldBg.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Continúa',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
                              height: 1.15,
                            ),
                          ),
                          if (event.organizationName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              event.organizationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const Spacer(),
                          _EventAgendaInfoRow(
                            icon: Icons.schedule_rounded,
                            text: '$startLabel–$endLabel',
                          ),
                          if (location != null &&
                              location.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            _EventAgendaInfoRow(
                              icon: Icons.place_outlined,
                              text: location,
                            ),
                          ],
                          if (genres != null && genres.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            _EventAgendaInfoRow(
                              icon: Icons.sell_outlined,
                              text: genres,
                            ),
                          ],
                          if (price != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Desde Bs ${price.toInt()}',
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventAgendaInfoRow extends StatelessWidget {
  const _EventAgendaInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: context.textMuted),
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

class _EventAgendaImageFallback extends StatelessWidget {
  const _EventAgendaImageFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color.withValues(alpha: 0.22),
      child: Center(child: Icon(Icons.event_rounded, size: 38, color: color)),
    );
  }
}
