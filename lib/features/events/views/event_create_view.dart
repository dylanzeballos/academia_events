import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/organization_provider.dart';
import '../widgets/map.dart';

class EventCreateView extends ConsumerStatefulWidget {
  const EventCreateView({super.key});

  @override
  ConsumerState<EventCreateView> createState() => _EventCreateViewState();
}

class _EventCreateViewState extends ConsumerState<EventCreateView> {
  final _formKey = GlobalKey<FormState>();

  // Controllers básicos
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _capacityController = TextEditingController();

  // Controllers de Ubicación
  final _locationNameController = TextEditingController();
  final _addressController = TextEditingController();

  // Selección de Ubicación Administrativa
  String? _selectedCategoryId;
  String? _selectedDepartmentId;
  String? _selectedProvinceId;
  String? _selectedMunicipalityId;
  String? _selectedCityId;

  // Coordenadas seleccionadas (Por defecto: Cochabamba / Quillacollo)
  LatLng _selectedLatLng = const LatLng(-17.3935, -66.2825);

  // Fechas y Horas
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 19, minute: 0);
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 0);

  // Imágenes en bytes
  Uint8List? _bannerBytes;
  Uint8List? _qrBytes;

  bool _isLoading = false;
  bool _requiresApproval = true;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contactPhoneController.dispose();
    _capacityController.dispose();
    _locationNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Abrir mapa en pantalla completa y capturar coordenadas
  Future<void> _openMapPicker() async {
    final LatLng? pickedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMap(
          initialLatLng: _selectedLatLng,
        ),
      ),
    );

    if (pickedLocation != null) {
      setState(() => _selectedLatLng = pickedLocation);
    }
  }

  Future<void> _pickImage(bool isQr) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (isQr) {
          _qrBytes = bytes;
        } else {
          _bannerBytes = bytes;
        }
      });
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final initialTime = isStart ? _startTime : _endTime;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = pickedDate;
        _startTime = pickedTime;
      } else {
        _endDate = pickedDate;
        _endTime = pickedTime;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final orgId = ref.read(selectedOrganizationIdProvider);
    if (orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay una organización seleccionada')),
      );
      return;
    }

    final startAt = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endAt = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (endAt.isBefore(startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha de fin debe ser posterior al inicio')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final title = _titleController.text.trim();
      final slug =
          '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}-${DateTime.now().millisecondsSinceEpoch}';

      final contact = _contactPhoneController.text.trim();
      final description = _descriptionController.text.trim();

      final fullDescription = contact.isNotEmpty
          ? '$description\n\nContactos: $contact'
          : description;

      final eventData = {
        'organization_id': orgId,
        'category_id': _selectedCategoryId,
        'title': title,
        'slug': slug,
        'description': fullDescription,
        'start_at': startAt.toIso8601String(),
        'end_at': endAt.toIso8601String(),
        'timezone': 'America/La_Paz',
        'status': 'published',
        'visibility': 'public',
        'requires_approval': _requiresApproval,
        if (_capacityController.text.isNotEmpty)
          'capacity': int.parse(_capacityController.text.trim()),
      };

      final locationData = {
        'department_id': _selectedDepartmentId,
        'province_id': _selectedProvinceId,
        'municipality_id': _selectedMunicipalityId,
        'city_id': _selectedCityId,
        'location_name': _locationNameController.text.trim(),
        'address_line_1': _addressController.text.trim(),
        'latitude': _selectedLatLng.latitude,
        'longitude': _selectedLatLng.longitude,
      };

      await ref.read(eventsRepositoryProvider).createFullEvent(
        eventData: eventData,
        locationData: locationData,
        bannerBytes: _bannerBytes,
        qrBytes: _qrBytes,
      );

      // ─── INVALIDACIONES DE PROVIDERS ───
      ref.invalidate(orgEventsProvider);
      ref.invalidate(weekEventsProvider);
      ref.invalidate(allEventsProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento publicado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear evento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventCategoriesAsync = ref.watch(eventCategoriesProvider);
    final departmentsAsync = ref.watch(departmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Evento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── 1. PANFLETO / PORTADA ───
              _ImagePickerBox(
                label: 'Panfleto / Afiche del Evento',
                icon: Icons.add_photo_alternate_outlined,
                imageBytes: _bannerBytes,
                onTap: () => _pickImage(false),
              ),
              const SizedBox(height: 20),

              // ─── 2. INFORMACIÓN BÁSICA ───
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título del evento *',
                  hintText: 'Ej. Social Salsa & Bachata Night',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresa un título' : null,
              ),
              const SizedBox(height: 16),

              // Tipo / Categoría de Evento
              eventCategoriesAsync.when(
                data: (categories) => DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  dropdownColor: context.cardBg,
                  style: TextStyle(color: context.textOnBg),
                  decoration: const InputDecoration(labelText: 'Tipo de Evento *'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                  validator: (v) => v == null ? 'Selecciona una categoría' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción del Evento *',
                  hintText: 'Detalles del programa, código de vestimenta, etc.',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresa una descripción' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contactPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono Contacto',
                        hintText: 'Ej. 77912345',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Aforo / Capacidad',
                        hintText: 'Ej. 150',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── 3. UBICACIÓN Y DIVISIÓN TERRITORIAL ───
              const Text(
                'Ubicación y División Territorial',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Desplegable Departamento
              departmentsAsync.when(
                data: (deps) => DropdownButtonFormField<String>(
                  initialValue: _selectedDepartmentId,
                  dropdownColor: context.cardBg,
                  style: TextStyle(color: context.textOnBg),
                  decoration: const InputDecoration(labelText: 'Departamento'),
                  items: deps
                      .map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['name'] as String)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDepartmentId = val;
                      _selectedProvinceId = null;
                      _selectedMunicipalityId = null;
                      _selectedCityId = null;
                    });
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 12),

              // Desplegable Provincia
              if (_selectedDepartmentId != null)
                ref.watch(provincesProvider(_selectedDepartmentId!)).when(
                      data: (provinces) => DropdownButtonFormField<String>(
                        key: ValueKey(_selectedDepartmentId),
                        initialValue: _selectedProvinceId,
                        dropdownColor: context.cardBg,
                        style: TextStyle(color: context.textOnBg),
                        decoration: const InputDecoration(labelText: 'Provincia'),
                        items: provinces
                            .map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] as String)))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedProvinceId = val;
                            _selectedMunicipalityId = null;
                            _selectedCityId = null;
                          });
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox(),
                    ),
              if (_selectedDepartmentId != null) const SizedBox(height: 12),

              // Desplegable Municipio
              if (_selectedProvinceId != null)
                ref.watch(municipalitiesProvider(_selectedProvinceId!)).when(
                      data: (munis) => DropdownButtonFormField<String>(
                        key: ValueKey(_selectedProvinceId),
                        initialValue: _selectedMunicipalityId,
                        dropdownColor: context.cardBg,
                        style: TextStyle(color: context.textOnBg),
                        decoration: const InputDecoration(labelText: 'Municipio'),
                        items: munis
                            .map((m) => DropdownMenuItem(value: m['id'] as String, child: Text(m['name'] as String)))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedMunicipalityId = val;
                            _selectedCityId = null;
                          });
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox(),
                    ),
              if (_selectedProvinceId != null) const SizedBox(height: 12),

              // Desplegable Ciudad
              if (_selectedMunicipalityId != null)
                ref.watch(citiesProvider(_selectedMunicipalityId!)).when(
                      data: (cities) => DropdownButtonFormField<String>(
                        key: ValueKey(_selectedMunicipalityId),
                        initialValue: _selectedCityId,
                        dropdownColor: context.cardBg,
                        style: TextStyle(color: context.textOnBg),
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                        items: cities
                            .map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedCityId = val),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox(),
                    ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _locationNameController,
                decoration: const InputDecoration(
                  labelText: 'Lugar / Nombre del Salón',
                  hintText: 'Ej. Salón de Eventos Los Arcos',
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección Exacta',
                  hintText: 'Ej. Av. Heroínas #456 entre 16 de Julio',
                ),
              ),
              const SizedBox(height: 16),

              // ─── PREVISUALIZACIÓN DEL MAPA SELECCIONADO ───
              const Text(
                'Ubicación Exacta en el Mapa',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              InkWell(
                onTap: _openMapPicker,
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
                            key: ValueKey('${_selectedLatLng.latitude}_${_selectedLatLng.longitude}'),
                            options: MapOptions(
                              initialCenter: _selectedLatLng,
                              initialZoom: 15.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.academia_events',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _selectedLatLng,
                                    width: 40,
                                    height: 40,
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
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.touch_app, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Lat: ${_selectedLatLng.latitude.toStringAsFixed(4)}, Lng: ${_selectedLatLng.longitude.toStringAsFixed(4)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
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
              const SizedBox(height: 24),

              // ─── 4. FECHA Y HORA ───
              const Text(
                'Fecha y Hora',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                title: const Text('Inicio del evento'),
                subtitle: Text(
                  '${_startDate.day}/${_startDate.month}/${_startDate.year} - ${_startTime.format(context)}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _pickDateTime(isStart: true),
              ),
              const Divider(),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy, color: AppColors.primary),
                title: const Text('Fin del evento'),
                subtitle: Text(
                  '${_endDate.day}/${_endDate.month}/${_endDate.year} - ${_endTime.format(context)}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _pickDateTime(isStart: false),
              ),
              const Divider(),
              const SizedBox(height: 20),

              // ─── 5. IMAGEN QR (PAGOS / CONTACTO) ───
              const Text(
                'Código QR de Pago / Información (Opcional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _ImagePickerBox(
                label: 'Subir QR',
                icon: Icons.qr_code_2_outlined,
                imageBytes: _qrBytes,
                height: 120,
                onTap: () => _pickImage(true),
              ),
              const SizedBox(height: 24),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Requiere aprobación'),
                subtitle: const Text('Validación previa para asistir'),
                value: _requiresApproval,
                onChanged: (val) => setState(() => _requiresApproval = val),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Publicar Evento',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePickerBox extends StatelessWidget {
  const _ImagePickerBox({
    required this.label,
    required this.icon,
    required this.imageBytes,
    required this.onTap,
    this.height = 180,
  });

  final String label;
  final IconData icon;
  final Uint8List? imageBytes;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: context.divider),
        ),
        child: imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                child: Image.memory(imageBytes!, fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 40, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(color: context.textOnBg, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
      ),
    );
  }
}