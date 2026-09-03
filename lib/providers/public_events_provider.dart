import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/public_event_model.dart';
import '../data/models/public_event_data.dart';
import '../data/models/event_filter_state.dart';
import '../data/models/paginated_result.dart';
import '../data/models/geographic_model.dart';
import '../data/models/event_category_model.dart';
import '../data/models/dance_category_model.dart';
import '../data/repositories/public_events_repository.dart';
import '../data/services/public_events_service.dart';

// ─── PUBLIC CALENDAR PROVIDERS ───

class PublicSelectedWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  void setWeek(DateTime week) => state = week;
  void nextWeek() => state = state.add(const Duration(days: 7));
  void previousWeek() => state = state.subtract(const Duration(days: 7));
}

final publicSelectedWeekProvider = NotifierProvider<PublicSelectedWeekNotifier, DateTime>(
  () => PublicSelectedWeekNotifier(),
);

class PublicSelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDay(DateTime day) => state = day;
}

final publicSelectedDayProvider = NotifierProvider<PublicSelectedDayNotifier, DateTime>(
  () => PublicSelectedDayNotifier(),
);

final publicWeekEventsProvider = FutureProvider<List<PublicEventModel>>((ref) async {
  final week = ref.watch(publicSelectedWeekProvider);
  final repo = ref.watch(publicEventsRepositoryProvider);

  final startOfWeek = week;
  final endOfWeek = week.add(const Duration(days: 7));

  final result = await repo.searchEvents(
    const EventFilterState().copyWith(
      dateFrom: startOfWeek,
      dateTo: endOfWeek,
      sortBy: EventSortBy.dateAsc,
    ),
  );

  return result.items;
});

final publicEventsServiceProvider = Provider<PublicEventsService>((ref) {
  return const PublicEventsService();
});

final publicEventsRepositoryProvider = Provider<IPublicEventsRepository>((ref) {
  final service = ref.watch(publicEventsServiceProvider);
  return PublicEventsRepository(service: service);
});

class EventFiltersNotifier extends Notifier<EventFilterState> {
  @override
  EventFilterState build() => const EventFilterState();

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query, page: 1);
  
  void toggleCategory(String categoryId) {
    final ids = [...state.categoryIds];
    if (ids.contains(categoryId)) {
      ids.remove(categoryId);
    } else {
      ids.add(categoryId);
    }
    state = state.copyWith(categoryIds: ids, page: 1);
  }

  void toggleDanceCategory(String danceCategoryId) {
    final ids = [...state.danceCategoryIds];
    if (ids.contains(danceCategoryId)) {
      ids.remove(danceCategoryId);
    } else {
      ids.add(danceCategoryId);
    }
    state = state.copyWith(danceCategoryIds: ids, page: 1);
  }

  void setLocation({
    String? departmentId,
    String? provinceId,
    String? municipalityId,
    String? cityId,
  }) {
    state = state.copyWith(
      departmentId: departmentId,
      provinceId: provinceId,
      municipalityId: municipalityId,
      cityId: cityId,
      page: 1,
    );
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(dateFrom: from, dateTo: to, page: 1);
  }

  void setPriceRange(double? min, double? max) {
    state = state.copyWith(priceMin: min, priceMax: max, page: 1);
  }

  void setSortBy(EventSortBy sortBy) {
    state = state.copyWith(sortBy: sortBy, page: 1);
  }

  void nextPage() => state = state.nextPage();
  void previousPage() => state = state.previousPage();
  void goToPage(int page) => state = state.copyWith(page: page);
  void reset() => state = state.reset();
  void clearLocation() => state = state.copyWith(clearLocation: true, page: 1);
  void clearDate() => state = state.copyWith(clearDate: true, page: 1);
  void clearPrice() => state = state.copyWith(clearPrice: true, page: 1);

  void setCategoryIds(List<String> ids) {
    state = state.copyWith(categoryIds: ids, page: 1);
  }

  void setDanceCategoryIds(List<String> ids) {
    state = state.copyWith(danceCategoryIds: ids, page: 1);
  }
}

