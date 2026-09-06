import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../providers/public_events_provider.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../widgets/public_week_timeline.dart';

/// Vista pública de un solo día (estilo Google Calendar).
///
/// Se abre desde la vista de semana al tocar un día. Muestra el timeline
/// vertical de ese día con la navegación a día anterior/siguiente.
class PublicDayView extends ConsumerWidget {
  const PublicDayView({super.key});

  void _changeDay(WidgetRef ref, int days) {
    final current = ref.read(publicSelectedDayProvider);
    final newDay = current.add(Duration(days: days));
    ref.read(publicSelectedDayProvider.notifier).setDay(newDay);

    // Si se cruza la frontera de la semana, mueve también la semana para que
    // la lista de eventos se vuelva a cargar con la correcta.
    final week = ref.read(publicSelectedWeekProvider);
    final weekMonday = week.subtract(Duration(days: week.weekday - 1));
    final newMonday = newDay.subtract(Duration(days: newDay.weekday - 1));
    final sameWeek = weekMonday.year == newMonday.year &&
        weekMonday.month == newMonday.month &&
        weekMonday.day == newMonday.day;
    if (!sameWeek) {
      ref.read(publicSelectedWeekProvider.notifier).setWeek(newDay);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(publicSelectedDayProvider);
    final eventsAsync = ref.watch(publicWeekEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormatter.fullDate(selectedDay)),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeDay(ref, -1),
            tooltip: 'Día anterior',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeDay(ref, 1),
            tooltip: 'Día siguiente',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: eventsAsync.when(
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
          final dayEvents = allEvents
              .where((e) => DateFormatter.rangeCoversDay(
                    e.startTime,
                    e.endTime,
                    selectedDay,
                  ))
              .toList();

          if (dayEvents.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 56,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sin eventos el ${DateFormatter.fullDate(selectedDay)}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return PublicWeekTimeline(
            events: dayEvents,
            date: selectedDay,
          );
        },
      ),
    );
  }
}