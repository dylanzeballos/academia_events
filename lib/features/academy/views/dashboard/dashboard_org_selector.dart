// lib/features/academy/views/dashboard/dashboard_org_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/organization_member_model.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../providers/organization_provider.dart';
import '../../../../shared/widgets/fullscreen_image_viewer.dart';

class DashboardOrgSelector extends ConsumerWidget {
  const DashboardOrgSelector({
    super.key,
    required this.orgs,
    required this.selectedOrgId,
    this.currentRole,
    required this.onSelected,
  });

  final List orgs;
  final String? selectedOrgId;
  final MemberRole? currentRole;
  final ValueChanged onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    OrganizationWithRole selectedOrgWithRole = orgs.first;
    for (final item in orgs) {
      if (item.organization.id == selectedOrgId) {
        selectedOrgWithRole = item;
        break;
      }
    }

    final org = selectedOrgWithRole.organization;
    final logoAsync = ref.watch(orgLogoUrlProvider(org.logoUrl));
    final logoUrl = logoAsync.whenOrNull(data: (url) => url);

    void openOrgDetails() {
      final id = ref.read(selectedOrganizationIdProvider);
      if (id != null) {
        context.push('${AppRoutes.organizationsDetail}/$id');
      }
    }

    return Card(
      color: context.cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        // Al tocar toda la tarjeta se navega a detalles, miembros y membresías
        onTap: openOrgDetails,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // ── 1. LOGO INDEPENDIENTE ──
              GestureDetector(
                onTap: logoUrl == null
                    ? null
                    : () => FullscreenImageViewer.show(
                          context,
                          logoUrl,
                          tag: 'dashboard-org-logo-${org.id}',
                        ),
                child: Hero(
                  tag: 'dashboard-org-logo-${org.id}',
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage:
                        logoUrl != null ? NetworkImage(logoUrl) : null,
                    child: logoUrl == null
                        ? Text(
                            org.name.isNotEmpty
                                ? org.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // ── 2. NOMBRE, ROL Y SUBTÍTULO ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (orgs.length > 1)
                      DropdownButtonHideUnderline(
                        child: DropdownButton(
                          isDense: true,
                          value: selectedOrgId,
                          dropdownColor: context.cardBg,
                          style: TextStyle(
                            color: context.textOnBg,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          items: orgs.map((o) {
                            return DropdownMenuItem(
                              value: o.organization.id,
                              child: Text(
                                o.organization.name,
                                style: TextStyle(color: context.textOnBg),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) onSelected(v);
                          },
                        ),
                      )
                    else
                      Text(
                        org.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (currentRole != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              currentRole!.displayName,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            'Miembros • Info • Membresías',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textMuted.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── 3. ÍCONO DE GESTIÓN Y FLECHA INDICADORA ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: context.divider.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: context.textMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}