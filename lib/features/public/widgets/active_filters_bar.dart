import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/event_filter_state.dart';
import '../../../../providers/public_events_provider.dart';
import 'event_filter_bottom_sheet.dart';

/// Barra visible de filtros activos que se muestra encima del calendario.
/// Muestra chips desplegables con los filtros aplicados y un botón para
/// abrir el panel completo de filtros.
class ActiveFiltersBar extends ConsumerStatefulWidget {
  const ActiveFiltersBar({super.key});

  @override
  ConsumerState<ActiveFiltersBar> createState() => _ActiveFiltersBarState();
}

class _ActiveFiltersBarState extends ConsumerState<ActiveFiltersBar> {
  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(eventFiltersProvider);
    final notifier = ref.read(eventFiltersProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingSmall,
        AppSizes.paddingSmall,
        AppSizes.paddingSmall,
        0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Filtros',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (filter.hasActiveFilters)
                TextButton.icon(
                  onPressed: notifier.reset,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Limpiar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              TextButton.icon(
                onPressed: () => EventFilterBottomSheet.show(context),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Más filtros'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          if (filter.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._categoryChips(ref),
                  if (filter.dateFrom != null || filter.dateTo != null)
                    _chip(
                      context,
                      label: _dateLabel(filter),
                      onDelete: notifier.clearDate,
                    ),
                  if (filter.priceMin != null || filter.priceMax != null)
                    _chip(
                      context,
                      label: _priceLabel(filter),
                      onDelete: notifier.clearPrice,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _categoryChips(WidgetRef ref) {
    final filter = ref.watch(eventFiltersProvider);
    final notifier = ref.read(eventFiltersProvider.notifier);
    final chips = <Widget>[];

    final categories = ref.watch(publicEventCategoriesProvider).value ?? const [];
    for (final id in filter.categoryIds) {
      final match = categories.where((c) => c.id == id).toList();
      if (match.isNotEmpty) {
        chips.add(
          _chip(
            context,
            label: match.first.name,
            onDelete: () => notifier.toggleCategory(id),
            color: AppColors.primary,
          ),
        );
      }
    }

    final danceCategories =
        ref.watch(publicDanceCategoriesProvider).value ?? const [];
    for (final id in filter.danceCategoryIds) {
      final match = danceCategories.where((c) => c.id == id).toList();
      if (match.isNotEmpty) {
        chips.add(
          _chip(
            context,
            label: match.first.name,
            onDelete: () => notifier.toggleDanceCategory(id),
            color: AppColors.secondary,
          ),
        );
      }
    }

    return chips;
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required VoidCallback onDelete,
    Color? color,
  }) {
    return InputChip(
      label: Text(label),
      onPressed: () {},
      onDeleted: onDelete,
      deleteButtonTooltipMessage: 'Quitar filtro',
      labelStyle: TextStyle(
        color: color ?? Theme.of(context).textTheme.bodyMedium?.color,
        fontSize: 12,
      ),
      backgroundColor: (color ?? Theme.of(context).cardColor)
          .withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radiusMedium,
        ),
        side: BorderSide(
          color: (color ?? Theme.of(context).dividerColor)
              .withValues(alpha: 0.4),
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  String _dateLabel(EventFilterState f) {
    String d(DateTime? x) =>
        x == null ? '' : '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}';
    final from = d(f.dateFrom);
    final to = d(f.dateTo);
    if (from.isNotEmpty && to.isNotEmpty) return '$from – $to';
    return from.isNotEmpty ? 'Desde $from' : 'Hasta $to';
  }

  String _priceLabel(EventFilterState f) {
    if (f.priceMin != null && f.priceMax != null) {
      final min = f.priceMin!.toStringAsFixed(0);
      final max = f.priceMax!.toStringAsFixed(0);
      return 'Bs $min – $max';
    }
    if (f.priceMin != null) return 'Desde Bs ${f.priceMin!.toStringAsFixed(0)}';
    return 'Hasta Bs ${f.priceMax!.toStringAsFixed(0)}';
  }
}