final eventFiltersProvider = NotifierProvider<EventFiltersNotifier, EventFilterState>(
  () => EventFiltersNotifier(),
);

final publicEventsProvider = FutureProvider<PaginatedResult<PublicEventModel>>((ref) async {
  final filter = ref.watch(eventFiltersProvider);
  final repo = ref.watch(publicEventsRepositoryProvider);
  return repo.searchEvents(filter);
});

final publicEventDetailProvider = FutureProvider.family<PublicEventModel?, String>((ref, eventId) async {
  final repo = ref.watch(publicEventsRepositoryProvider);
  return repo.getEventById(eventId);
});

final organizationsWithEventsProvider = FutureProvider<List<OrganizationWithEventCount>>((ref) async {
  final repo = ref.watch(publicEventsRepositoryProvider);
  return repo.getOrganizationsWithEvents(limit: 10);
});

final publicEventCategoriesProvider = FutureProvider<List<EventCategoryModel>>((ref) async {
  final repo = ref.watch(publicEventsRepositoryProvider);
  return repo.getEventCategories();
});

final publicDanceCategoriesProvider = FutureProvider<List<DanceCategoryModel>>((ref) async {
  final repo = ref.watch(publicEventsRepositoryProvider);
  return repo.getDanceCategories();
});

final publicDepartmentsProvider = FutureProvider<List<DepartmentModel>>((ref) async {
  final repo = ref.watch(publicEventsRepositoryProvider);
  return repo.getDepartments();
});

class SelectedDepartmentIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedDepartmentIdProvider = NotifierProvider<SelectedDepartmentIdNotifier, String?>(
  () => SelectedDepartmentIdNotifier(),
);

final publicProvincesProvider = FutureProvider<List<ProvinceModel>>((ref) async {
  final deptId = ref.watch(selectedDepartmentIdProvider);
  if (deptId == null) return [];
  final repo = ref.watch(publicEventsRepositoryProvider);
  return repo.getProvinces(deptId);
});

class SelectedProvinceIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedProvinceIdProvider = NotifierProvider<SelectedProvinceIdNotifier, String?>(
  () => SelectedProvinceIdNotifier(),
);

final publicMunicipalitiesProvider = FutureProvider<List<MunicipalityModel>>((ref) async {
  final provId = ref.watch(selectedProvinceIdProvider);
  if (provId == null) return [];
  final repo = ref.watch(publicEventsRepositoryProvider);
  return repo.getMunicipalities(provId);
});

class SelectedMunicipalityIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedMunicipalityIdProvider = NotifierProvider<SelectedMunicipalityIdNotifier, String?>(
  () => SelectedMunicipalityIdNotifier(),
);

final publicCitiesProvider = FutureProvider<List<CityModel>>((ref) async {
  final muniId = ref.watch(selectedMunicipalityIdProvider);
  if (muniId == null) return [];
  final repo = ref.watch(publicEventsRepositoryProvider);
  return repo.getCities(muniId);
});

class SelectedCityIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedCityIdProvider = NotifierProvider<SelectedCityIdNotifier, String?>(
  () => SelectedCityIdNotifier(),
);

void resetPublicGeographicSelections(WidgetRef ref) {
  ref.read(selectedDepartmentIdProvider.notifier).clear();
  ref.read(selectedProvinceIdProvider.notifier).clear();
  ref.read(selectedMunicipalityIdProvider.notifier).clear();
  ref.read(selectedCityIdProvider.notifier).clear();
}

void resetPublicProvincesAndBelow(WidgetRef ref) {
  ref.read(selectedProvinceIdProvider.notifier).clear();
  ref.read(selectedMunicipalityIdProvider.notifier).clear();
  ref.read(selectedCityIdProvider.notifier).clear();
}

void resetPublicMunicipalitiesAndBelow(WidgetRef ref) {
  ref.read(selectedMunicipalityIdProvider.notifier).clear();
  ref.read(selectedCityIdProvider.notifier).clear();
}