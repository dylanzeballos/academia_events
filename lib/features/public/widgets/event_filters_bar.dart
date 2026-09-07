import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/dance_category_model.dart';
import '../../../data/models/public_event_data.dart';
import '../../../providers/public_events_provider.dart';

/// Barra de filtros desplegables para los calendarios (Horario y calendario
/// público).
///
/// Sustituye a la antigua barra de filtros activos y al bottom sheet:
/// solo menús desplegables (categorías de baile multi-selección y
/// organización) más un botón "Limpiar" cuando hay filtros activos.
///
/// Con [showOrganizationFilter] en `false` (página de una organización) se
/// oculta el desplegable de organización, pues la organización viene fijada
/// por la ruta.
class EventFiltersBar extends ConsumerWidget {
  const EventFiltersBar({
    super.key,
    this.showOrganizationFilter = true,
  });

  final bool showOrganizationFilter;

  static const String _allDanceValue = '__all_dance__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFiltersProvider);
    final danceAsync = ref.watch(publicDanceCategoriesProvider);
    final orgsAsync = ref.watch(organizationsWithEventsProvider);

    final dance = danceAsync.value ?? const <DanceCategoryModel>[];
    final orgs = orgsAsync.value ?? const <OrganizationWithEventCount>[];

    final selectedDanceNames = <String>[];
    if (filter.danceCategoryIds.isNotEmpty) {
      for (final c in dance) {
        if (filter.danceCategoryIds.contains(c.id)) selectedDanceNames.add(c.name);
      }
    }
    final danceLabel = filter.danceCategoryIds.isEmpty
        ? 'Todas'
        : selectedDanceNames.isEmpty
            ? '${filter.danceCategoryIds.length} seleccionadas'
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
        : 'Organización';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(bottom: BorderSide(color: context.divider, width: 1)),
      ),
      child: Row(
        children: [
          // ── Categorías de baile (multi-selección) ───────────────
          Flexible(
            child: PopupMenuButton<String>(
              tooltip: 'Filtrar por categoría de baile',
              onSelected: (value) {
                final notifier = ref.read(eventFiltersProvider.notifier);
                if (value == _allDanceValue) {
                  notifier.setDanceCategoryIds(const []);
                } else {
                  notifier.toggleDanceCategory(value);
                }
              },
              itemBuilder: (context) {
                return [
                  CheckedPopupMenuItem<String>(
                    value: _allDanceValue,
                    checked: filter.danceCategoryIds.isEmpty,
                    child: const Text('Todas'),
                  ),
                  for (final c in dance)
                    CheckedPopupMenuItem<String>(
                      value: c.id,
                      checked: filter.danceCategoryIds.contains(c.id),
                      child: Text(c.name),
                    ),
                ];
              },
              child: _FilterPill(
                icon: Icons.music_note_rounded,
                label: danceLabel,
              ),
            ),
          ),

          // ── Organización (selección única) ──────────────────────
          if (showOrganizationFilter) ...[
            const SizedBox(width: 8),
            Flexible(
              child: PopupMenuButton<String?>(
                tooltip: 'Filtrar por organización',
                enabled: orgs.isNotEmpty,
                onSelected: (value) {
                  ref.read(eventFiltersProvider.notifier).setOrganizationId(value);
                },
                itemBuilder: (context) {
                  return [
                    PopupMenuItem<String?>(
                      value: null,
                      child: Row(
                        children: [
                          Icon(
                            filter.organizationId == null
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text('Todas'),
                        ],
                      ),
                    ),
                    for (final o in orgs)
                      PopupMenuItem<String?>(
                        value: o.id,
                        child: Row(
                          children: [
                            Icon(
                              o.id == filter.organizationId
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(o.name, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                  ];
                },
                child: _FilterPill(
                  icon: Icons.apartment_rounded,
                  label: orgLabel,
                ),
              ),
            ),
          ],

          const Spacer(),

          // ── Limpiar filtros ─────────────────────────────────────
          if (filter.hasActiveFilters)
            TextButton(
              onPressed: () {
                ref.read(eventFiltersProvider.notifier).reset();
              },
              child: const Text('Limpiar'),
            ),
        ],
      ),
    );
  }
}

/// Botón de filtros para las vistas de semana públicas: abre la hoja de
/// filtros y muestra un punto indicador cuando hay filtros activos.
///
/// Sustituye a la barra de filtros fija que ocupaba el espacio encima de los
/// días, dejando que la agenda semanal se adapte verticalmente a los eventos.
class EventFiltersButton extends ConsumerWidget {
  const EventFiltersButton({
    super.key,
    this.showOrganizationFilter = true,
  });

  final bool showOrganizationFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActiveFilters =
        ref.watch(eventFiltersProvider).hasActiveFilters;

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

/// Muestra la hoja con los filtros desplegables (categorías de baile y
/// organización) más el botón "Limpiar".
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

/// Pastilla que abre el menú desplegable.
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.inputBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textOnBg,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 18, color: context.textMuted),
        ],
      ),
    );
  }
}