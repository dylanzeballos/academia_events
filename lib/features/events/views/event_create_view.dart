// lib/features/events/views/event_create_view.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_feedback.dart';
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

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _capacityController = TextEditingController();

  final _priceController = TextEditingController(text: '0');
  final _ticketStockController = TextEditingController(text: '100');
  bool _isUnlimitedStock = false;

  // Soporte de Teatro / Butacas numeradas
  bool _isTheatreEvent = false;
  String? _selectedVenueId;

  // Soporte de Documento / PDF de Reglamento
  Uint8List? _rulesPdfBytes;
  String? _rulesPdfFileName;

  final _locationNameController = TextEditingController();
  final _addressController = TextEditingController();

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

  Future<void> _pickRulesPdf() async {
    try {
      final dynamic picked = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (picked != null) {
        final dynamic firstItem = (picked is List)
            ? (picked.isNotEmpty ? picked.first : null)
            : (picked.files?.isNotEmpty == true ? picked.files.first : null);

        if (firstItem != null) {
          Uint8List? fileBytes;
          String fileName = 'reglamento.pdf';

          // 1. Obtener nombre del archivo
          try {
            fileName = (firstItem.name as String?) ?? fileName;
          } catch (_) {}

          // 2. Extraer los bytes según la plataforma (Web o Móvil)
          try {
            // Intentar leer propiedad directa .bytes
            fileBytes = firstItem.bytes as Uint8List?;
          } catch (_) {}

          // Si vino null o falló y tiene método readAsBytes() (WebPlatformFile / XFile)
          if (fileBytes == null) {
            try {
              fileBytes = await firstItem.readAsBytes();
            } catch (_) {}
          }

          // Si es Web y tiene readStream
          if (fileBytes == null) {
            try {
              final stream = firstItem.readStream;
              if (stream != null) {
                final List<int> byteList = [];
                await for (final chunk in stream) {
                  byteList.addAll(chunk);
                }
                fileBytes = Uint8List.fromList(byteList);
              }
            } catch (_) {}
          }

          // Si es Móvil/Desktop nativo y tiene path
          if (fileBytes == null) {
            try {
              final String? filePath = firstItem.path as String?;
              if (filePath != null) {
                final ioFile = File(filePath);
                if (await ioFile.exists()) {
                  fileBytes = await ioFile.readAsBytes();
                }
              }
            } catch (_) {}
          }

          if (fileBytes != null) {
            setState(() {
              _rulesPdfBytes = fileBytes;
              _rulesPdfFileName = fileName;
            });
          } else {
            if (mounted) {
              AppFeedback.error(
                context,
                'No se pudieron extraer los bytes del archivo',
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, 'No se pudo cargar el archivo PDF: $e');
      }
    }
  }

  void _removeRulesPdf() {
    setState(() {
      _rulesPdfBytes = null;
      _rulesPdfFileName = null;
    });
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
        SnackBar(
          content: const Text('No hay una organización seleccionada'),
          backgroundColor: context.cardBg,
        ),
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
        SnackBar(
          content: const Text('La fecha de fin debe ser posterior al inicio'),
          backgroundColor: context.cardBg,
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

      final ticketQuantity = _isUnlimitedStock
          ? 999999
          : (int.tryParse(_ticketStockController.text.trim()) ?? 100);

      final parsedCapacity = _capacityController.text.trim().isNotEmpty
          ? int.tryParse(_capacityController.text.trim())
          : (_isUnlimitedStock ? null : ticketQuantity);

      final eventData = {
        'organization_id': orgId,
        'category_id': _selectedCategoryId,
        'title': title,
        'slug': slug,
        'description': description.isNotEmpty
            ? description
            : 'la mejor de todas',
        'contact_phone': contact.isNotEmpty ? contact : null,
        'start_at': startAt.toIso8601String(),
        'end_at': endAt.toIso8601String(),
        'timezone': 'America/La_Paz',
        'status': 'published',
        'moderation_status': 'approved',
        'visibility': 'public',
        'requires_approval': false,
        'published_at': DateTime.now().toIso8601String(),
        'capacity': parsedCapacity,
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
          'name': _isTheatreEvent ? 'Butaca Numerada' : 'Entrada General',
          'description': _isTheatreEvent
              ? 'Asiento numerado en teatro'
              : 'Acceso general al evento',
          'price': parsedPrice,
          'quantity': ticketQuantity,
          'currency': 'BOB',
          'is_active': true,
        },
      ];

      await ref
          .read(eventsRepositoryProvider)
          .createFullEvent(
            eventData: eventData,
            locationData: locationData,
            ticketTypesData: ticketTypesData,
            bannerBytes: _bannerBytes,
            qrBytes: null,
            rulesPdfBytes: _rulesPdfBytes,
            venueId: _isTheatreEvent ? _selectedVenueId : null,
          );

      ref.invalidate(orgEventsProvider);
      ref.invalidate(weekEventsProvider);
      ref.invalidate(allEventsProvider);

      if (mounted) {
        context.pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Evento creado y publicado correctamente'),
            backgroundColor: context.cardBg,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('CREATE EVENT ERROR: $e');
      if (e is PostgrestException) {
        debugPrint(
          'PG code=${e.code} msg=${e.message} details=${e.details} hint=${e.hint}',
        );
      }
      if (e is StorageException) {
        debugPrint('STORAGE status=${e.statusCode} msg=${e.message}');
      }
      debugPrintStack(stackTrace: st);
      if (mounted) {
        AppFeedback.error(context, friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          'Crear Evento',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ImagePickerBox(
                label: 'Panfleto / Afiche del Evento',
                icon: Icons.add_photo_alternate_outlined,
                imageBytes: _bannerBytes,
                onTap: _pickBannerImage,
              ),
              const SizedBox(height: 20),

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

              // Tarjeta para subir el PDF de Reglamento / Código de vestimenta
              Card(
                color: context.cardBg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reglamento o Código de Vestimenta (PDF)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Adjunta las normas o especificaciones para los asistentes (opcional).',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      if (_rulesPdfFileName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.picture_as_pdf,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _rulesPdfFileName!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                onPressed: _removeRulesPdf,
                                tooltip: 'Quitar archivo',
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: _pickRulesPdf,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Seleccionar documento PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              EventTicketsEditor(
                priceController: _priceController,
                stockController: _ticketStockController,
                isUnlimitedStock: _isUnlimitedStock,
                onUnlimitedStockChanged: (val) {
                  setState(() => _isUnlimitedStock = val);
                },
              ),
              const SizedBox(height: 20),

              // Sección para Teatro y Butacas Numeradas
              Card(
                color: context.cardBg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '¿Evento en Teatro / Butacas numeradas?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Generará el plano físico con selección de asientos',
                        ),
                        value: _isTheatreEvent,
                        onChanged: (val) =>
                            setState(() => _isTheatreEvent = val),
                      ),
                      if (_isTheatreEvent) ...[
                        const SizedBox(height: 10),
                        ref
                            .watch(venuesListProvider)
                            .when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text(
                                'Error al cargar teatros: $e',
                                style: const TextStyle(color: AppColors.error),
                              ),
                              data: (venues) {
                                if (venues.isEmpty) {
                                  return const Text(
                                    'No hay plantillas de recintos registradas en la base de datos.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                                return DropdownButtonFormField<String>(
                                  initialValue: _selectedVenueId,
                                  decoration: InputDecoration(
                                    labelText: 'Selecciona el Teatro o Recinto',
                                    prefixIcon: const Icon(
                                      Icons.theater_comedy_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  items: venues.map((v) {
                                    return DropdownMenuItem<String>(
                                      value: v['id'] as String,
                                      child: Text(v['name'] as String),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedVenueId = val),
                                  validator: (val) =>
                                      _isTheatreEvent && val == null
                                      ? 'Selecciona un recinto para clonar las butacas'
                                      : null,
                                );
                              },
                            ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

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

              EventScheduleForm(
                startDate: _startDate,
                startTime: _startTime,
                endDate: _endDate,
                endTime: _endTime,
                onPickDateTime: _pickDateTime,
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Guardar Evento',
                        style: TextStyle(
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
