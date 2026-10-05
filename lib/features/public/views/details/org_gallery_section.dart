import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/organization_image_model.dart';
import '../../../../providers/organization_provider.dart';
import '../../../../shared/widgets/fullscreen_image_viewer.dart';

class OrgGallerySection extends ConsumerWidget {
  const OrgGallerySection({
    super.key,
    required this.imagesAsync,
  });

  final AsyncValue<List<OrganizationImageModel>> imagesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return imagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text(
        'No se pudo cargar la galería: $error',
        style: TextStyle(color: context.textMuted),
      ),
      data: (images) {
        if (images.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Galería de la organización',
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Toca una imagen para ampliarla',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) =>
                  _PublicGalleryTile(image: images[index], images: images),
            ),
          ],
        );
      },
    );
  }
}

class _PublicGalleryTile extends ConsumerWidget {
  const _PublicGalleryTile({required this.image, required this.images});

  final OrganizationImageModel image;
  final List<OrganizationImageModel> images;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(orgLogoUrlProvider(image.imageUrl));
    final url = urlAsync.whenOrNull(data: (value) => value);
    final tag = 'organization-gallery-${image.id}';

    return GestureDetector(
      onTap: url == null ? null : () => _openGallery(context, ref),
      child: Hero(
        tag: tag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: url == null
              ? ColoredBox(
                  color: context.surfaceInput,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: context.surfaceInput,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: context.textMuted,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// Abre la galería completa en la imagen tocada, permitiendo deslizar
  /// entre todas las fotos (estilo WhatsApp).
  void _openGallery(BuildContext context, WidgetRef ref) {
    final urls = <String>[];
    final tags = <String>[];
    for (final img in images) {
      final resolved = ref
          .read(orgLogoUrlProvider(img.imageUrl))
          .whenOrNull(data: (value) => value);
      if (resolved != null && resolved.trim().isNotEmpty) {
        urls.add(resolved);
        tags.add('organization-gallery-${img.id}');
      }
    }
    if (urls.isEmpty) return;
    final initialIndex = tags.indexOf('organization-gallery-${image.id}');
    FullscreenImageViewer.showGallery(
      context,
      urls,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      tags: tags,
    );
  }
}
