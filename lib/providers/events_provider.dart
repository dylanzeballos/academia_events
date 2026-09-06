import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/event_filter_state.dart';
import '../data/models/event_model.dart';
import '../data/repositories/events_repository.dart';
import '../data/services/events_service.dart';
import '../data/services/locations_service.dart';
import 'organization_provider.dart';
import 'public_events_provider.dart' show eventFiltersProvider;

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
    return DateTime(now.year, now.month, now.day);
  }

  void setWeek(DateTime week) =>
      state = DateTime(week.year, week.month, week.day);
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

/// Los eventos del calendario respetan los filtros activos de la barra
/// (`eventFiltersProvider`): categorías, categorías de baile, rango de fechas
/// y precio se aplican a los eventos; las clases solo se filtran por fecha.
final weekEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final week = ref.watch(selectedWeekProvider);
  final filter = ref.watch(eventFiltersProvider);
  final eventsRepo = ref.watch(eventsRepositoryProvider);
  final classesRepo = ref.watch(classesRepositoryProvider);

  final events = await eventsRepo.fetchWeekEvents(week);
  final classes = await classesRepo.fetchWeekClasses(week);

  final filteredEvents = events
      .where((e) => _scheduleEventMatches(e, filter, isClass: false))
      .toList();
  final filteredClasses = classes
      .where((e) => _scheduleEventMatches(e, filter, isClass: true))
      .toList();

  final all = [...filteredEvents, ...filteredClasses];
  all.sort((a, b) => a.startTime.compareTo(b.startTime));

  return all;
});

/// ¿El evento/la clase satisface los filtros activos de la barra?
///
/// Los filtros de categoría y precio se aplican solo a eventos (las clases
/// no tienen categorías ni precios por sesión). El rango de fechas aplica a
/// ambos.
bool _scheduleEventMatches(EventModel e, EventFilterState f,
    {required bool isClass}) {
  if (!isClass) {
    if (f.categoryIds.isNotEmpty &&
        (e.categoryId == null || !f.categoryIds.contains(e.categoryId))) {
      return false;
    }
    if (f.danceCategoryIds.isNotEmpty &&
        !e.danceCategoryIds.any(f.danceCategoryIds.contains)) {
      return false;
    }
    final price = e.startingPrice;
    if (f.priceMin != null || f.priceMax != null) {
      if (price == null) return false;
      if (f.priceMin != null && price < f.priceMin!) return false;
      if (f.priceMax != null && price > f.priceMax!) return false;
    }
  }

  final from = f.dateFrom;
  if (from != null && e.endTime.isBefore(from)) return false;
  final to = f.dateTo;
  if (to != null && e.startTime.isAfter(to)) return false;

  return true;
}

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

/// Clases próximas (desde ahora, próximos 7 días) de una organización.
///
/// Toma la semana actual y la siguiente para que las clases que caen a
/// principios de la semana que viene (cuando hoy es casi fin de semana) no se
/// pierdan.
final organizationUpcomingClassesProvider =
    FutureProvider.family<List<EventModel>, String>((ref, organizationId) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final horizon = today.add(const Duration(days: 7));

      final repo = ref.watch(classesRepositoryProvider);
      final candidates = <EventModel>[
        ...await repo.fetchWeekClasses(now),
        ...await repo.fetchWeekClasses(now.add(const Duration(days: 7))),
      ];

      final upcoming = candidates
          .where((e) =>
              e.organizationId == organizationId &&
              !e.endTime.isBefore(today) &&
              !e.startTime.isAfter(horizon))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return upcoming;
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