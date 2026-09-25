import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future _openWhatsApp() async {
    if (whatsappNumber.trim().isEmpty) return;
    final cleanPhone = whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone?text=Hola,%20quisiera%20más%20información%20de%20las%20clases');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
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
            // Banner Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _buildFallbackCover(),
                      )
                    : _buildFallbackCover(),
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
                          color: const Color(0xFF1E2333),
                        ),
                        child: ClipOval(
                          child: logoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: logoUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => _avatarFallback(),
                                )
                              : _avatarFallback(),
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
                      child: const Icon(Icons.check, size: 14, color: Colors.white),
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
          style: const TextStyle(
            color: Colors.white,
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
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        if (location != null && location!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            location!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
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
                    onPressed: whatsappNumber.trim().isEmpty ? null : _openWhatsApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                    label: Text(
                      whatsappNumber.trim().isEmpty ? 'Contacto no disponible' : 'WhatsApp',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                color: const Color(0xFF1B2234),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2B344D)),
              ),
              child: IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                onPressed: onShare,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      color: const Color(0xFF1E2538),
      child: const Center(
        child: Icon(Icons.music_note, size: 48, color: Colors.white24),
      ),
    );
  }

  Widget _avatarFallback() {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'A',
        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({required this.mainText, required this.subText, this.isHighlighted = false});
  final String mainText;
  final String subText;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141926).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF27314A)),
      ),
      child: Column(
        children: [
          Text(
            mainText,
            style: TextStyle(
              color: isHighlighted ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            subText,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161C2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF232D46)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF38BDF8)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}