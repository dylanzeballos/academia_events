import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_filter_state.dart';
import '../../../../data/models/paginated_result.dart';
import '../../../../data/models/public_event_model.dart';
import '../../../../providers/public_events_provider.dart';
import '../widgets/public_event_card.dart';
import '../widgets/event_search_bar.dart';
import '../widgets/event_filter_drawer.dart';
import '../widgets/pagination_controls.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/error_banner.dart';

class PublicEventsView extends ConsumerStatefulWidget {
  const PublicEventsView({super.key});

  @override
  ConsumerState<PublicEventsView> createState() => _PublicEventsViewState();
}

class _PublicEventsViewState extends ConsumerState<PublicEventsView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isGridView = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(publicEventsProvider);
    final filter = ref.watch(eventFiltersProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(context, isDesktop, filter),
      drawer: isDesktop ? null : const EventFilterDrawer(),
      body: Column(
        children: [
          // Search & Filter Bar
          _buildSearchFilterBar(context, isDesktop, filter),

          // Active Filters Chips
          if (filter.hasActiveFilters)
            _buildActiveFiltersChips(context),

          // Events List/Grid
          Expanded(
            child: eventsAsync.when(
              loading: () => const LoadingIndicator(),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingLarge),
                  child: AppBanner(
                    message: 'Error cargando eventos: $error',
                    type: BannerType.error,
                    onDismiss: () => ref.invalidate(publicEventsProvider),
                  ),
                ),
              ),
              data: (paginatedResult) {
                if (paginatedResult.isEmpty) {
                  return _buildEmptyState(context);
                }

                return _buildEventsList(
                  context,
                  paginatedResult,
                  isDesktop,
                );
              },
            ),
          ),
        ],
      ),
      // Mobile filter button
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.filter_list, color: Colors.white),
              label: const Text('Filtros', style: TextStyle(color: Colors.white)),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDesktop, EventFilterState filter) {
    return AppBar(
      title: const Text('Descubrir Eventos'),
      centerTitle: !isDesktop,
      actions: [
        if (isDesktop) ...[
          const EventSearchBarDesktop(),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () => _showDesktopFilterDialog(context),
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (filter.hasActiveFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Filtros',
          ),
          const SizedBox(width: 8),
        ],
        // View toggle
        IconButton(
          onPressed: () => setState(() => _isGridView = !_isGridView),
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          tooltip: _isGridView ? 'Vista lista' : 'Vista cuadrícula',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchFilterBar(BuildContext context, bool isDesktop, EventFilterState filter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(bottom: BorderSide(color: context.divider)),
      ),
      child: isDesktop
          ? Row(
              children: [
                const EventSearchBarDesktop(),
                const SizedBox(width: 16),
                _buildSortDropdown(context),
              ],
            )
          : Column(
              children: [
                EventSearchBar(
                  hintText: 'Buscar eventos...',
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildSortDropdown(context)),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      icon: Stack(
                        children: [
                          const Icon(Icons.filter_list, size: 18),
                          if (filter.hasActiveFilters)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      label: const Text('Filtros'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSortDropdown(BuildContext context) {
    final filter = ref.watch(eventFiltersProvider);
    final notifier = ref.read(eventFiltersProvider.notifier);

    return DropdownButton<EventSortBy>(
      value: filter.sortBy,
      underline: const SizedBox.shrink(),
      onChanged: (value) {
        if (value != null) notifier.setSortBy(value);
      },
      items: EventSortBy.values.map((sort) {
        return DropdownMenuItem<EventSortBy>(
          value: sort,
          child: Text(
            _sortLabel(sort),
            style: TextStyle(color: context.textOnBg, fontSize: 13),
          ),
        );
      }).toList(),
    );
  }

  String _sortLabel(EventSortBy sort) {
    switch (sort) {
      case EventSortBy.dateAsc:
        return 'Próximos';
      case EventSortBy.dateDesc:
        return 'Lejanos';
      case EventSortBy.priceAsc:
        return 'Precio ↑';
      case EventSortBy.priceDesc:
        return 'Precio ↓';
      case EventSortBy.relevance:
        return 'Relevancia';
    }
  }

  Widget _buildActiveFiltersChips(BuildContext context) {
    final filter = ref.watch(eventFiltersProvider);
    final notifier = ref.read(eventFiltersProvider.notifier);

    final chips = <Widget>[];

    if (filter.categoryIds.isNotEmpty) {
      chips.add(_ActiveFilterChip(
        label: '${filter.categoryIds.length} categoría(s)',
        onRemove: () => notifier.setCategoryIds([]),
      ));
    }
    if (filter.danceCategoryIds.isNotEmpty) {
      chips.add(_ActiveFilterChip(
        label: '${filter.danceCategoryIds.length} baile(s)',
        onRemove: () => notifier.setDanceCategoryIds([]),
      ));
    }
    if (filter.departmentId != null || filter.cityId != null) {
      chips.add(_ActiveFilterChip(
        label: 'Ubicación',
        onRemove: () => notifier.clearLocation(),
      ));
    }
    if (filter.dateFrom != null || filter.dateTo != null) {
      chips.add(_ActiveFilterChip(
        label: 'Fecha',
        onRemove: () => notifier.clearDate(),
      ));
    }
    if (filter.priceMin != null || filter.priceMax != null) {
      chips.add(_ActiveFilterChip(
        label: 'Precio',
        onRemove: () => notifier.clearPrice(),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }

  Widget _buildEventsList(
    BuildContext context,
    PaginatedResult<PublicEventModel> result,
    bool isDesktop,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 200 &&
            result.hasNextPage) {
          ref.read(eventFiltersProvider.notifier).nextPage();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(publicEventsProvider),
        child: _isGridView
            ? _buildGridView(context, result)
            : _buildListView(context, result),
      ),
    );
  }

  Widget _buildGridView(BuildContext context, PaginatedResult<PublicEventModel> result) {
    final crossAxisCount = MediaQuery.of(context).size.width > 1200
        ? 4
        : MediaQuery.of(context).size.width > 768
            ? 3
            : 2;

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: result.items.length + (result.hasNextPage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == result.items.length) {
          return const Center(child: LoadingIndicator());
        }
        final event = result.items[index];
        return PublicEventCard(
          event: event,
          onTap: () => context.push('${AppRoutes.publicEventDetailBase}/${event.id}'),
        );
      },
    );
  }

  Widget _buildListView(BuildContext context, PaginatedResult<PublicEventModel> result) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: result.items.length + (result.hasNextPage ? 1 : 0) + 1,
      itemBuilder: (context, index) {
        if (index == result.items.length) {
          if (result.hasNextPage) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: LoadingIndicator()),
            );
          }
          return const SizedBox.shrink();
        }
        if (index == result.items.length + 1) {
          return PaginationControls(
            paginatedResult: result,
            onPageChanged: (page) {},
          );
        }
        final event = result.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PublicEventCard(
            event: event,
            onTap: () => context.push('${AppRoutes.publicEventDetailBase}/${event.id}'),
            aspectRatio: 2.2,
            showOrganizationLogo: false,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron eventos',
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta ajustar los filtros o la búsqueda',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => ref.read(eventFiltersProvider.notifier).reset(),
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar filtros'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDesktopFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 600),
          child: const EventFilterDrawer(),
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}