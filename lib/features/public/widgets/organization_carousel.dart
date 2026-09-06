import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';
import '../../../../data/models/public_event_data.dart';
import '../../../../data/models/public_event_model.dart';
import '../../../../providers/events_provider.dart';
import '../../../../providers/public_events_provider.dart';

/// Auto-sliding carousel of organizations that have published events.
///
/// - Solo muestra organizaciones que tienen logo.
/// - Cada tarjeta muestra el logo (avatar) y el nombre.
/// - Al tocar una tarjeta se abre un bottom sheet con la información de la
///   organización, sus próximos eventos y sus clases próximas (sin depender
///   de rutas protegidas por autenticación).
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
                onTap: () => _showOrgInfo(context, org),
              );
            },
          ),
        );
      },
    );
  }

  /// Abre un bottom sheet con la información de la organización, sus próximos
  /// eventos y sus clases próximas. No requiere autenticación ni navega a
  /// rutas protegidas.
  void _showOrgInfo(BuildContext context, OrganizationWithEventCount org) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.cardBg,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Consumer(
            builder: (context, ref, _) {
              final eventsAsync = ref.watch(
                publicOrganizationEventsProvider(org.id),
              );
              final classesAsync = ref.watch(
                organizationUpcomingClassesProvider(org.id),
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle del sheet
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Encabezado con logo + nombre
                  _OrgAvatar(
                    name: org.name,
                    logoUrl: org.logoUrl,
                    size: 84,
                    isActive: true,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    org.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    org.eventCount == 1
                        ? '1 evento publicado'
                        : '${org.eventCount} eventos publicados',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // Próximos eventos
                  _SectionHeader(
                    icon: Icons.event_available_rounded,
                    title: 'Próximos eventos',
                  ),
                  const SizedBox(height: 8),
                  eventsAsync.when(
                    loading: () => const _SheetLoading(),
                    error: (error, _) => _SheetMessage(
                      text: 'No se pudieron cargar los eventos',
                    ),
                    data: (events) {
                      if (events.isEmpty) {
                        return const _SheetMessage(text: 'Sin eventos próximos');
                      }
                      return Column(
                        children: [
                          for (final e in events) _EventTile(event: e),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Clases próximas
                  _SectionHeader(
                    icon: Icons.fitness_center_rounded,
                    title: 'Clases próximas',
                  ),
                  const SizedBox(height: 8),
                  classesAsync.when(
                    loading: () => const _SheetLoading(),
                    error: (error, _) => const _SheetMessage(
                      text: 'No se pudieron cargar las clases',
                    ),
                    data: (classes) {
                      if (classes.isEmpty) {
                        return const _SheetMessage(text: 'Sin clases próximas');
                      }
                      return Column(
                        children: [
                          for (final c in classes) _ClassTile(cls: c),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),

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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SheetLoading extends StatelessWidget {
  const _SheetLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[500], fontSize: 13),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final PublicEventModel event;

  @override
  Widget build(BuildContext context) {
    final locationName = event.location?.locationName ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.divider.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormatter.fullDate(event.startTime)} · '
                  '${DateFormatter.timeRange(event.startTime, event.endTime)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                if (locationName.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.cls});

  final EventModel cls;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.divider.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fitness_center_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormatter.shortDay(cls.startTime)} '
                  '${DateFormatter.dayMonth(cls.startTime)} · '
                  '${DateFormatter.hourMin(cls.startTime)} – '
                  '${DateFormatter.hourMin(cls.endTime)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
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