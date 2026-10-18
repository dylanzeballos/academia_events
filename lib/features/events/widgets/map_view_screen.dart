// lib/features/events/widgets/map_view_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';

class MapViewScreen extends StatelessWidget {
  const MapViewScreen({
    super.key,
    required this.center,
    this.title,
    this.subtitle,
  });

  final LatLng center;
  final String? title;
  final String? subtitle;

  Future<void> _openGoogleMaps(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${center.latitude},${center.longitude}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo abrir Google Maps'),
          backgroundColor: context.cardBg,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(title ?? 'Ubicación', style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Abrir en Google Maps',
            icon: Icon(Icons.open_in_new, color: context.textOnBg),
            onPressed: () => _openGoogleMaps(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 16),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.academia_events',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 45,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.error,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (subtitle != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.cardBg.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  border: Border.all(color: context.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
              ),
              onPressed: () => _openGoogleMaps(context),
              icon: const Icon(Icons.map_outlined),
              label: const Text(
                'Abrir en Google Maps',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}