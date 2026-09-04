import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';
import '../map_view_screen.dart';

class EventLocationSection extends StatelessWidget {
  const EventLocationSection({
    super.key,
    required this.event,
    required this.accentColor,
  });

  final EventModel event;
  final Color accentColor;

  Future<void> _openGoogleMaps(BuildContext context, LatLng point) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps')),
      );
    }
  }

  void _openFullMap(BuildContext context) {
    final loc = event.location!;
    final subtitleParts = [
      if (loc.locationName != null && loc.locationName!.isNotEmpty) loc.locationName!,
      if (loc.addressLine1 != null && loc.addressLine1!.isNotEmpty) loc.addressLine1!,
    ];

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => MapViewScreen(
          center: LatLng(loc.latitude!, loc.longitude!),
          title: event.title,
          subtitle: subtitleParts.join(' · '),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = event.location;
    final hasLocation = location?.latitude != null && location?.longitude != null;

    final locationLines = [
      if (location?.locationName != null && location!.locationName!.isNotEmpty)
        location.locationName!,
      if (location?.addressLine1 != null && location!.addressLine1!.isNotEmpty)
        location.addressLine1!,
    ];

    if (!hasLocation && locationLines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ubicación',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        if (hasLocation)
          GestureDetector(
            onTap: () => _openFullMap(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(location!.latitude!, location.longitude!),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(flags: 0),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.academia_events',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(location.latitude!, location.longitude!),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 38),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.cardBg.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fullscreen, size: 16, color: accentColor),
                            const SizedBox(width: 4),
                            Text(
                              'Ampliar',
                              style: TextStyle(
                                color: context.textOnBg,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (locationLines.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_outlined, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locationLines.join('\n'),
                  style: TextStyle(
                    color: context.textOnBg.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (hasLocation) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openFullMap(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor),
                  ),
                  icon: const Icon(Icons.fullscreen, size: 18),
                  label: const Text('Ampliar mapa'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openGoogleMaps(
                    context,
                    LatLng(location!.latitude!, location.longitude!),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Google Maps'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}