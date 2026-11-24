// lib/features/organization/views/details/org_location_section.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/organization_model.dart';

class OrgLocationSection extends StatelessWidget {
  const OrgLocationSection({super.key, required this.organization});

  final OrganizationModel organization;

  Future<void> _openGoogleMaps(BuildContext context, LatLng? point) async {
    Uri uri;
    if (point != null) {
      uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${point.latitude},${point.longitude}',
      });
    } else {
      final query = '${organization.name} ${organization.address ?? ''}'.trim();
      uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': query,
      });
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo abrir la aplicación de mapas.'),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.near_me_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'UBICACIÓN Y CÓMO LLEGAR',
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── TARJETA ESTILO RADAR / GPS HUB ──
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ── CABECERA ILUSTRATIVA: GPS RADAR ──
              GestureDetector(
                onTap: () => _openGoogleMaps(context, point),
                child: Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.85),
                        const Color(0xFF1E1B4B), // Tono índigo oscuro nocturno
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Patrón sutil de fondo
                      CustomPaint(
                        size: const Size(double.infinity, 110),
                        painter: _RadarGridPainter(),
                      ),

                      // Ondas de radar concéntricas
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                      ),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),

                      // Pin central flotante
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),

                      // Badge superior derecho: Estado del punto
                      Positioned(
                        top: 10,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasCoordinates
                                      ? AppColors.success
                                      : Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                hasCoordinates ? 'GPS ACTIVO' : 'REFERENCIA',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Texto inferior de pulsar para navegar
                      Positioned(
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app_outlined,
                                size: 12,
                                color: Colors.white70,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Toca para abrir en Google Maps',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
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

              // ── CUERPO CON LA INFORMACIÓN FORMATEADA ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (locationName.isNotEmpty)
                      _InfoRow(
                        icon: Icons.business_outlined,
                        title: 'Sede o Edificio',
                        subtitle: locationName,
                      ),
                    if (address.isNotEmpty) ...[
                      if (locationName.isNotEmpty) const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.map_outlined,
                        title: 'Dirección física',
                        subtitle: address,
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      if (locationName.isNotEmpty || address.isNotEmpty)
                        const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.phone_in_talk_outlined,
                        title: 'Contacto de sede',
                        subtitle: phone,
                      ),
                    ],

                    const SizedBox(height: 18),

                    // ── BOTÓN ACCIÓN DIRECTA A MAPS ──
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: () => _openGoogleMaps(context, point),
                        icon: const Icon(Icons.directions_rounded, size: 20),
                        label: const Text(
                          'Iniciar ruta en Google Maps',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMedium),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── PINTOR DE LÍNEAS DE RADAR ──
class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    // Líneas horizontales
    for (double y = 0; y <= size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Líneas verticales
    for (double x = 0; x <= size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}