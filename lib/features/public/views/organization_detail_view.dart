import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/organization_model.dart';
import '../../../../data/models/organization_image_model.dart';
import '../../../../providers/organization_provider.dart';
import '../../organization/widgets/organization_share_section.dart';
import './details/org_gallery_section.dart';
import './details/org_hero_header.dart';
import './details/org_location_section.dart';
import './details/public_schedule_view.dart';

class PublicOrganizationDetailView extends ConsumerStatefulWidget {
  const PublicOrganizationDetailView({
    super.key,
    required this.organizationId,
    this.organizationName,
  });

  final String organizationId;
  final String? organizationName;

  @override
  ConsumerState<PublicOrganizationDetailView> createState() =>
      _PublicOrganizationDetailViewState();
}

class _PublicOrganizationDetailViewState
    extends ConsumerState<PublicOrganizationDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(organizationRepositoryProvider)
          .recordOrganizationView(widget.organizationId)
          .catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final organizationId = widget.organizationId;
    final organizationAsync = ref.watch(
      publicOrganizationProvider(organizationId),
    );
    final galleryAsync = ref.watch(organizationImagesProvider(organizationId));

    return organizationAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0A0D14),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: const Color(0xFF0A0D14),
        body: Center(
          child: Text(
            'No se pudo cargar la organización: $error',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
      data: (organization) {
        final logoUrl = ref
            .watch(orgLogoUrlProvider(organization?.logoUrl))
            .whenOrNull(data: (url) => url);
        final coverUrl = ref
            .watch(orgLogoUrlProvider(organization?.coverImageUrl))
            .whenOrNull(data: (url) => url);

        return _buildContent(
          context,
          organization,
          galleryAsync,
          logoUrl: logoUrl,
          coverUrl: coverUrl,
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    OrganizationModel? organization,
    AsyncValue<List<OrganizationImageModel>> galleryAsync,
    {
    String? logoUrl,
    String? coverUrl,
    }
  ) {
    final org = organization;
    final name = org?.name ?? widget.organizationName ?? 'Academia de Baile';
    final phone = org?.phoneNumber ?? '';
    final location = [
      if (org?.locationName?.trim().isNotEmpty == true) org!.locationName!,
      if (org?.address?.trim().isNotEmpty == true) org!.address!,
    ].join(' · ');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D14),
        elevation: 0,
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Portada, Avatar, Rating & Botones
            OrgHeroHeader(
              name: name,
              coverUrl: coverUrl,
              logoUrl: logoUrl,
              logoTag: 'organization-logo-${widget.organizationId}',
              description: org?.description,
              location: location,
              whatsappNumber: phone,
              onShare: () {},
            ),

            if (org != null) ...[
              const SizedBox(height: 16),
              OrganizationShareSection(
                organization: org,
                compact: true,
              ),
            ],

            const SizedBox(height: 16),

            // ── BOTÓN DIRECTO: HORARIO SOLO LECTURA ──
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
                border: Border.all(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicScheduleView(
                          organizationId: widget.organizationId,
                          organizationName: name,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFF06B6D4),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Horario Semanal de Clases',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ver días, horas y profesores disponibles',
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.55),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF06B6D4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 2. Instalaciones y Galería Oficial
            OrgGallerySection(
              imagesAsync: galleryAsync,
            ),

            const SizedBox(height: 28),

            if (org != null)
              OrgLocationSection(
                organization: org,
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}