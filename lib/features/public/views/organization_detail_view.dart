// lib/features/public/views/organization_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/organization_image_model.dart';
import '../../../../data/models/organization_model.dart';
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
      loading: () => Scaffold(
        backgroundColor: context.scaffoldBg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: context.scaffoldBg,
        body: Center(
          child: Text(
            'No se pudo cargar la organización: $error',
            style: TextStyle(color: context.textMuted),
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
    AsyncValue<List<OrganizationImageModel>> galleryAsync, {
    String? logoUrl,
    String? coverUrl,
  }) {
    final org = organization;
    final name = org?.name ?? widget.organizationName ?? 'Academia de Baile';
    final phone = org?.phoneNumber ?? '';
    final location = [
      if (org?.locationName?.trim().isNotEmpty == true) org!.locationName!,
      if (org?.address?.trim().isNotEmpty == true) org!.address!,
    ].join(' · ');

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.textOnBg,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Cabecera (Portada, Avatar, Info y WhatsApp a ancho completo)
            OrgHeroHeader(
              name: name,
              coverUrl: coverUrl,
              logoUrl: logoUrl,
              logoTag: 'organization-logo-${widget.organizationId}',
              description: org?.description,
              location: location,
              whatsappNumber: phone,
            ),

            // ── COMPARTIR Y CÓDIGO QR DE LA ACADEMIA ──
            if (org != null) ...[
              const SizedBox(height: 16),
              OrganizationShareSection(organization: org, compact: true),
            ],

            const SizedBox(height: 16),

            // ── HORARIO SEMANAL DE CLASES ──
            Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
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
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Horario Semanal de Clases',
                                style: TextStyle(
                                  color: context.textOnBg,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ver días, horas y profesores disponibles',
                                style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── INSCRIPCIONES Y PLANES (BOTÓN DESTACADO) ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'INSCRIPCIONES Y PLANES',
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
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primary,
                        Color(0xFF8B5CF6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                      onTap: () {
                        context.push(
                          '${AppRoutes.enrollClassDetail}/${widget.organizationId}',
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.assignment_turned_in_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Inscribirme a Clases',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Elige tu clase, paquete de sesiones o Pase VIP',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // 2. Instalaciones y Galería Oficial
            OrgGallerySection(imagesAsync: galleryAsync),

            const SizedBox(height: 28),

            // 3. Ubicación y Cómo Llegar (Tarjeta GPS interactiva)
            if (org != null) OrgLocationSection(organization: org),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}