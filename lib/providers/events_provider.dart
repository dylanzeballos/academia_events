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

/// Carga todos los departamentos
final departmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(locationsServiceProvider);
  return service.fetchDepartments();
});

/// Carga las provincias según el ID del Departamento seleccionado
final provincesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, departmentId) async {
  if (departmentId.isEmpty) return [];
  final service = ref.watch(locationsServiceProvider);
  return service.fetchProvinces(departmentId);
});

/// Carga los municipios según el ID de la Provincia seleccionada
final municipalitiesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  if (provinceId.isEmpty) return [];
  final service = ref.watch(locationsServiceProvider);
  return service.fetchMunicipalities(provinceId);
});

/// Carga las ciudades según el ID del Municipio seleccionado
final citiesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, municipalityId) async {
  if (municipalityId.isEmpty) return [];
  final service = ref.watch(locationsServiceProvider);
  return service.fetchCities(municipalityId);
});