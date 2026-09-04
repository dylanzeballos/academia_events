import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/event_filter_state.dart';
import '../../../../data/models/geographic_model.dart';
import '../../../../providers/public_events_provider.dart';

/// Bottom sheet version of filters for mobile
class EventFilterBottomSheet extends ConsumerWidget {
  const EventFilterBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FilterBottomSheetContent(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink(); // Not used directly
  }
}

class _FilterBottomSheetContent extends ConsumerStatefulWidget {
  const _FilterBottomSheetContent();

  @override
  ConsumerState<_FilterBottomSheetContent> createState() => _FilterBottomSheetContentState();
}

class _FilterBottomSheetContentState extends ConsumerState<_FilterBottomSheetContent> {
  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(eventFiltersProvider);
    final hasFilters = filter.hasActiveFilters;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: ref.read(eventFiltersProvider).hasActiveFilters
                ? null
                : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSizes.radiusLarge),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Filtros',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (hasFilters)
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(eventFiltersProvider.notifier).reset(),
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Limpiar todo'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Theme.of(context).textTheme.bodyLarge?.color),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Filter content - reuse the drawer content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: _buildFilterContent(context, ref),
                ),
              ),

              // Apply button
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        ),
                      ),
                      child: const Text(
                        'Aplicar filtros',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterContent(BuildContext context, WidgetRef ref) {
    // This is a simplified version - in practice you'd extract the sections
    // from EventFilterDrawer into reusable widgets
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          context,
          title: 'Categoría',
          child: _buildCategoryChips(context, ref),
        ),
        _buildSection(
          context,
          title: 'Categoría de Baile',
          child: _buildDanceCategoryChips(context, ref),
        ),
        _buildSection(
          context,
          title: 'Ubicación',
          child: _buildLocationSelector(context, ref),
        ),
        _buildSection(
          context,
          title: 'Fecha',
          child: _buildDateRange(context, ref),
        ),
        _buildSection(
          context,
          title: 'Precio',
          child: _buildPriceRange(context, ref),
        ),
        _buildSection(
          context,
          title: 'Ordenar por',
          child: _buildSortSelector(context, ref),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFiltersProvider);
    final categoriesAsync = ref.watch(publicEventCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const _LoadingChips(),
      error: (_, _) => const SizedBox.shrink(),
      data: (categories) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((cat) {
          final selected = filter.categoryIds.contains(cat.id);
          return FilterChip(
            label: Text(cat.name),
            selected: selected,
            onSelected: (_) => ref.read(eventFiltersProvider.notifier).toggleCategory(cat.id),
            selectedColor: AppColors.primary.withValues(alpha: 0.2),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selected ? AppColors.primary : Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDanceCategoryChips(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFiltersProvider);
    final categoriesAsync = ref.watch(publicDanceCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const _LoadingChips(),
      error: (_, _) => const SizedBox.shrink(),
      data: (categories) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((cat) {
          final selected = filter.danceCategoryIds.contains(cat.id);
          return FilterChip(
            label: Text(cat.name),
            selected: selected,
            onSelected: (_) => ref.read(eventFiltersProvider.notifier).toggleDanceCategory(cat.id),
            selectedColor: AppColors.secondary.withValues(alpha: 0.2),
            checkmarkColor: AppColors.secondary,
            labelStyle: TextStyle(
              color: selected ? AppColors.secondary : Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLocationSelector(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFiltersProvider);
    final departmentsAsync = ref.watch(publicDepartmentsProvider);
    final provincesAsync = ref.watch(publicProvincesProvider);
    final municipalitiesAsync = ref.watch(publicMunicipalitiesProvider);
    final citiesAsync = ref.watch(publicCitiesProvider);
    final notifier = ref.read(eventFiltersProvider.notifier);

    return Column(
      children: [
        departmentsAsync.when(
          loading: () => const _LoadingDropdown(),
          error: (_, _) => const SizedBox.shrink(),
          data: (departments) => _DropdownField(
            label: 'Departamento',
            value: departments.firstWhere(
              (d) => d.id == filter.departmentId,
              orElse: () => DepartmentModel(id: '', name: '', code: ''),
            ),
            items: departments,
            onChanged: (dept) => notifier.setLocation(
              departmentId: dept?.id,
              provinceId: null,
              municipalityId: null,
              cityId: null,
            ),
            getLabel: (d) => d.name,
          ),
        ),
        if (filter.departmentId != null)
          provincesAsync.when(
            loading: () => const _LoadingDropdown(),
            error: (_, _) => const SizedBox.shrink(),
            data: (provinces) => _DropdownField(
              label: 'Provincia',
              value: provinces.firstWhere(
                (p) => p.id == filter.provinceId,
                orElse: () => ProvinceModel(id: '', departmentId: '', name: ''),
              ),
              items: provinces,
              onChanged: (prov) => notifier.setLocation(
                departmentId: filter.departmentId,
                provinceId: prov?.id,
                municipalityId: null,
                cityId: null,
              ),
              getLabel: (p) => p.name,
            ),
          ),
        if (filter.provinceId != null)
          municipalitiesAsync.when(
            loading: () => const _LoadingDropdown(),
            error: (_, _) => const SizedBox.shrink(),
            data: (municipalities) => _DropdownField(
              label: 'Municipio',
              value: municipalities.firstWhere(
                (m) => m.id == filter.municipalityId,
                orElse: () => MunicipalityModel(id: '', provinceId: '', name: ''),
              ),
              items: municipalities,
              onChanged: (muni) => notifier.setLocation(
                departmentId: filter.departmentId,
                provinceId: filter.provinceId,
                municipalityId: muni?.id,
                cityId: null,
              ),
              getLabel: (m) => m.name,
            ),
          ),
        if (filter.municipalityId != null)
          citiesAsync.when(
            loading: () => const _LoadingDropdown(),
            error: (_, _) => const SizedBox.shrink(),
            data: (cities) => _DropdownField(
              label: 'Ciudad',
              value: cities.firstWhere(
                (c) => c.id == filter.cityId,
                orElse: () => CityModel(id: '', municipalityId: '', name: ''),
              ),
              items: cities,
              onChanged: (city) => notifier.setLocation(
                departmentId: filter.departmentId,
                provinceId: filter.provinceId,
                municipalityId: filter.municipalityId,
                cityId: city?.id,
              ),
              getLabel: (c) => c.name,
            ),
          ),
        if (filter.departmentId != null ||
            filter.provinceId != null ||
            filter.municipalityId != null ||
            filter.cityId != null)
          TextButton.icon(
            onPressed: () => notifier.clearLocation(),
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Limpiar ubicación'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
          ),
      ],
    );
  }

  Widget _buildDateRange(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFiltersProvider);
    final notifier = ref.read(eventFiltersProvider.notifier);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: 'Desde',
                date: filter.dateFrom,
                onTap: () => _pickDate(context, true, filter, notifier),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateField(
                label: 'Hasta',
                date: filter.dateTo,
                onTap: () => _pickDate(context, false, filter, notifier),
              ),
            ),
          ],
        ),
        if (filter.dateFrom != null || filter.dateTo != null)
          TextButton.icon(
            onPressed: () => notifier.clearDate(),
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Limpiar fechas'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
          ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, bool isFrom, EventFilterState filter, EventFiltersNotifier notifier) async {
    final initialDate = isFrom ? filter.dateFrom ?? DateTime.now() : filter.dateTo ?? DateTime.now();
    final firstDate = isFrom ? DateTime.now().subtract(const Duration(days: 365)) : (filter.dateFrom ?? DateTime.now());
    final lastDate = DateTime.now().add(const Duration(days: 365 * 2));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('es', 'BO'),
    );

    if (picked != null) {
      if (isFrom) {
        notifier.setDateRange(picked, filter.dateTo);
      } else {
        notifier.setDateRange(filter.dateFrom, picked);
      }
    }
  }

  Widget _buildPriceRange(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFiltersProvider);
    final notifier = ref.read(eventFiltersProvider.notifier);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Mín',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  prefixText: 'Bs ',
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) {
                    notifier.setPriceRange(parsed, filter.priceMax);
                  }
                },
                controller: TextEditingController(text: filter.priceMin?.toStringAsFixed(0) ?? ''),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Máx',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  prefixText: 'Bs ',
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) {
                    notifier.setPriceRange(filter.priceMin, parsed);
                  }
                },
                controller: TextEditingController(text: filter.priceMax?.toStringAsFixed(0) ?? ''),
              ),
            ),
          ],
        ),
        if (filter.priceMin != null || filter.priceMax != null)
          TextButton.icon(
            onPressed: () => notifier.clearPrice(),
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Limpiar precio'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
          ),
      ],
    );
  }

  Widget _buildSortSelector(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFiltersProvider);
    final notifier = ref.read(eventFiltersProvider.notifier);

    return DropdownButtonFormField<EventSortBy>(
      initialValue: filter.sortBy,
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      items: EventSortBy.values.map((sort) {
        return DropdownMenuItem<EventSortBy>(
          value: sort,
          child: Text(_sortLabel(sort)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) notifier.setSortBy(value);
      },
      isExpanded: true,
    );
  }

  String _sortLabel(EventSortBy sort) {
    switch (sort) {
      case EventSortBy.dateAsc:
        return 'Fecha: más próximos';
      case EventSortBy.dateDesc:
        return 'Fecha: más lejanos';
      case EventSortBy.priceAsc:
        return 'Precio: menor a mayor';
      case EventSortBy.priceDesc:
        return 'Precio: mayor a menor';
      case EventSortBy.relevance:
        return 'Relevancia';
    }
  }
}

class _LoadingChips extends StatelessWidget {
  const _LoadingChips();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(3, (index) => Container(
        height: 32,
        width: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
      )),
    );
  }
}

class _LoadingDropdown extends StatelessWidget {
  const _LoadingDropdown();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.getLabel,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T) getLabel;

  bool _isEmpty(dynamic v) => v == null || (v as dynamic).id?.toString().isEmpty == true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<T>(
        initialValue: _isEmpty(value) ? null : value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(getLabel(item)),
          );
        }).toList(),
        onChanged: onChanged,
        isExpanded: true,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey[500]),
        ),
        child: Text(
          date != null ? '${date!.day}/${date!.month}/${date!.year}' : 'Seleccionar',
          style: TextStyle(
            color: date != null ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey[500],
          ),
        ),
      ),
    );
  }
}