import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/organization_image_model.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/geographic_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/geographic_location_picker.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../events/widgets/map.dart';
import '../widgets/organization_share_section.dart';
import 'organization_members_view.dart';

class OrganizationDetailView extends ConsumerStatefulWidget {
  const OrganizationDetailView({super.key});

  @override
  ConsumerState<OrganizationDetailView> createState() =>
      _OrganizationDetailViewState();
}

class _OrganizationDetailViewState
    extends ConsumerState<OrganizationDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgId = ref.watch(selectedOrganizationIdProvider);
    if (orgId == null) {
      return const Scaffold(body: Center(child: Text('Sin organización')));
    }

    final orgAsync = ref.watch(selectedOrganizationProvider);
    final isAdmin = ref.watch(isOrgAdminProvider);

    return orgAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (org) {
        if (org == null) {
          return const Scaffold(
              body: Center(child: Text('Organización no encontrada')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(org.name),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'INFO'),
                Tab(text: 'MIEMBROS'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _InfoTab(organization: org, isAdmin: isAdmin),
              const OrganizationMembersView(),
            ],
          ),
        );
      },
    );
  }
}

class _InfoTab extends ConsumerStatefulWidget {
  const _InfoTab({required this.organization, required this.isAdmin});

  final dynamic organization;
  final bool isAdmin;

