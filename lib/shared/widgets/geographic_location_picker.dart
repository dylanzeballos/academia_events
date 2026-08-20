import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/theme_extensions.dart';
import '../../data/models/geographic_model.dart';
import '../../providers/geographic_provider.dart';

/// Widget de selects dependientes para seleccionar ubicacion geografica.
/// Jerarquia: Department -> Province -> Municipality -> City
class GeographicLocationPicker extends ConsumerStatefulWidget {
  const GeographicLocationPicker({
    super.key,
    this.initialCityId,
    this.onCityChanged,
  });

  final String? initialCityId;
  final ValueChanged<String?>? onCityChanged;

  @override
  ConsumerState<GeographicLocationPicker> createState() =>
      _GeographicLocationPickerState();
}

class _GeographicLocationPickerState
    extends ConsumerState<GeographicLocationPicker> {
  @override
  void initState() {
    super.initState();
    if (widget.initialCityId != null) {
      _resolveInitialCity();
    }
  }

  Future<void> _resolveInitialCity() async {
    final repo = ref.read(geographicRepositoryProvider);
    final chain = await repo.resolveCityChain(widget.initialCityId!);
    if (chain != null && mounted) {
      ref.read(selectedDepartmentIdProvider.notifier).select(chain['departmentId']);
      ref.read(selectedProvinceIdProvider.notifier).select(chain['provinceId']);
      ref.read(selectedMunicipalityIdProvider.notifier).select(chain['municipalityId']);
      ref.read(selectedCityIdProvider.notifier).select(widget.initialCityId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(departmentsProvider);
    final provinces = ref.watch(provincesProvider);
    final municipalities = ref.watch(municipalitiesProvider);
    final cities = ref.watch(citiesProvider);

    final selectedDept = ref.watch(selectedDepartmentIdProvider);
    final selectedProv = ref.watch(selectedProvinceIdProvider);
    final selectedMuni = ref.watch(selectedMunicipalityIdProvider);
    final selectedCity = ref.watch(selectedCityIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Department
        departments.when(
          loading: () => const _DropdownSkeleton(label: 'Departamento'),
          error: (e, _) => Text('Error: $e',
              style: const TextStyle(color: AppColors.error, fontSize: 12)),
          data: (items) => _GeoDropdown<DepartmentModel>(
            label: 'Departamento',
            icon: Icons.location_city_outlined,
            items: items,
            selectedId: selectedDept,
            itemToId: (d) => d.id,
            itemToLabel: (d) => d.name,
            onChanged: (id) {
              ref.read(selectedDepartmentIdProvider.notifier).select(id);
              resetProvincesAndBelow(ref);
            },
          ),
        ),
        const SizedBox(height: 12),

        // Province
        if (selectedDept != null)
          provinces.when(
            loading: () => const _DropdownSkeleton(label: 'Provincia'),
            error: (e, _) => Text('Error: $e',
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
            data: (items) => _GeoDropdown<ProvinceModel>(
              label: 'Provincia',
              icon: Icons.map_outlined,
              items: items,
              selectedId: selectedProv,
              itemToId: (p) => p.id,
              itemToLabel: (p) => p.name,
              onChanged: (id) {
                ref.read(selectedProvinceIdProvider.notifier).select(id);
                resetMunicipalitiesAndBelow(ref);
              },
            ),
          ),
        const SizedBox(height: 12),

        // Municipality
        if (selectedProv != null)
          municipalities.when(
            loading: () => const _DropdownSkeleton(label: 'Municipio'),
            error: (e, _) => Text('Error: $e',
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
            data: (items) => _GeoDropdown<MunicipalityModel>(
              label: 'Municipio',
              icon: Icons.location_on_outlined,
              items: items,
              selectedId: selectedMuni,
              itemToId: (m) => m.id,
              itemToLabel: (m) => m.name,
              onChanged: (id) {
                ref.read(selectedMunicipalityIdProvider.notifier).select(id);
                ref.read(selectedCityIdProvider.notifier).clear();
              },
            ),
          ),
        const SizedBox(height: 12),

        // City
        if (selectedMuni != null)
          cities.when(
            loading: () => const _DropdownSkeleton(label: 'Ciudad'),
            error: (e, _) => Text('Error: $e',
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
            data: (items) => _GeoDropdown<CityModel>(
              label: 'Ciudad',
              icon: Icons.home_outlined,
              items: items,
              selectedId: selectedCity,
              itemToId: (c) => c.id,
              itemToLabel: (c) => c.name,
              onChanged: (id) {
                ref.read(selectedCityIdProvider.notifier).select(id);
                widget.onCityChanged?.call(id);
              },
            ),
          ),
      ],
    );
  }
}

class _GeoDropdown<T> extends StatelessWidget {
  const _GeoDropdown({
    required this.label,
    required this.icon,
    required this.items,
    required this.selectedId,
    required this.itemToId,
    required this.itemToLabel,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final List<T> items;
  final String? selectedId;
  final String Function(T) itemToId;
  final String Function(T) itemToLabel;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      isExpanded: true,
      dropdownColor: context.cardBg,
      style: TextStyle(color: context.textOnBg, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        filled: true,
        fillColor: context.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: context.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: context.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: itemToId(item),
          child: Text(itemToLabel(item)),
        );
      }).toList(),
      onChanged: (value) => onChanged(value),
    );
  }
}

class _DropdownSkeleton extends StatelessWidget {
  const _DropdownSkeleton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        filled: true,
        fillColor: context.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: BorderSide(color: context.divider),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
