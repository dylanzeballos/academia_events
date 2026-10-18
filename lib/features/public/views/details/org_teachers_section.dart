// lib/features/organization/views/details/org_location_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/organization_model.dart';

class OrgLocationSection extends StatelessWidget {
  const OrgLocationSection({super.key, required this.organization});

  final OrganizationModel organization;

  Future<void> _openGoogleMaps(BuildContext context, LatLng point) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${point.latitude},${point.longitude}',
    });

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo abrir Google Maps.'),
          backgroundColor: context.cardBg,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCoordinates =
        organization.latitude != null && organization.longitude != null;
    final address = organization.address?.trim() ?? '';
    final locationName = organization.locationName?.trim() ?? '';
    final phone = organization.phoneNumber?.trim() ?? '';

    if (!hasCoordinates &&
        address.isEmpty &&
        locationName.isEmpty &&
        phone.isEmpty) {
      return const SizedBox.shrink();
    }

    final point = hasCoordinates
        ? LatLng(organization.latitude!, organization.longitude!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ubicación',
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: context.divider),
          ),
          child: Column(
            children: [
              if (point != null)
                GestureDetector(
                  onTap: () => _openGoogleMaps(context, point),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: point,
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(
                            flags: 0,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.academia_events',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: point,
                                width: 42,
                                height: 42,
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppColors.error,
                                  size: 38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (point != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openGoogleMaps(context, point),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Abrir en Google Maps'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSmall)),
                    ),
                  ),
                ),
              ],
              if (point != null) const SizedBox(height: 16),
              if (locationName.isNotEmpty)
                _InfoRow(
                  icon: Icons.place_outlined,
                  title: 'Lugar o sede',
                  subtitle: locationName,
                ),
              if (address.isNotEmpty) ...[
                if (locationName.isNotEmpty) const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  title: 'Dirección',
                  subtitle: address,
                ),
              ],
              if (phone.isNotEmpty) ...[
                if (locationName.isNotEmpty || address.isNotEmpty)
                  const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  title: 'Teléfono',
                  subtitle: phone,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 2),
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}