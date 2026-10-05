import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/theme_extensions.dart';
import '../../../../shared/widgets/fullscreen_image_viewer.dart';

class OrgHeroHeader extends StatelessWidget {
  const OrgHeroHeader({
    super.key,
    required this.name,
    this.coverUrl,
    this.logoUrl,
    this.description,
    this.location,
    this.whatsappNumber = '',
    this.logoTag,
    this.onShare,
  });

  final String name;
  final String? coverUrl;
  final String? logoUrl;
  final String? description;
  final String? location;
  final String whatsappNumber;
  final String? logoTag;
  final VoidCallback? onShare;

  Future<void> _openWhatsApp(BuildContext context) async {
    final cleanPhone = whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;

    final url = Uri.https('wa.me', '/$cleanPhone', {
      'text': 'Hola, quisiera más información de las clases',
    });

    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp con este número.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Portada con Avatar superpuesto y Badges
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Banner Cover (toca para ampliar)
            GestureDetector(
              onTap: coverUrl == null
                  ? null
                  : () => FullscreenImageViewer.show(
                      context,
                      coverUrl!,
                      tag: '${logoTag ?? 'organization-logo-$name'}-cover',
                    ),
              child: Hero(
                tag: '${logoTag ?? 'organization-logo-$name'}-cover',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                _buildFallbackCover(context),
                          )
                        : _buildFallbackCover(context),
                  ),
                ),
              ),
            ),

            // Avatar circular superpuesto
            Positioned(
              bottom: -32,
              left: 16,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: logoUrl == null
                        ? null
                        : () => FullscreenImageViewer.show(
                            context,
                            logoUrl!,
                            tag: logoTag,
                          ),
                    child: Hero(
                      tag: logoTag ?? 'organization-logo-$name',
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE85D04),
                            width: 3,
                          ),
                          color: context.surfaceInput,
                        ),
                        child: ClipOval(
                          child: logoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: logoUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      _avatarFallback(context),
                                )
                              : _avatarFallback(context),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF06B6D4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 42),

        // Nombre de la academia
        Text(
          name,
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),

        if (description != null && description!.trim().isNotEmpty)
          Text(
            description!,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        if (location != null && location!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            location!,
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),

        const SizedBox(height: 16),

        // Botones de Acción (Inscribirme / WhatsApp y Compartir)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE85D04), Color(0xFF06B6D4)],
                    ),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: whatsappNumber.trim().isEmpty
                        ? null
                        : () => _openWhatsApp(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      whatsappNumber.trim().isEmpty
                          ? 'Contacto no disponible'
                          : 'WhatsApp',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: context.surfaceInput,
                shape: BoxShape.circle,
                border: Border.all(color: context.divider),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.share_outlined,
                  color: context.textOnBg,
                  size: 20,
                ),
                onPressed: onShare,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFallbackCover(BuildContext context) {
    return Container(
      color: context.surfaceInput,
      child: Center(
        child: Icon(Icons.music_note, size: 48, color: context.textMuted),
      ),
    );
  }

  Widget _avatarFallback(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'A',
        style: TextStyle(
          color: context.textOnBg,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
