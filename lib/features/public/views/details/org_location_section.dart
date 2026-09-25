import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/models/organization_model.dart';
import '../../../events/widgets/map_view_screen.dart';

class OrgLocationSection extends StatelessWidget {
  const OrgLocationSection({
    super.key,
    required this.organization,
  });

  final OrganizationModel organization;

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
        const Text(
          'Ubicación',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF131722),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E2538)),
          ),
          child: Column(
            children: [
              if (point != null)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapViewScreen(
                        center: point,
                        title: organization.name,
                        subtitle: [locationName, address]
                            .where((value) => value.isNotEmpty)
                            .join(' · '),
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: point,
                          initialZoom: 15,
                          interactionOptions:
                              const InteractionOptions(flags: 0),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.academia_events',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: point,
                                width: 42,
                                height: 42,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
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
        const Icon(Icons.place_outlined, color: Color(0xFF06B6D4), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white,
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
