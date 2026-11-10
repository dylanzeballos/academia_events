import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event_model.dart';
import '../../../../providers/events_provider.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_feedback.dart';

enum EventListFilter { day, active, archived }

class WeekEventList extends ConsumerStatefulWidget {
  const WeekEventList({
    super.key,
    required this.selectedDay,
    this.fallbackEvents = const [],
  });

  final DateTime selectedDay;
  final List<EventModel> fallbackEvents;

  @override
  ConsumerState<WeekEventList> createState() => _WeekEventListState();
}

class _WeekEventListState extends ConsumerState<WeekEventList> {
  EventListFilter _currentFilter = EventListFilter.active;

  @override
  Widget build(BuildContext context) {
    // Si tienes allEventsProvider o eventsProvider global, lo usamos.
    // En caso de carga, usamos fallbackEvents para evitar parpadeos.
    final eventsAsync = ref.watch(allEventsProvider);

    return eventsAsync.when(
      loading: () => const Center(child: LoadingIndicator()),
      error: (e, _) => AppErrorState(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(allEventsProvider),
      ),
      data: (allEvents) {
        final eventsToUse = allEvents.isNotEmpty ? allEvents : widget.fallbackEvents;
        final now = DateTime.now();

        // 1. Eventos solo del día seleccionado
        final dayEvents = eventsToUse.where((e) {
          return DateFormatter.rangeCoversDay(e.startTime, e.endTime, widget.selectedDay);
        }).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        // 2. Todos los eventos activos globales (que no han concluido)
        final activeEvents = eventsToUse
            .where((e) => !e.endTime.isBefore(now))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        // 3. Todos los eventos archivados globales (cuya fecha final ya pasó)
        final archivedEvents = eventsToUse
            .where((e) => e.endTime.isBefore(now))
            .toList()
          ..sort((a, b) => b.endTime.compareTo(a.endTime));

        final List<EventModel> currentList;
        switch (_currentFilter) {
          case EventListFilter.day:
            currentList = dayEvents;
            break;
          case EventListFilter.active:
            currentList = activeEvents;
            break;
          case EventListFilter.archived:
            currentList = archivedEvents;
            break;
        }

        final isArchivedTab = _currentFilter == EventListFilter.archived;

        return Column(
          children: [
            // ── Selector de 3 Pestañas (Del Día | Activos | Archivados) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  border: Border.all(color: context.divider.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _FilterTabButton(
                        label: 'Del día',
                        count: dayEvents.length,
                        isSelected: _currentFilter == EventListFilter.day,
                        onTap: () => setState(() => _currentFilter = EventListFilter.day),
                      ),
                    ),
                    Expanded(
                      child: _FilterTabButton(
                        label: 'Activos',
                        count: activeEvents.length,
                        isSelected: _currentFilter == EventListFilter.active,
                        onTap: () => setState(() => _currentFilter = EventListFilter.active),
                      ),
                    ),
                    Expanded(
                      child: _FilterTabButton(
                        label: 'Archivados',
                        count: archivedEvents.length,
                        isSelected: _currentFilter == EventListFilter.archived,
                        onTap: () => setState(() => _currentFilter = EventListFilter.archived),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Listado de Eventos ──
            Expanded(
              child: currentList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isArchivedTab
                                  ? Icons.history_rounded
                                  : (_currentFilter == EventListFilter.day
                                      ? Icons.calendar_today_outlined
                                      : Icons.event_busy_rounded),
                              size: 48,
                              color: context.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _emptyMessage(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.textOnBg.withValues(alpha: 0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                      itemCount: currentList.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _WeekEventListTile(
                        event: currentList[index],
                        isArchived: isArchivedTab,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  String _emptyMessage() {
    switch (_currentFilter) {
      case EventListFilter.day:
        return 'No hay eventos programados para ${DateFormatter.dayNumber(widget.selectedDay)} ${DateFormatter.shortMonth(widget.selectedDay)}';
      case EventListFilter.active:
        return 'No hay eventos activos disponibles';
      case EventListFilter.archived:
        return 'No hay eventos archivados en el historial';
    }
  }
}

class _FilterTabButton extends StatelessWidget {
  const _FilterTabButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.onPrimary : context.textMuted,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.onPrimary.withValues(alpha: 0.25)
                    : context.divider.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? AppColors.onPrimary : context.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekEventListTile extends StatelessWidget {
  const _WeekEventListTile({
    required this.event,
    this.isArchived = false,
  });

  final EventModel event;
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    final accent = isArchived
        ? context.textMuted
        : AppColors.colorForOrganization(event.organizationId);

    final genres = event.danceCategoryNames.isNotEmpty
        ? event.danceCategoryNames.take(2).join(' · ')
        : event.categoryName;
    final location =
        event.location?.locationName ??
        event.location?.city?.name ??
        event.location?.municipality?.name;

    return Opacity(
      opacity: isArchived ? 0.78 : 1.0,
      child: Card(
        margin: EdgeInsets.zero,
        color: context.cardBg,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          side: BorderSide(
            color: isArchived
                ? context.divider.withValues(alpha: 0.4)
                : context.divider,
          ),
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: event.coverImageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) =>
                                  _EventImageFallback(accent: accent),
                            )
                          : _EventImageFallback(accent: accent),
                      if (isArchived)
                        Container(
                          color: Colors.black.withValues(alpha: 0.28),
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.all(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CONCLUIDO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
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