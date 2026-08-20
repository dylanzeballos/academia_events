import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/geographic_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/geographic_location_picker.dart';
import '../../../shared/widgets/loading_indicator.dart';
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
  bool _editing = false;
  Uint8List? _logoBytes;
  String? _logoExtension;

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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _legalNameCtrl.dispose();
    _descCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
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
        'city_id': ref.read(selectedCityIdProvider),
      });

      // Upload logo if changed
      if (_logoBytes != null && _logoExtension != null) {
        await repo.uploadLogoForOrg(
          orgId: orgId,
          bytes: _logoBytes!,
          extension: _logoExtension!,
        );
      }

      ref.invalidate(selectedOrganizationProvider);
      ref.invalidate(myOrganizationsProvider);
      setState(() {
        _editing = false;
        _logoBytes = null;
        _logoExtension = null;
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

  @override
  Widget build(BuildContext context) {
    final org = widget.organization;
    final resolvedLogoAsync = ref.watch(orgLogoUrlProvider(org.logoUrl));
    final resolvedLogo = resolvedLogoAsync.whenOrNull(data: (url) => url);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            GeographicLocationPicker(
              initialCityId: org.cityId,
              onCityChanged: (_) {},
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
                    onPressed: () => setState(() => _editing = false),
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
            if (org.cityName != null && org.cityName!.isNotEmpty)
              _InfoRow(label: 'Ubicación', value: org.cityName!),
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
