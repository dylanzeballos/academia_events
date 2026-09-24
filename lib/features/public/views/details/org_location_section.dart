import 'package:flutter/material.dart';

class OrgLocationSection extends StatelessWidget {
  const OrgLocationSection({
    super.key,
    this.address = 'Av. Oquendo #450 (Entre Jordan y Calama), Cochabamba',
    this.schedule = 'Lunes a Sábado: 16:00 – 22:30',
    this.phone = '+591 68458460',
  });

  final String address;
  final String schedule;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ubicación & Servicios',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        // Contenedor principal
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF131722),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E2538)),
          ),
          child: Column(
            children: [
              // Vista previa del mapa
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  color: const Color(0xFF263238),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.map, size: 70, color: Colors.white.withValues(alpha: 0.1)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE85D04)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, color: Color(0xFFE85D04), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Sede Central Cochabamba',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Dirección Sede
              _InfoRow(
                icon: Icons.location_on_outlined,
                iconColor: const Color(0xFFE85D04),
                title: 'Dirección Sede',
                subtitle: address,
              ),
              const SizedBox(height: 12),

              // Atención de Secretaría
              _InfoRow(
                icon: Icons.access_time,
                iconColor: const Color(0xFF06B6D4),
                title: 'Atención de Secretaría',
                subtitle: schedule,
              ),
              const SizedBox(height: 12),

              // Teléfono / WhatsApp
              _InfoRow(
                icon: Icons.phone_outlined,
                iconColor: const Color(0xFFF59E0B),
                title: 'Línea Directa & WhatsApp',
                subtitle: phone,
              ),

              const SizedBox(height: 16),

              // Grilla de comodidades
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _AmenityChip(icon: Icons.ac_unit, label: '2 Salas Climatizadas'),
                  _AmenityChip(icon: Icons.crop_square, label: 'Espejos Profesionales'),
                  _AmenityChip(icon: Icons.shower_outlined, label: 'Vestuarios & Duchas'),
                  _AmenityChip(icon: Icons.local_parking, label: 'Parqueo Privado'),
                ],
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
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2232),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF06B6D4)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}