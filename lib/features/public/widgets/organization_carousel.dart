import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/public_event_data.dart';
import '../../../../providers/public_events_provider.dart';

/// Auto-sliding carousel of organizations that have published events.
/// Placed above the bottom navigation bar in student mode.
///
/// - Solo muestra organizaciones que tienen logo.
/// - Cada tarjeta es únicamente el logo (ampliado).
/// - Al tocar un logo se abre un bottom sheet con la información (sin
///   depender de rutas protegidas por autenticación).
class OrganizationCarousel extends ConsumerStatefulWidget {
  const OrganizationCarousel({
    super.key,
    this.height = 80,
    this.autoPlayInterval = const Duration(seconds: 5),
    this.showTitle = false,
    this.onCollapse,
  });

  final double height;
  final Duration autoPlayInterval;
  final bool showTitle;
  final VoidCallback? onCollapse;

  @override
  ConsumerState<OrganizationCarousel> createState() => _OrganizationCarouselState();
}

class _OrganizationCarouselState extends ConsumerState<OrganizationCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(widget.autoPlayInterval, () {
      if (!mounted || !_pageController.hasClients) {
        _startAutoPlay();
        return;
      }
      final orgs = ref.read(organizationsWithEventsProvider).value ?? [];
      if (orgs.length > 1) {
        _currentPage = (_currentPage + 1) % orgs.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
      _startAutoPlay();
    });
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

        return Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showTitle)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.business_outlined, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Organizaciones con eventos',
                          style: TextStyle(
                            color: context.textOnBg,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
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
                    padEnds: false,
                    physics: const ClampingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final org = orgs[index];
                      return _OrgLogoItem(
                        organization: org,
                        isActive: index == _currentPage,
                        onTap: () => _showOrgInfo(context, org),
                      );
                    },
                  ),
                ),
                if (orgs.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(orgs.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPage == index ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primary
                              : context.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
            if (widget.onCollapse != null)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: widget.onCollapse,
                  icon: const Icon(Icons.expand_more, size: 20),
                  color: context.textOnBg.withValues(alpha: 0.6),
                  tooltip: 'Plegar carrusel',
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Abre un bottom sheet con la información de la organización (no requiere
  /// autenticación y no navega a rutas protegidas).
  void _showOrgInfo(BuildContext context, OrganizationWithEventCount org) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.divider.withValues(alpha: 0.3),
                  border: Border.all(color: context.divider),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: org.logoUrl!,
                    fit: BoxFit.cover,
                    width: 72,
                    height: 72,
                    errorWidget: (_, _, _) => SizedBox(
                      width: 72,
                      height: 72,
                      child: Icon(
                        Icons.business_outlined,
                        color: AppColors.primary,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                org.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                org.eventCount == 1
                    ? '1 evento publicado'
                    : '${org.eventCount} eventos publicados',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: organization.logoUrl!,
              fit: BoxFit.cover,
              width: 52,
              height: 52,
              placeholder: (_, _) => Container(
                width: 52,
                height: 52,
                color: context.divider.withValues(alpha: 0.3),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              errorWidget: (_, _, _) => Container(
                width: 52,
                height: 52,
                color: context.divider.withValues(alpha: 0.3),
                child: Icon(
                  Icons.business_outlined,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}