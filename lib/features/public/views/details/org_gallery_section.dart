import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        style: const TextStyle(color: Colors.white60),
      ),
      data: (images) {
        if (images.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Galería de la organización',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Imágenes compartidas por la academia',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
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
                  _PublicGalleryTile(image: images[index]),
            ),
          ],
        );
      },
    );
  }
}

class _PublicGalleryTile extends ConsumerWidget {
  const _PublicGalleryTile({required this.image});

  final OrganizationImageModel image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(orgLogoUrlProvider(image.imageUrl));
    final url = urlAsync.whenOrNull(data: (value) => value);

    return GestureDetector(
      onTap: url == null
          ? null
          : () => FullscreenImageViewer.show(
                context,
                url,
                tag: 'organization-gallery-${image.id}',
              ),
      child: Hero(
        tag: 'organization-gallery-${image.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: url == null
              ? const ColoredBox(
                  color: Color(0xFF181F30),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFF181F30),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
