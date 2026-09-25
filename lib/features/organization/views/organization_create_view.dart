import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../providers/geographic_provider.dart';
import '../../../shared/widgets/geographic_location_picker.dart';
import '../../events/widgets/map.dart';

class OrganizationCreateView extends ConsumerStatefulWidget {
  const OrganizationCreateView({super.key});

  @override
  ConsumerState<OrganizationCreateView> createState() =>
      _OrganizationCreateViewState();
}

class _OrganizationCreateViewState
    extends ConsumerState<OrganizationCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _locationNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  Uint8List? _logoBytes;
  String? _logoExtension;
  String? _logoPreviewPath;
  Uint8List? _coverBytes;
  String? _coverExtension;
  String? _coverPreviewPath;
  LatLng _selectedLatLng = const LatLng(-17.3935, -66.2825);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _legalNameCtrl.dispose();
    _descCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _locationNameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final image = await _pickImage();
    if (image == null) return;

    final bytes = await File(image.path).readAsBytes();
    final ext = image.path.split('.').last;

    setState(() {
      _logoBytes = bytes;
      _logoExtension = ext;
      _logoPreviewPath = image.path;
    });
  }

  Future<void> _pickCover() async {
    final image = await _pickImage();
    if (image == null) return;

    final bytes = await File(image.path).readAsBytes();
    final ext = image.path.split('.').last;

    setState(() {
      _coverBytes = bytes;
      _coverExtension = ext;
      _coverPreviewPath = image.path;
    });
  }

  Future<XFile?> _pickImage() async {
    final picker = ImagePicker();
    return picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1200,
      imageQuality: 80,
    );
  }

  Future<void> _openMapPicker() async {
    final pickedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerMap(initialLatLng: _selectedLatLng),
      ),
    );
    if (pickedLocation != null && mounted) {
      setState(() => _selectedLatLng = pickedLocation);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(createOrgProvider.notifier).create(
          name: _nameCtrl.text.trim(),
          legalName: _legalNameCtrl.text.trim().isEmpty
              ? null
              : _legalNameCtrl.text.trim(),
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          websiteUrl: _websiteCtrl.text.trim().isEmpty
              ? null
              : _websiteCtrl.text.trim(),
            locationName: _locationNameCtrl.text.trim().isEmpty
              ? null
              : _locationNameCtrl.text.trim(),
            address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
            latitude: _selectedLatLng.latitude,
            longitude: _selectedLatLng.longitude,
          logoBytes: _logoBytes,
          logoExtension: _logoExtension,
            coverBytes: _coverBytes,
            coverExtension: _coverExtension,
          departmentId: ref.read(selectedDepartmentIdProvider),
          provinceId: ref.read(selectedProvinceIdProvider),
          municipalityId: ref.read(selectedMunicipalityIdProvider),
        );

    if (success && mounted) {
      // El notifier ya activó el modo organización: navegar directo al
      // panel para que la UI se actualice al instante.
      final messenger = ScaffoldMessenger.of(context);
      context.go(AppRoutes.academyDashboard);
      messenger.showSnackBar(
        const SnackBar(content: Text('Organización creada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createOrgProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Organización'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.error != null)
                AppBanner(
                  message: state.error!,
                  onDismiss: () =>
                      ref.read(createOrgProvider.notifier).clearError(),
                ),

              // Logo picker
              Center(
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        backgroundImage: _logoPreviewPath != null
                            ? FileImage(File(_logoPreviewPath!))
                            : null,
                        child: _logoPreviewPath == null
                            ? const Icon(
                                Icons.business_outlined,
                                size: 40,
                                color: AppColors.primary,
                              )
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: context.textOnBg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Toca para agregar logo',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),

              GestureDetector(
                onTap: _pickCover,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    image: _coverPreviewPath != null
                        ? DecorationImage(
                            image: FileImage(File(_coverPreviewPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _coverPreviewPath == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.panorama_outlined,
                                size: 42, color: AppColors.primary),
                            SizedBox(height: 8),
                            Text('Agregar banner de la organización'),
                          ],
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit,
                                size: 18, color: context.textOnBg),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameCtrl,
                validator: AppValidators.eventTitle,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la organización *',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _legalNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre legal (opcional)',
                  prefixIcon: Icon(Icons.gavel_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Geographic location
              Text(
                'Ubicación',
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const GeographicLocationPicker(),
              const SizedBox(height: 16),

              TextFormField(
                controller: _locationNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lugar o sede (opcional)',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección (opcional)',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _openMapPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.divider),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        IgnorePointer(
                          child: FlutterMap(
                            key: ValueKey(
                              '${_selectedLatLng.latitude}_${_selectedLatLng.longitude}',
                            ),
                            options: MapOptions(
                              initialCenter: _selectedLatLng,
                              initialZoom: 15,
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
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              'Toca el mapa para elegir la ubicación  '
                              '${_selectedLatLng.latitude.toStringAsFixed(5)}, '
                              '${_selectedLatLng.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return AppValidators.email(v);
                },
                decoration: const InputDecoration(
                  labelText: 'Email (opcional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                validator: AppValidators.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _websiteCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Website (opcional)',
                  prefixIcon: Icon(Icons.language_outlined),
                ),
              ),
              const SizedBox(height: 32),

              AppButton(
                label: 'Crear Organización',
                isLoading: state.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
