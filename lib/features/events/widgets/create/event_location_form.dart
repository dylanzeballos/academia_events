import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../providers/events_provider.dart';

class EventLocationForm extends ConsumerWidget {
  const EventLocationForm({
    super.key,
    required this.locationNameController,
    required this.addressController,
    required this.selectedLatLng,
    required this.onMapTap,
    required this.selectedDepartmentId,
    required this.selectedProvinceId,
    required this.selectedMunicipalityId,
    required this.selectedCityId,
    required this.onDepartmentChanged,
    required this.onProvinceChanged,
    required this.onMunicipalityChanged,
    required this.onCityChanged,
  });

  final TextEditingController locationNameController;
  final TextEditingController addressController;
  final LatLng selectedLatLng;
  final VoidCallback onMapTap;

  final String? selectedDepartmentId;
  final String? selectedProvinceId;
  final String? selectedMunicipalityId;
  final String? selectedCityId;

  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<String?> onProvinceChanged;
  final ValueChanged<String?> onMunicipalityChanged;
  final ValueChanged<String?> onCityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(departmentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ubicación y División Territorial',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Departamento
        departmentsAsync.when(
          data: (deps) => DropdownButtonFormField<String>(
            initialValue: selectedDepartmentId,
            dropdownColor: context.cardBg,
            style: TextStyle(color: context.textOnBg),
            decoration: const InputDecoration(labelText: 'Departamento'),
            items: deps
                .map((d) => DropdownMenuItem(
                    value: d['id'] as String, child: Text(d['name'] as String)))
                .toList(),
            onChanged: onDepartmentChanged,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),

        // Provincia
        if (selectedDepartmentId != null)
          ref.watch(provincesProvider(selectedDepartmentId!)).when(
                data: (provinces) => DropdownButtonFormField<String>(
                  key: ValueKey(selectedDepartmentId),
                  initialValue: selectedProvinceId,
                  dropdownColor: context.cardBg,
                  style: TextStyle(color: context.textOnBg),
                  decoration: const InputDecoration(labelText: 'Provincia'),
                  items: provinces
                      .map((p) => DropdownMenuItem(
                          value: p['id'] as String, child: Text(p['name'] as String)))
                      .toList(),
                  onChanged: onProvinceChanged,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
        if (selectedDepartmentId != null) const SizedBox(height: 12),

        // Municipio
        if (selectedProvinceId != null)
          ref.watch(municipalitiesProvider(selectedProvinceId!)).when(
                data: (munis) => DropdownButtonFormField<String>(
                  key: ValueKey(selectedProvinceId),
                  initialValue: selectedMunicipalityId,
                  dropdownColor: context.cardBg,
                  style: TextStyle(color: context.textOnBg),
                  decoration: const InputDecoration(labelText: 'Municipio'),
                  items: munis
                      .map((m) => DropdownMenuItem(
                          value: m['id'] as String, child: Text(m['name'] as String)))
                      .toList(),
                  onChanged: onMunicipalityChanged,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
        if (selectedProvinceId != null) const SizedBox(height: 12),

        // Ciudad
        if (selectedMunicipalityId != null)
          ref.watch(citiesProvider(selectedMunicipalityId!)).when(
                data: (cities) => DropdownButtonFormField<String>(
                  key: ValueKey(selectedMunicipalityId),
                  initialValue: selectedCityId,
                  dropdownColor: context.cardBg,
                  style: TextStyle(color: context.textOnBg),
                  decoration: const InputDecoration(labelText: 'Ciudad'),
                  items: cities
                      .map((c) => DropdownMenuItem(
                          value: c['id'] as String, child: Text(c['name'] as String)))
                      .toList(),
                  onChanged: onCityChanged,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
        const SizedBox(height: 16),

        TextFormField(
          controller: locationNameController,
          decoration: const InputDecoration(
            labelText: 'Lugar / Nombre del Salón',
            hintText: 'Ej. Salón de Eventos Los Arcos',
          ),
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: addressController,
          decoration: const InputDecoration(
            labelText: 'Dirección Exacta',
            hintText: 'Ej. Av. Heroínas #456',
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Ubicación Exacta en el Mapa',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),

        // Previsualización interactiva del mapa
        InkWell(
          onTap: onMapTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              border: Border.all(color: context.divider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              child: Stack(
                children: [
                  IgnorePointer(
                    child: FlutterMap(
                      key: ValueKey(
                          '${selectedLatLng.latitude}_${selectedLatLng.longitude}'),
                      options: MapOptions(
                        initialCenter: selectedLatLng,
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.academia_events',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: selectedLatLng,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on,
                                  color: Colors.red, size: 38),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding:
                          const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lat: ${selectedLatLng.latitude.toStringAsFixed(4)}, Lng: ${selectedLatLng.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Text(
                            'Cambiar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
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
      ],
    );
  }
}