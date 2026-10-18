import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/dance_category_model.dart';
import '../../../../data/models/geographic_model.dart';
import '../../../../data/models/public_event_data.dart';
import '../../../../providers/public_events_provider.dart';

class EventFiltersBar extends ConsumerWidget {
  const EventFiltersBar({
    super.key,
    this.showOrganizationFilter = true,
    this.dense = false,
  });

  final bool showOrganizationFilter;
  final bool dense;

  static const String _allDanceValue = '__all_dance__';
  static const String _allValue = '__all__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFiltersProvider);
    final danceAsync = ref.watch(publicDanceCategoriesProvider);
    final orgsAsync = ref.watch(organizationsWithEventsProvider);
    final departmentsAsync = ref.watch(publicDepartmentsProvider);

    final dance = danceAsync.value ?? const <DanceCategoryModel>[];
    final orgs = orgsAsync.value ?? const <OrganizationWithEventCount>[];
    final departments = departmentsAsync.value ?? const <DepartmentModel>[];

    final selectedDanceNames = <String>[];
    if (filter.danceCategoryIds.isNotEmpty) {
      for (final c in dance) {
        if (filter.danceCategoryIds.contains(c.id)) {
          selectedDanceNames.add(c.name);
        }
      }
    }
    final danceLabel = filter.danceCategoryIds.isEmpty
        ? 'Estilo'
        : selectedDanceNames.isEmpty
            ? '${filter.danceCategoryIds.length} estilos'
            : selectedDanceNames.join(' · ');

    String? selectedOrgName;
    for (final o in orgs) {
      if (o.id == filter.organizationId) {
        selectedOrgName = o.name;
        break;
      }
    }
    final orgLabel = filter.organizationId != null && selectedOrgName != null
        ? selectedOrgName
        : 'Academia';

    DepartmentModel? selectedDepartment;
    for (final department in departments) {
      if (department.id == filter.departmentId) {
        selectedDepartment = department;
        break;
      }
    }
    final departmentLabel = selectedDepartment?.name ?? 'Ubicación';

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(bottom: BorderSide(color: context.divider, width: 1)),
      ),
      padding: EdgeInsets.symmetric(vertical: dense ? 6 : 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16),
        child: Row(
          children: [
            _PillMenu<String>(
              tooltip: 'Filtrar por ubicación',
              onSelected: (value) => ref
                  .read(eventFiltersProvider.notifier)
                  .setDepartmentId(value == _allValue ? null : value),
              itemBuilder: (context) => [
                _radioItem(context, _allValue, filter.departmentId == null, 'Todas'),
                for (final department in departments)
                  _radioItem(
                    context,
                    department.id,
                    department.id == filter.departmentId,
                    department.name,
                  ),
              ],
              child: _FilterPill(
                icon: Icons.location_on_outlined,
                label: departmentLabel,
                dense: dense,
                active: filter.departmentId != null,
              ),
            ),
            const SizedBox(width: 8),

            _PillMenu<String>(
              tooltip: 'Filtrar por estilo de baile',
              onSelected: (value) {
                final notifier = ref.read(eventFiltersProvider.notifier);
                if (value == _allDanceValue) {
                  notifier.setDanceCategoryIds(const []);
                } else {
                  notifier.toggleDanceCategory(value);
                }
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem<String>(
                  value: _allDanceValue,
                  checked: filter.danceCategoryIds.isEmpty,
                  child: Text(
                    'Todos los estilos',
                    style: TextStyle(color: context.textOnBg),
                  ),
                ),
                for (final c in dance)
                  CheckedPopupMenuItem<String>(
                    value: c.id,
                    checked: filter.danceCategoryIds.contains(c.id),
                    child: Text(
                      c.name,
                      style: TextStyle(color: context.textOnBg),
                    ),
                  ),
              ],
              child: _FilterPill(
                icon: Icons.music_note_rounded,
                label: danceLabel,
                dense: dense,
                active: filter.danceCategoryIds.isNotEmpty,
              ),
            ),
            const SizedBox(width: 8),

            if (showOrganizationFilter) ...[
              _PillMenu<String>(
                tooltip: 'Filtrar por academia',
                enabled: orgs.isNotEmpty,
                onSelected: (value) => ref
                    .read(eventFiltersProvider.notifier)
                    .setOrganizationId(value == _allValue ? null : value),
                itemBuilder: (context) => [
                  _radioItem(context, _allValue, selectedOrgName == null, 'Todas'),
                  for (final o in orgs)
                    _radioItem(context, o.id, o.id == filter.organizationId, o.name),
                ],
                child: _FilterPill(
                  icon: Icons.apartment_rounded,
                  label: orgLabel,
                  dense: dense,
                  active: filter.organizationId != null,
                ),
              ),
              const SizedBox(width: 8),
            ],

            if (filter.hasActiveFilters) ...[
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => ref.read(eventFiltersProvider.notifier).reset(),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Limpiar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  PopupMenuItem<T> _radioItem<T>(
    BuildContext context,
    T value,
    bool selected,
    String label,
  ) {
    return PopupMenuItem<T>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 18,
            color: selected ? AppColors.primary : context.textMuted,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.primary : context.textOnBg,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EventFiltersButton extends ConsumerWidget {
  const EventFiltersButton({super.key, this.showOrganizationFilter = true});

  final bool showOrganizationFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActiveFilters = ref.watch(eventFiltersProvider).hasActiveFilters;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => showEventFiltersSheet(
            context,
            showOrganizationFilter: showOrganizationFilter,
          ),
          tooltip: 'Filtros',
          icon: Icon(
            hasActiveFilters ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
            color: context.textOnBg,
          ),
        ),
        if (hasActiveFilters)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showEventFiltersSheet(
  BuildContext context, {
  bool showOrganizationFilter = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLarge)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Text(
                    'Filtros',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textOnBg,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: Icon(Icons.close, color: context.textMuted),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            EventFiltersBar(showOrganizationFilter: showOrganizationFilter),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _PillMenu<T> extends StatelessWidget {
  const _PillMenu({
    required this.child,
    required this.itemBuilder,
    required this.onSelected,
    required this.tooltip,
    this.enabled = true,
  });

  final Widget child;
  final PopupMenuItemBuilder<T> itemBuilder;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      enabled: enabled,
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      color: context.cardBg,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: child,
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    this.dense = false,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool dense;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primary : context.textOnBg;
    final bg = active ? AppColors.primary.withValues(alpha: 0.14) : context.cardBg;
    final border = active ? AppColors.primary : context.divider;

    return Container(
      height: dense ? 30 : 36,
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 14 : 16, color: fg),
          SizedBox(width: dense ? 4 : 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 11 : 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          SizedBox(width: dense ? 2 : 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: dense ? 16 : 18, color: fg),
        ],
      ),
    );
  }
}