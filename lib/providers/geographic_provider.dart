import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/geographic_model.dart';
import '../data/repositories/geographic_repository.dart';

final geographicRepositoryProvider = Provider<IGeographicRepository>((ref) {
  return const GeographicRepository();
});

// ─── Departments ───────────────────────────────────

final departmentsProvider =
    FutureProvider<List<DepartmentModel>>((ref) async {
  final repo = ref.watch(geographicRepositoryProvider);
  return repo.fetchDepartments();
});

// ─── Provinces (depend on selected department) ─────

class SelectedDepartmentIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedDepartmentIdProvider =
    NotifierProvider<SelectedDepartmentIdNotifier, String?>(
  () => SelectedDepartmentIdNotifier(),
);

final provincesProvider =
    FutureProvider<List<ProvinceModel>>((ref) async {
  final deptId = ref.watch(selectedDepartmentIdProvider);
  if (deptId == null) return [];
  final repo = ref.watch(geographicRepositoryProvider);
  return repo.fetchProvinces(deptId);
});

// ─── Municipalities (depend on selected province) ──

class SelectedProvinceIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedProvinceIdProvider =
    NotifierProvider<SelectedProvinceIdNotifier, String?>(
  () => SelectedProvinceIdNotifier(),
);

final municipalitiesProvider =
    FutureProvider<List<MunicipalityModel>>((ref) async {
  final provId = ref.watch(selectedProvinceIdProvider);
  if (provId == null) return [];
  final repo = ref.watch(geographicRepositoryProvider);
  return repo.fetchMunicipalities(provId);
});

// ─── Cities (depend on selected municipality) ──────

class SelectedMunicipalityIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedMunicipalityIdProvider =
    NotifierProvider<SelectedMunicipalityIdNotifier, String?>(
  () => SelectedMunicipalityIdNotifier(),
);

final citiesProvider = FutureProvider<List<CityModel>>((ref) async {
  final muniId = ref.watch(selectedMunicipalityIdProvider);
  if (muniId == null) return [];
  final repo = ref.watch(geographicRepositoryProvider);
  return repo.fetchCities(muniId);
});

// ─── Selected city ─────────────────────────────────

class SelectedCityIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedCityIdProvider =
    NotifierProvider<SelectedCityIdNotifier, String?>(
  () => SelectedCityIdNotifier(),
);

// ─── Reset helpers ─────────────────────────────────

void resetGeographicSelections(WidgetRef ref) {
  ref.read(selectedDepartmentIdProvider.notifier).clear();
  ref.read(selectedProvinceIdProvider.notifier).clear();
  ref.read(selectedMunicipalityIdProvider.notifier).clear();
  ref.read(selectedCityIdProvider.notifier).clear();
}

void resetProvincesAndBelow(WidgetRef ref) {
  ref.read(selectedProvinceIdProvider.notifier).clear();
  ref.read(selectedMunicipalityIdProvider.notifier).clear();
  ref.read(selectedCityIdProvider.notifier).clear();
}

void resetMunicipalitiesAndBelow(WidgetRef ref) {
  ref.read(selectedMunicipalityIdProvider.notifier).clear();
  ref.read(selectedCityIdProvider.notifier).clear();
}
