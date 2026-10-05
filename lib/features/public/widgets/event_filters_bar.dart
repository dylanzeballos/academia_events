import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/dance_category_model.dart';
import '../../../data/models/geographic_model.dart';
import '../../../data/models/public_event_data.dart';
import '../../../providers/public_events_provider.dart';

/// Barra de filtros desplegables para los calendarios (Horario y calendario
/// público).
///
/// Se muestra como una fila desplazable de pastillas compactas. Cada pastilla
/// se resalta cuando su filtro está activo. Con [showOrganizationFilter] en
/// `false` (página de una organización) se oculta el desplegable de
/// organización, pues viene fijada por la ruta.
class EventFiltersBar extends ConsumerWidget {
  const EventFiltersBar({
    super.key,
    this.showOrganizationFilter = true,
    this.dense = false,
  });

  final bool showOrganizationFilter;
  final bool dense;

  static const String _allDanceValue = '__all_dance__';

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
            // ── Categorías de baile (multi-selección) ───────────────
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
                  child: const Text('Todos los estilos'),
                ),
                for (final c in dance)
                  CheckedPopupMenuItem<String>(
                    value: c.id,
                    checked: filter.danceCategoryIds.contains(c.id),
                    child: Text(c.name),
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

            // ── Organización (selección única) ──────────────────────
            if (showOrganizationFilter) ...[
              _PillMenu<String?>(
                tooltip: 'Filtrar por academia',
                enabled: orgs.isNotEmpty,
                onSelected: (value) => ref
                    .read(eventFiltersProvider.notifier)
                    .setOrganizationId(value),
                itemBuilder: (context) => [
                  _radioItem(null, selectedOrgName == null, 'Todas'),
                  for (final o in orgs)
                    _radioItem(o.id, o.id == filter.organizationId, o.name),
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

            // ── Departamento (selección única) ──────────────────────
            _PillMenu<String?>(
              tooltip: 'Filtrar por ubicación',
              onSelected: (value) =>
                  ref.read(eventFiltersProvider.notifier).setDepartmentId(value),
              itemBuilder: (context) => [
                _radioItem(null, filter.departmentId == null, 'Todas'),
                for (final department in departments)
                  _radioItem(
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

            // ── Limpiar filtros ─────────────────────────────────────
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

  PopupMenuItem<String?> _radioItem(String? value, bool selected, String label) {
    return PopupMenuItem<String?>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            size: 18,
            color: selected ? AppColors.primary : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Botón de filtros que abre la hoja y muestra un punto cuando hay filtros
/// activos.
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
            hasActiveFilters
                ? Icons.filter_alt_rounded
                : Icons.filter_alt_outlined,
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

/// Muestra la hoja con los filtros desplegables más el botón "Limpiar".
Future<void> showEventFiltersSheet(
  BuildContext context, {
  bool showOrganizationFilter = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
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
                    icon: const Icon(Icons.close),
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

/// PopupMenuButton tipado con pastilla desplegable.
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
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: child,
    );
  }
}

/// Pastilla que abre el menú desplegable. Se resalta cuando está activa.
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
    final bg = active
        ? AppColors.primary.withValues(alpha: 0.14)
        : context.inputBg;
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