  @override
  ConsumerState<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends ConsumerState<_InfoTab> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _legalNameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _locationNameCtrl;
  late final TextEditingController _addressCtrl;
  bool _editing = false;
  Uint8List? _logoBytes;
  String? _logoExtension;
  Uint8List? _coverBytes;
  String? _coverExtension;
  LatLng? _selectedLatLng;
  final List<XFile> _pendingGalleryImages = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.organization.name);
    _legalNameCtrl =
        TextEditingController(text: widget.organization.legalName);
    _descCtrl = TextEditingController(text: widget.organization.description);
    _emailCtrl = TextEditingController(text: widget.organization.email);
    _phoneCtrl = TextEditingController(text: widget.organization.phoneNumber);
    _websiteCtrl =
        TextEditingController(text: widget.organization.websiteUrl);
    _locationNameCtrl =
        TextEditingController(text: widget.organization.locationName);
    _addressCtrl = TextEditingController(text: widget.organization.address);
    if (widget.organization.latitude != null &&
        widget.organization.longitude != null) {
      _selectedLatLng = LatLng(
        widget.organization.latitude!,
        widget.organization.longitude!,
      );
    }
  }

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

  Future<void> _save() async {
    final orgId = widget.organization.id;
    final repo = ref.read(organizationRepositoryProvider);
    try {
      await repo.updateOrganization(orgId, {
        'name': _nameCtrl.text.trim(),
        'legal_name': _legalNameCtrl.text.trim().isEmpty
            ? null
            : _legalNameCtrl.text.trim(),
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'email':
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'phone_number':
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'website_url': _websiteCtrl.text.trim().isEmpty
            ? null
            : _websiteCtrl.text.trim(),
        'department_id': ref.read(selectedDepartmentIdProvider),
        'province_id': ref.read(selectedProvinceIdProvider),
        'municipality_id': ref.read(selectedMunicipalityIdProvider),
        'location_name': _locationNameCtrl.text.trim().isEmpty
          ? null
          : _locationNameCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
        'latitude': _selectedLatLng?.latitude,
        'longitude': _selectedLatLng?.longitude,
      });

      // Upload logo if changed
      if (_logoBytes != null && _logoExtension != null) {
        await repo.uploadLogoForOrg(
          orgId: orgId,
          bytes: _logoBytes!,
          extension: _logoExtension!,
        );
      }

      if (_coverBytes != null && _coverExtension != null) {
        await repo.uploadCoverForOrg(
          orgId: orgId,
          bytes: _coverBytes!,
          extension: _coverExtension!,
        );
      }

      for (final image in _pendingGalleryImages) {
        await repo.addOrganizationImage(
          orgId: orgId,
          bytes: await File(image.path).readAsBytes(),
          extension: image.path.split('.').last,
        );
      }

      ref.invalidate(selectedOrganizationProvider);
      ref.invalidate(myOrganizationsProvider);
      ref.invalidate(organizationImagesProvider(orgId));
      setState(() {
        _editing = false;
        _logoBytes = null;
        _logoExtension = null;
        _coverBytes = null;
        _coverExtension = null;
        _pendingGalleryImages.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Actualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image == null) return;

    final bytes = await File(image.path).readAsBytes();
    final ext = image.path.split('.').last;

    setState(() {
      _logoBytes = bytes;
      _logoExtension = ext;
    });
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() {
      _coverBytes = null;
      _coverExtension = image.path.split('.').last;
    });
    _coverBytes = await File(image.path).readAsBytes();
    if (mounted) setState(() {});
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerMap(
          initialLatLng: _selectedLatLng ?? const LatLng(-17.3935, -66.2825),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _selectedLatLng = picked);
  }

  Future<void> _addGalleryImages() async {
    final images = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (images.isEmpty) return;

    setState(() => _pendingGalleryImages.addAll(images));
  }

  Future<void> _deleteGalleryImage(OrganizationImageModel image) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar imagen'),
        content: const Text('Esta imagen se eliminará de la galería.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await ref.read(organizationRepositoryProvider).deleteOrganizationImage(image);
      ref.invalidate(organizationImagesProvider(widget.organization.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar la imagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = widget.organization;
    final resolvedLogoAsync = ref.watch(orgLogoUrlProvider(org.logoUrl));
    final resolvedLogo = resolvedLogoAsync.whenOrNull(data: (url) => url);
    final resolvedCoverAsync = ref.watch(orgLogoUrlProvider(org.coverImageUrl));
    final resolvedCover = resolvedCoverAsync.whenOrNull(data: (url) => url);
    final galleryAsync = ref.watch(organizationImagesProvider(org.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            GestureDetector(
              onTap: _editing ? _pickCover : null,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  image: _coverBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_coverBytes!), fit: BoxFit.cover)
                      : resolvedCover != null
                          ? DecorationImage(
                              image: NetworkImage(resolvedCover),
                              fit: BoxFit.cover,
                            )
                          : null,
                ),
                child: (_coverBytes == null && resolvedCover == null)
                    ? const Center(
                        child: Icon(Icons.panorama_outlined,
                            size: 44, color: AppColors.primary),
                      )
                    : _editing
                        ? const Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircleAvatar(
                                radius: 17,
                                backgroundColor: AppColors.primary,
                                child: Icon(Icons.edit,
                                    size: 17, color: Colors.white),
                              ),
                            ),
                          )
                        : null,
              ),
            ),
            const SizedBox(height: 20),
          // Logo
          Center(
            child: GestureDetector(
              onTap: _editing ? _pickLogo : null,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: _logoBytes != null
                        ? MemoryImage(_logoBytes!)
                        : resolvedLogo != null
                            ? NetworkImage(resolvedLogo)
                            : null,
                    child: (_logoBytes == null && resolvedLogo == null)
                        ? Text(
                            org.name.isNotEmpty ? org.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  if (_editing)
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
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Galería de la organización',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.isAdmin && _editing)
                IconButton(
                  tooltip: 'Agregar imágenes',
                  onPressed: _addGalleryImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  color: AppColors.primary,
                ),
            ],
          ),
          galleryAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'No se pudo cargar la galería: $error',
              style: const TextStyle(color: Colors.grey),
            ),
            data: (images) => images.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Todavía no hay imágenes adicionales.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, index) => _GalleryImageTile(
                      image: images[index],
                      canDelete: widget.isAdmin,
                      onDelete: () => _deleteGalleryImage(images[index]),
                    ),
                  ),
          ),
              if (_pendingGalleryImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '${_pendingGalleryImages.length} imagen(es) pendiente(s) de guardar',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: _pendingGalleryImages.length,
                  itemBuilder: (context, index) {
                    final image = _pendingGalleryImages[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(image.path), fit: BoxFit.cover),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            onPressed: () => setState(
                              () => _pendingGalleryImages.removeAt(index),
                            ),
                            icon: const Icon(Icons.close),
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              padding: const EdgeInsets.all(4),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
          const SizedBox(height: 24),

          OrganizationShareSection(organization: org),
          const SizedBox(height: 24),

          if (_editing) ...[
            // Modo edición
            TextFormField(
              controller: _nameCtrl,
              validator: AppValidators.eventTitle,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _legalNameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre legal'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _websiteCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Website'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ubicación',
              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const GeographicLocationPicker(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Lugar o sede',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                _selectedLatLng == null
                    ? 'Seleccionar ubicación en el mapa'
                    : 'Cambiar ubicación (${_selectedLatLng!.latitude.toStringAsFixed(5)}, '
                        '${_selectedLatLng!.longitude.toStringAsFixed(5)})',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Guardar',
                    onPressed: _save,
                    icon: Icons.save,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Cancelar',
                    onPressed: () => setState(() {
                      _editing = false;
                      _pendingGalleryImages.clear();
                    }),
                    isOutlined: true,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Modo lectura
            _InfoRow(label: 'Nombre', value: org.name),
            if (org.legalName != null && org.legalName!.isNotEmpty)
              _InfoRow(label: 'Nombre legal', value: org.legalName!),
            if (org.description != null && org.description!.isNotEmpty)
              _InfoRow(label: 'Descripción', value: org.description!),
            if (org.locationName != null && org.locationName!.isNotEmpty)
              _InfoRow(label: 'Lugar', value: org.locationName!),
            if (org.address != null && org.address!.isNotEmpty)
              _InfoRow(label: 'Dirección', value: org.address!),
            if (org.latitude != null && org.longitude != null)
              _InfoRow(
                label: 'Coordenadas',
                value:
                    '${org.latitude!.toStringAsFixed(5)}, ${org.longitude!.toStringAsFixed(5)}',
              ),
            if (org.email != null && org.email!.isNotEmpty)
              _InfoRow(label: 'Email', value: org.email!),
            if (org.phoneNumber != null && org.phoneNumber!.isNotEmpty)
              _InfoRow(label: 'Teléfono', value: org.phoneNumber!),
            if (org.websiteUrl != null && org.websiteUrl!.isNotEmpty)
              _InfoRow(label: 'Website', value: org.websiteUrl!),
            _InfoRow(
              label: 'Verificada',
              value: org.isVerified ? 'Sí' : 'No',
            ),
            _InfoRow(
              label: 'Estado',
              value: org.isActive ? 'Activa' : 'Inactiva',
            ),
            const SizedBox(height: 24),
            if (widget.isAdmin)
              AppButton(
                label: 'Editar',
                onPressed: () => setState(() => _editing = true),
                icon: Icons.edit,
                isOutlined: true,
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: context.textOnBg, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _GalleryImageTile extends ConsumerWidget {
  const _GalleryImageTile({
    required this.image,
    required this.canDelete,
    required this.onDelete,
  });

  final OrganizationImageModel image;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrlAsync = ref.watch(orgLogoUrlProvider(image.imageUrl));
    final imageUrl = imageUrlAsync.whenOrNull(data: (url) => url);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.broken_image_outlined),
              ),
            )
          else
            const ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (canDelete)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: 'Eliminar imagen',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
