import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/public_event_model.dart';

class PublicEventCard extends StatelessWidget {
  const PublicEventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showOrganizationLogo = true,
    this.aspectRatio = 0.65,
  });

  final PublicEventModel event;
  final VoidCallback? onTap;
  final bool showOrganizationLogo;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final hasImage = event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty;
    final priceText = event.minPrice != null
        ? 'Desde ${event.minPrice!.toStringAsFixed(0)} ${event.currency}'
        : 'Gratis';
    
    final locationText = [
      event.location?.locationName,
      event.location?.city?.name,
    ].where((e) => e != null && e.isNotEmpty).join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: context.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusMedium),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      CachedNetworkImage(
                        imageUrl: event.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: context.divider.withValues(alpha: 0.3),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, _, _) => _PlaceholderBanner(
                          color: AppColors.colorForOrganization(event.organizationId),
                        ),
                      )
                    else
                      _PlaceholderBanner(
                        color: AppColors.colorForOrganization(event.organizationId),
                      ),
                    // Price badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                        ),
                        child: Text(
                          priceText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Organization logo
                    if (showOrganizationLogo &&
                        event.organizationLogoUrl != null &&
                        event.organizationLogoUrl!.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: event.organizationLogoUrl!,
                              fit: BoxFit.cover,
                              width: 28,
                              height: 28,
                              errorWidget: (_, _, _) => Container(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                child: const Icon(
                                  Icons.storefront_outlined,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + Date row
                  Row(
                    children: [
                      if (event.categoryName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            event.categoryName!,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 11,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatter.dayMonth(event.startTime),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Title
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Organization
                  if (event.organizationName.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 11,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.organizationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Location
                  if (locationText.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 11,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Dance categories
                  if (event.danceCategories.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: event.danceCategories.take(3).map((cat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cat.name,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderBanner extends StatelessWidget {
  const _PlaceholderBanner({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.25),
      child: Center(
        child: Icon(Icons.image_outlined, color: color, size: 40),
      ),
    );
  }
}