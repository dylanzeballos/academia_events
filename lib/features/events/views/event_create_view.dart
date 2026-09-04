import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/organization_provider.dart';
import '../widgets/create/event_basic_info_form.dart';
import '../widgets/create/event_location_form.dart';
import '../widgets/create/event_schedule_form.dart';
import '../widgets/create/event_tickets_editor.dart';
import '../widgets/create/image_picker_box.dart';
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

  // Controllers de Tickets (Precio y Stock opcional/ilimitado)
  final _priceController = TextEditingController(text: '0');
  final _ticketStockController = TextEditingController(text: '100');
  bool _isUnlimitedStock = false;

  // Controllers de Ubicación
  final _locationNameController = TextEditingController();
  final _addressController = TextEditingController();

  // Ubicación administrativa
  String? _selectedCategoryId;
  String? _selectedDepartmentId;
  String? _selectedProvinceId;
  String? _selectedMunicipalityId;
  String? _selectedCityId;

  LatLng _selectedLatLng = const LatLng(-17.3935, -66.2825);

  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 19, minute: 0);
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 0);

  Uint8List? _bannerBytes;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contactPhoneController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _ticketStockController.dispose();
    _locationNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final LatLng? pickedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMap(initialLatLng: _selectedLatLng),
      ),
    );

    if (pickedLocation != null) {
      setState(() => _selectedLatLng = pickedLocation);
    }
  }

  Future<void> _pickBannerImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() => _bannerBytes = bytes);
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
        const SnackBar(
          content: Text('La fecha de fin debe ser posterior al inicio'),
        ),
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

      // Cantidad de entradas: 999999 si es ilimitado para cumplir CHECK (quantity > 0)
      final ticketQuantity = _isUnlimitedStock
          ? 999999
          : (int.tryParse(_ticketStockController.text.trim()) ?? 100);

      final parsedCapacity = _capacityController.text.trim().isNotEmpty
          ? int.tryParse(_capacityController.text.trim())
          : (_isUnlimitedStock ? null : ticketQuantity);

      // Estado en 'draft' (borrador) a la espera del pago de publicación
      final eventData = {
        'organization_id': orgId,
        'category_id': _selectedCategoryId,
        'title': title,
        'slug': slug,
        'description': fullDescription,
        'start_at': startAt.toIso8601String(),
        'end_at': endAt.toIso8601String(),
        'timezone': 'America/La_Paz',
        'status': 'draft',
        'visibility': 'public',
        'requires_approval': false,
        'published_at': null,
        if (parsedCapacity != null) 'capacity': parsedCapacity,
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

      final parsedPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final ticketTypesData = [
        {
          'name': 'Entrada General',
          'description': 'Acceso general al evento',
          'price': parsedPrice,
          'quantity': ticketQuantity,
          'currency': 'BOB',
          'is_active': true,
        }
      ];

      await ref.read(eventsRepositoryProvider).createFullEvent(
            eventData: eventData,
            locationData: locationData,
            ticketTypesData: ticketTypesData,
            bannerBytes: _bannerBytes,
            qrBytes: null,
          );

      ref.invalidate(orgEventsProvider);
      ref.invalidate(weekEventsProvider);
      ref.invalidate(allEventsProvider);

      if (mounted) {
        context.pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento creado en borrador correctamente')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Evento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Portada / Banner
              ImagePickerBox(
                label: 'Panfleto / Afiche del Evento',
                icon: Icons.add_photo_alternate_outlined,
                imageBytes: _bannerBytes,
                onTap: _pickBannerImage,
              ),
              const SizedBox(height: 20),

              // 2. Información básica
              EventBasicInfoForm(
                titleController: _titleController,
                descriptionController: _descriptionController,
                contactPhoneController: _contactPhoneController,
                capacityController: _capacityController,
                selectedCategoryId: _selectedCategoryId,
                onCategoryChanged: (val) =>
                    setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 20),

              // 3. Costo y Stock de entradas
              EventTicketsEditor(
                priceController: _priceController,
                stockController: _ticketStockController,
                isUnlimitedStock: _isUnlimitedStock,
                onUnlimitedStockChanged: (val) {
                  setState(() => _isUnlimitedStock = val);
                },
              ),
              const SizedBox(height: 24),

              // 4. Ubicación y mapa
              EventLocationForm(
                locationNameController: _locationNameController,
                addressController: _addressController,
                selectedLatLng: _selectedLatLng,
                onMapTap: _openMapPicker,
                selectedDepartmentId: _selectedDepartmentId,
                selectedProvinceId: _selectedProvinceId,
                selectedMunicipalityId: _selectedMunicipalityId,
                selectedCityId: _selectedCityId,
                onDepartmentChanged: (val) {
                  setState(() {
                    _selectedDepartmentId = val;
                    _selectedProvinceId = null;
                    _selectedMunicipalityId = null;
                    _selectedCityId = null;
                  });
                },
                onProvinceChanged: (val) {
                  setState(() {
                    _selectedProvinceId = val;
                    _selectedMunicipalityId = null;
                    _selectedCityId = null;
                  });
                },
                onMunicipalityChanged: (val) {
                  setState(() {
                    _selectedMunicipalityId = val;
                    _selectedCityId = null;
                  });
                },
                onCityChanged: (val) => setState(() => _selectedCityId = val),
              ),
              const SizedBox(height: 24),

              // 5. Fechas y horarios
              EventScheduleForm(
                startDate: _startDate,
                startTime: _startTime,
                endDate: _endDate,
                endTime: _endTime,
                onPickDateTime: _pickDateTime,
              ),
              const SizedBox(height: 28),

              // 6. Botón de creación
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
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Guardar Evento',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}