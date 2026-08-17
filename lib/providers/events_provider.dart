import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/event_model.dart';
import '../data/repositories/events_repository.dart';

final eventsRepositoryProvider = Provider<IEventsRepository>((ref) {
  return const EventsRepository();
});

final classesRepositoryProvider = Provider<IClassesRepository>((ref) {
  return const ClassesRepository();
});

class SelectedWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  void setWeek(DateTime week) => state = week;
  void nextWeek() => state = state.add(const Duration(days: 7));
  void previousWeek() => state = state.subtract(const Duration(days: 7));
}

final selectedWeekProvider =
    NotifierProvider<SelectedWeekNotifier, DateTime>(() {
  return SelectedWeekNotifier();
});

class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDay(DateTime day) => state = day;
}

final selectedDayProvider =
    NotifierProvider<SelectedDayNotifier, DateTime>(() {
  return SelectedDayNotifier();
});

final weekEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final week = ref.watch(selectedWeekProvider);
  final eventsRepo = ref.watch(eventsRepositoryProvider);
  final classesRepo = ref.watch(classesRepositoryProvider);

  final events = await eventsRepo.fetchWeekEvents(week);
  final classes = await classesRepo.fetchWeekClasses(week);

  final all = [...events, ...classes];
  all.sort((a, b) => a.startTime.compareTo(b.startTime));

  return all;
});

final dayEventsProvider = Provider<List<EventModel>>((ref) {
  final events = ref.watch(weekEventsProvider).value ?? [];
  final day = ref.watch(selectedDayProvider);
  return events.where((e) {
    return e.startTime.year == day.year &&
        e.startTime.month == day.month &&
        e.startTime.day == day.day;
  }).toList();
});

final academyClassesProvider =
    FutureProvider.family<List<EventModel>, String>((ref, organizationId) async {
  final week = ref.watch(selectedWeekProvider);
  final repo = ref.watch(classesRepositoryProvider);
  final all = await repo.fetchWeekClasses(week);
  return all.where((e) => e.organizationId == organizationId).toList();
});
