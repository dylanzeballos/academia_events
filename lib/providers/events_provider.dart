import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/event_model.dart';
import '../data/repositories/events_repository.dart';
import '../data/services/events_service.dart';
import '../data/services/locations_service.dart';
import 'organization_provider.dart';

// ─── SERVICES PROVIDERS ───
final eventsServiceProvider = Provider<EventsService>((ref) {
  return const EventsService();
});

final locationsServiceProvider = Provider<LocationsService>((ref) {
  return const LocationsService();
});

// ─── REPOSITORY PROVIDERS ───
final eventsRepositoryProvider = Provider<IEventsRepository>((ref) {
  final service = ref.watch(eventsServiceProvider);
  return EventsRepository(service: service);
});

final classesRepositoryProvider = Provider<IClassesRepository>((ref) {
  final service = ref.watch(eventsServiceProvider);
  return ClassesRepository(service: service);
});

// ─── NOTIFIERS DE FECHA ───
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

final selectedWeekProvider = NotifierProvider<SelectedWeekNotifier, DateTime>(
  () => SelectedWeekNotifier(),
);

class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDay(DateTime day) => state = day;
}

final selectedDayProvider = NotifierProvider<SelectedDayNotifier, DateTime>(
  () => SelectedDayNotifier(),
);

// ─── FUTURE / COMPUTED PROVIDERS ───
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

final academyClassesProvider = FutureProvider.family<List<EventModel>, String>((
  ref,
  organizationId,
) async {
  final week = ref.watch(selectedWeekProvider);
  final repo = ref.watch(classesRepositoryProvider);
  final all = await repo.fetchWeekClasses(week);
  return all.where((e) => e.organizationId == organizationId).toList();
});

final orgEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final orgId = ref.watch(selectedOrganizationIdProvider);
  if (orgId == null) return [];

  final repo = ref.watch(eventsRepositoryProvider);
  return repo.fetchOrganizationEvents(orgId);
});

// ─── LOCATION PROVIDERS (EN CASCADA) ───

final departmentsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(locationsServiceProvider);
  return service.fetchDepartments();
});

final provincesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      departmentId,
    ) async {
      if (departmentId.isEmpty) return [];
      final service = ref.watch(locationsServiceProvider);
      return service.fetchProvinces(departmentId);
    });

final municipalitiesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      provinceId,
    ) async {
      if (provinceId.isEmpty) return [];
      final service = ref.watch(locationsServiceProvider);
      return service.fetchMunicipalities(provinceId);
    });

final citiesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      municipalityId,
    ) async {
      if (municipalityId.isEmpty) return [];
      final service = ref.watch(locationsServiceProvider);
      return service.fetchCities(municipalityId);
    });

final allEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.fetchAllEvents();
});

final eventDetailProvider = FutureProvider.family<EventModel, String>((
  ref,
  eventId,
) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.fetchEventById(eventId);
});

// ─── CREACIÓN DE EVENTO (CON TICKETS) ───

class CreateEventState {
  const CreateEventState({this.isLoading = false, this.error});
  final bool isLoading;
  final String? error;

  CreateEventState copyWith({bool? isLoading, String? error}) {
    return CreateEventState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CreateEventNotifier extends Notifier<CreateEventState> {
  @override
  CreateEventState build() => const CreateEventState();

  Future<bool> createFullEvent({
    required Map<String, dynamic> eventData,
    required Map<String, dynamic> locationData,
    List<Map<String, dynamic>>? ticketTypesData,
    Uint8List? bannerBytes,
    Uint8List? qrBytes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(eventsRepositoryProvider);
      await repo.createFullEvent(
        eventData: eventData,
        locationData: locationData,
        ticketTypesData: ticketTypesData,
        bannerBytes: bannerBytes,
        qrBytes: qrBytes,
      );

      ref.invalidate(allEventsProvider);
      ref.invalidate(weekEventsProvider);
      ref.invalidate(orgEventsProvider);

      state = const CreateEventState();
      return true;
    } catch (e) {
      state = CreateEventState(error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith();
}

final createEventProvider =
    NotifierProvider<CreateEventNotifier, CreateEventState>(() {
  return CreateEventNotifier();
});