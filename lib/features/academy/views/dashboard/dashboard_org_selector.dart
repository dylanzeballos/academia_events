import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/organization_member_model.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../providers/organization_provider.dart';
import '../../../organization/views/organization_detail_view.dart';

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
    // Selección directa sin firstWhere ni orElse
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

    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null,
              child: logoUrl == null
                  ? Text(
                      org.name.isNotEmpty ? org.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
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
                            child: Text(o.organization.name),
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
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (currentRole != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currentRole!.displayName,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Editar organización',
              icon: const Icon(Icons.edit_outlined),
              color: AppColors.primary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrganizationDetailView(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}