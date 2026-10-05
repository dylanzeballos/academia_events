import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/public_event_data.dart';
import '../../../../providers/events_provider.dart';
import '../../../../providers/public_events_provider.dart';

class OrganizationCarouselSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final organizationCarouselSearchProvider =
    NotifierProvider<OrganizationCarouselSearchNotifier, String>(
      OrganizationCarouselSearchNotifier.new,
    );

class OrganizationCarouselSearchBar extends ConsumerStatefulWidget {
  const OrganizationCarouselSearchBar({super.key});

  @override
  ConsumerState<OrganizationCarouselSearchBar> createState() =>
      _OrganizationCarouselSearchBarState();
}

class _OrganizationCarouselSearchBarState
    extends ConsumerState<OrganizationCarouselSearchBar> {
  Timer? _debounce;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(organizationCarouselSearchProvider.notifier).setQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(organizationCarouselSearchProvider);
    if (_controller.text != query) _controller.text = query;

    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: 'Buscar academias u organizaciones...',
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey[500]),
                onPressed: () {
                  _debounce?.cancel();
                  _controller.clear();
                  ref
                      .read(organizationCarouselSearchProvider.notifier)
                      .setQuery('');
                },
                tooltip: 'Limpiar búsqueda',
              )
            : null,
        filled: true,
        fillColor: context.cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
    );
  }
}

/// Carrusel circular y auto-deslizante de organizaciones.
///
/// - Cada tarjeta muestra el logo (avatar) y el nombre.
/// - Al tocar una tarjeta se navega a la página pública de la organización
///   (con su semana, próximos eventos y clases próximas, sin depender de
///   rutas protegidas por autenticación).
class OrganizationCarousel extends ConsumerStatefulWidget {
  const OrganizationCarousel({
    super.key,
    this.height = 96,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.compact = false,
    this.expandedHeight,
  });

  final double height;
  final Duration autoPlayInterval;
  final bool compact;
  final double? expandedHeight;

  @override
  ConsumerState<OrganizationCarousel> createState() =>
      _OrganizationCarouselState();
}

class _OrganizationCarouselState extends ConsumerState<OrganizationCarousel> {
  static const _virtualPageCount = 1000;
  static const _initialPage = _virtualPageCount ~/ 2;

