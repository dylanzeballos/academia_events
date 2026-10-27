// lib/features/public/views/details/org_hero_header.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
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
  });

  final String name;
  final String? coverUrl;
  final String? logoUrl;
  final String? description;
  final String? location;
  final String whatsappNumber;
  final String? logoTag;

  Future<void> _openWhatsApp(BuildContext context) async {
    final cleanPhone = whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;

    final url = Uri.https('wa.me', '/$cleanPhone', {
      'text': 'Hola, quisiera más información de las clases',
    });

    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo abrir WhatsApp con este número.'),
          backgroundColor: context.cardBg,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
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
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _buildFallbackCover(context),
                          )
                        : _buildFallbackCover(context),
                  ),
                ),
              ),
            ),
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
                            color: AppColors.primary,
                            width: 3,
                          ),
                          color: context.cardBg,
                        ),
                        child: ClipOval(
                          child: logoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: logoUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => _avatarFallback(context),
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
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.onSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 42),
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
        const SizedBox(height: 16),
        // Botón WhatsApp ocupando todo el ancho (sin botón compartir a la derecha)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
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
                color: AppColors.onPrimary,
                size: 18,
              ),
              label: Text(
                whatsappNumber.trim().isEmpty
                    ? 'Contacto no disponible'
                    : 'WhatsApp',
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackCover(BuildContext context) {
    return Container(
      color: context.cardBg,
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