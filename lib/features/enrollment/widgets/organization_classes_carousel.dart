import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/organization_with_classes.dart';
import '../../../providers/class_enrollment_provider.dart';

/// Carrusel de organizaciones que tienen clases publicadas. Al tocar una
/// organización se navega a la experiencia de explorar sus clases.
class OrganizationClassesCarousel extends ConsumerStatefulWidget {
  const OrganizationClassesCarousel({super.key, this.height = 72});

  final double height;

  @override
  ConsumerState<OrganizationClassesCarousel> createState() =>
      _OrganizationClassesCarouselState();
}

class _OrganizationClassesCarouselState
    extends ConsumerState<OrganizationClassesCarousel> {
  final PageController _pageController =
      PageController(viewportFraction: 0.55);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(organizationsWithPublishedClassesProvider);

    return orgsAsync.when(
      loading: () => SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (orgs) {
        if (orgs.isEmpty) {
          return Center(
            child: Text(
              'Aún no hay organizaciones con clases.',
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
          );
        }

        return SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: orgs.length,
            padEnds: false,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (index) {
              final clamped = index.clamp(0, orgs.length - 1);
              setState(() => _currentPage = clamped);
            },
            itemBuilder: (context, index) {
              final org = orgs[index];
              return _OrgCard(
                organization: org,
                isActive: index == _currentPage,
                onTap: () {
                  ref
                      .read(selectedExploreOrgIdProvider.notifier)
                      .select(org.id);
                },
                navigateToClasses: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('Explorando clases de ${org.name}'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  ref
                      .read(selectedExploreOrgIdProvider.notifier)
                      .select(org.id);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _OrgCard extends StatelessWidget {
  const _OrgCard({
    required this.organization,
    required this.isActive,
    required this.onTap,
    required this.navigateToClasses,
  });

  final OrganizationWithClasses organization;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback navigateToClasses;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isActive ? navigateToClasses : onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          border: Border.all(
            color: isActive ? AppColors.primary : context.divider,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: (organization.logoUrl != null &&
                      organization.logoUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: organization.logoUrl!,
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                      placeholder: (_, _) => Container(
                        width: 40,
                        height: 40,
                        color: context.divider.withValues(alpha: 0.3),
                        child: const Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        width: 40,
                        height: 40,
                        color: context.divider.withValues(alpha: 0.3),
                        child: Icon(
                          Icons.business_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      color: AppColors.primary.withValues(alpha: 0.15),
                      child: Center(
                        child: Text(
                          organization.name.isNotEmpty
                              ? organization.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                organization.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}