  late PageController _pageController;
  int _currentPage = _initialPage;
  int _orgsCount = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _initialPage,
      viewportFraction: 0.48,
    );
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (_) => _advance());
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Avanza automáticamente a la siguiente tarjeta (solo si hay más de una).
  void _advance() {
    if (!mounted || !_pageController.hasClients) return;
    if (_orgsCount <= 1) return;
    final next = _currentPage + 1 >= _virtualPageCount
        ? _initialPage
        : _currentPage + 1;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(organizationsWithEventsProvider);
    final filter = ref.watch(eventFiltersProvider);
    final weekEventsAsync = ref.watch(weekEventsProvider);
    final matchingEvents = weekEventsAsync.value ?? const [];
    final query = ref
        .watch(organizationCarouselSearchProvider)
        .trim()
        .toLowerCase();

    return orgsAsync.when(
      loading: () => SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (allOrgs) {
        // Las organizaciones sin logo muestran su inicial como respaldo.
        final showExpandedCarousel =
            widget.expandedHeight != null ||
            (weekEventsAsync.hasValue && matchingEvents.isEmpty);
        final carouselHeight =
            showExpandedCarousel && widget.expandedHeight != null
            ? widget.expandedHeight!
            : showExpandedCarousel
            ? (MediaQuery.sizeOf(context).height * 0.5)
                  .clamp(widget.height * 1.5, 360.0)
                  .toDouble()
            : widget.height;
        // Organizaciones con eventos que cumplen los filtros exclusivos de
        // eventos (categoría, precio, fecha o ciudad) en la semana elegida.
        final matchingOrganizationIds = matchingEvents
            .map((event) => event.organizationId)
            .toSet();

        // Filtros que solo pueden evaluarse sobre los eventos: si hay alguno
        // activo, la academia debe tener un evento que lo cumpla.
        final requiresMatchingEvent =
            filter.categoryIds.isNotEmpty ||
            filter.priceMin != null ||
            filter.priceMax != null ||
            filter.dateFrom != null ||
            filter.dateTo != null ||
            filter.cityId != null;

        // Filtro local del buscador del carrusel (nombre o género de baile).
        final searchedOrgs = query.isEmpty
            ? List<OrganizationWithEventCount>.from(allOrgs)
            : allOrgs
                  .where(
                    (organization) =>
                        organization.name.toLowerCase().contains(query) ||
                        organization.danceGenres.any(
                          (genre) => genre.toLowerCase().contains(query),
                        ),
                  )
                  .toList();

        // Los filtros de ubicación, academia y estilo se evalúan sobre la
        // propia academia, así que las academias sin eventos también aparecen.
        final visibleOrgs = searchedOrgs.where((organization) {
          if (filter.organizationId != null &&
              organization.id != filter.organizationId) {
            return false;
          }
          if (filter.departmentId != null &&
              organization.departmentId != filter.departmentId &&
              !matchingOrganizationIds.contains(organization.id)) {
            return false;
          }
          if (filter.provinceId != null &&
              organization.provinceId != filter.provinceId) {
            return false;
          }
          if (filter.municipalityId != null &&
              organization.municipalityId != filter.municipalityId) {
            return false;
          }
          if (filter.danceCategoryIds.isNotEmpty &&
              !organization.danceCategoryIds.any(
                filter.danceCategoryIds.contains,
              )) {
            return false;
          }
          final searchQuery = filter.searchQuery.trim().toLowerCase();
          if (searchQuery.isNotEmpty &&
              !organization.name.toLowerCase().contains(searchQuery) &&
              !organization.danceGenres.any(
                (genre) => genre.toLowerCase().contains(searchQuery),
              )) {
            return false;
          }
          if (requiresMatchingEvent &&
              !matchingOrganizationIds.contains(organization.id)) {
            return false;
          }
          return true;
        }).toList();
        if (visibleOrgs.isEmpty) return const SizedBox.shrink();
        _orgsCount = visibleOrgs.length;

        return SizedBox(
          height: carouselHeight,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 9, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'ACADEMIAS & SEDES',
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '${visibleOrgs.length} activas',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleOrgs.length == 1
                    ? _OrgLogoItem(
                        organization: visibleOrgs.first,
                        isActive: true,
                        compact: widget.compact,
                        expanded: showExpandedCarousel,
                        cardHeight: carouselHeight - 32,
                        onTap: () => context.push(
                          '${AppRoutes.organizationPublicDetailBase}/${visibleOrgs.first.id}',
                          extra: visibleOrgs.first.name,
                        ),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: _virtualPageCount,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                        },
                        physics: const ClampingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final orgIndex = index % visibleOrgs.length;
                          final org = visibleOrgs[orgIndex];
                          return _OrgLogoItem(
                            organization: org,
                            isActive:
                                orgIndex ==
                                _currentPage % visibleOrgs.length,
                            compact: widget.compact,
                            expanded: showExpandedCarousel,
                            cardHeight: carouselHeight - 32,
                            onTap: () => context.push(
                              '${AppRoutes.organizationPublicDetailBase}/${org.id}',
                              extra: org.name,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrgLogoItem extends StatelessWidget {
  const _OrgLogoItem({
    required this.organization,
    required this.isActive,
    required this.compact,
    required this.expanded,
    this.cardHeight,
    required this.onTap,
  });

  final OrganizationWithEventCount organization;
  final bool isActive;
  final VoidCallback onTap;
  final bool compact;
  final bool expanded;
  final double? cardHeight;

  @override
  Widget build(BuildContext context) {
    final compactCard = (cardHeight ?? 0) < 240;
    final bannerHeight = compactCard || !expanded ? 54.0 : 96.0;
    final avatarSize = compactCard
        ? 38.0
        : expanded
        ? 72.0
        : compact
        ? 30.0
        : 50.0;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: expanded
              ? 170
              : compact
              ? 72
              : 140,
          height: cardHeight,
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            border: Border.all(
              color: isActive ? AppColors.primary : context.divider,
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: bannerHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (organization.bannerUrl != null &&
                          organization.bannerUrl!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: organization.bannerUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              _BannerFallback(name: organization.name),
                        )
                      else
                        _BannerFallback(name: organization.name),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _CardBadge(
                          label: '${organization.eventCount} eventos',
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: compactCard
                      ? 6
                      : expanded
                      ? 14
                      : 10,
                ),
                _OrgAvatar(
                  name: organization.name,
                  logoUrl: organization.logoUrl,
                  size: avatarSize,
                  isActive: isActive,
                ),
                SizedBox(
                  height: compactCard
                      ? 4
                      : expanded
                      ? 8
                      : compact
                      ? 2
                      : 5,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 6),
                  child: Text(
                    organization.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: compactCard
                          ? 14
                          : expanded
                          ? 18
                          : compact
                          ? 7
                          : 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (organization.danceGenres.isNotEmpty || expanded) ...[
                  SizedBox(height: compactCard ? 3 : 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      organization.danceGenres.isNotEmpty
                          ? organization.danceGenres.take(2).join(' & ')
                          : 'Academia de baile',
                      maxLines: compactCard ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textOnBg.withValues(alpha: 0.65),
                        fontSize: compactCard ? 10 : 11,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  const _CardBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.45),
            AppColors.primary.withValues(alpha: 0.3),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.groups_rounded,
        size: 34,
        color: Colors.white.withValues(alpha: 0.75),
      ),
    );
  }
}

/// Avatar redondeado del logo de la organización.
///
/// Si no hay logo o la imagen falla al cargar, muestra la inicial de la
/// organización sobre un fondo de color (nunca un campo vacío).
class _OrgAvatar extends StatelessWidget {
  const _OrgAvatar({
    required this.name,
    required this.logoUrl,
    required this.size,
    required this.isActive,
  });

  final String name;
  final String? logoUrl;
  final double size;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    final hasUrl = url != null && url.trim().isNotEmpty;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.cardBg,
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.6)
              : context.divider.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: size,
                height: size,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}
