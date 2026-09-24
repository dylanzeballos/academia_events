import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class OrgGallerySection extends StatefulWidget {
  const OrgGallerySection({super.key});

  @override
  State createState() => _OrgGallerySectionState();
}

class _OrgGallerySectionState extends State {
  int _selectedFilter = 0;
  final List _filters = ['TODAS', 'INSTALACIONES & SALAS', 'CLASES & TALLERES'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de Sección
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instalaciones & Galería',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Fotos oficiales de la academia',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F263B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 13, color: Color(0xFF38BDF8)),
                  SizedBox(width: 4),
                  Text('Subir Fotos', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Filtros de Galería
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(_filters.length, (index) {
              final active = _selectedFilter == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = index),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF06B6D4) : const Color(0xFF171E2E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _filters[index],
                    style: TextStyle(
                      color: active ? Colors.black : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 14),

        // Foto Principal Grande
        _PhotoCard(
          title: 'Sala Central 1 • Parquet flotante & Climatización',
          icon: Icons.aspect_ratio,
          aspectRatio: 16 / 9,
          imageUrl: 'https://images.unsplash.com/photo-1547153760-18fc86324498?auto=format&fit=crop&w=800&q=80',
        ),

        const SizedBox(height: 10),

        // Fila de 2 Fotos
        Row(
          children: const [
            Expanded(
              child: _PhotoCard(
                title: 'Clase Bachata Sensual',
                aspectRatio: 1,
                imageUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?auto=format&fit=crop&w=500&q=80',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _PhotoCard(
                title: 'Viernes de Social Dance',
                aspectRatio: 1,
                imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=500&q=80',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.title,
    required this.imageUrl,
    required this.aspectRatio,
    this.icon,
  });

  final String title;
  final String imageUrl;
  final double aspectRatio;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: const Color(0xFF181F30)),
              errorWidget: (_, _, _) => Container(color: const Color(0xFF181F30)),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 10,
            right: 10,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: const Color(0xFF38BDF8)),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}