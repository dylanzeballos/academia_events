import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/public_event_data.dart';
import '../../../../providers/public_events_provider.dart';

/// Auto-sliding carousel of organizations that have published events.
///
/// - Solo muestra organizaciones que tienen logo.
/// - Cada tarjeta muestra el logo (avatar) y el nombre.
/// - Al tocar una tarjeta se navega a la página pública de la organización
///   (con su semana, próximos eventos y clases próximas, sin depender de
///   rutas protegidas por autenticación).
class OrganizationCarousel extends ConsumerStatefulWidget {
  const OrganizationCarousel({
    super.key,
    this.height = 96,
    this.autoPlayInterval = const Duration(seconds: 4),
  });

  final double height;
  final Duration autoPlayInterval;

  @override
  ConsumerState<OrganizationCarousel> createState() => _OrganizationCarouselState();
}

class _OrganizationCarouselState extends ConsumerState<OrganizationCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  int _orgsCount = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.34);
    _autoPlayTimer = Timer.periodic(
      widget.autoPlayInterval,
      (_) => _advance(),
    );
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
    final next = (_currentPage + 1) % _orgsCount;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(organizationsWithEventsProvider);

    return orgsAsync.when(
      loading: () => SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (allOrgs) {
        // Solo organizaciones con logo.
        final orgs = List<OrganizationWithEventCount>.from(
          allOrgs.where((o) =>
              o.logoUrl != null && o.logoUrl!.trim().isNotEmpty),
        );
        if (orgs.isEmpty) return const SizedBox.shrink();
        _orgsCount = orgs.length;
        if (_currentPage >= _orgsCount) _currentPage = 0;

        return SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: orgs.length,
            onPageChanged: (index) {
              // Si el índice salió del rango (p.ej. al quitar orgs sin logo),
              // reajustar para evitar desbordes.
              final clamped = index.clamp(0, orgs.length - 1);
              setState(() => _currentPage = clamped);
            },
            physics: const ClampingScrollPhysics(),
            itemBuilder: (context, index) {
              final org = orgs[index];
              return _OrgLogoItem(
                organization: org,
                isActive: index == _currentPage,
                onTap: () => context.push(
                  '${AppRoutes.organizationPublicDetailBase}/${org.id}',
                  extra: org.name,
                ),
              );
            },
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
    required this.onTap,
  });

  final OrganizationWithEventCount organization;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: 104,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _OrgAvatar(
                name: organization.name,
                logoUrl: organization.logoUrl,
                size: 46,
                isActive: isActive,
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  organization.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
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