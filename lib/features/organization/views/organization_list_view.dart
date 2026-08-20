import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/loading_indicator.dart';
import 'organization_create_view.dart';
import 'organization_detail_view.dart';

class OrganizationListView extends ConsumerWidget {
  const OrganizationListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(myOrganizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Organizaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OrganizationCreateView(),
              ),
            ),
          ),
        ],
      ),
      body: orgsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: AppBanner(message: 'Error: $e'),
        ),
        data: (orgs) {
          if (orgs.isEmpty) {
            return _EmptyState(
              onCreate: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrganizationCreateView(),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(myOrganizationsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orgs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final orgWithRole = orgs[index];
                final org = orgWithRole.organization;
                final role = orgWithRole.role;

                return _OrganizationCard(
                  name: org.name,
                  description: org.description,
                  logoUrl: org.logoUrl,
                  role: role.displayName,
                  isVerified: org.isVerified,
                  onTap: () {
                    ref
                        .read(selectedOrganizationIdProvider.notifier)
                        .select(org.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrganizationDetailView(),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrganizationCard extends ConsumerWidget {
  const _OrganizationCard({
    required this.name,
    this.description,
    this.logoUrl,
    required this.role,
    this.isVerified = false,
    required this.onTap,
  });

  final String name;
  final String? description;
  final String? logoUrl;
  final String role;
  final bool isVerified;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedLogoAsync = ref.watch(orgLogoUrlProvider(logoUrl));
    final resolvedLogo = resolvedLogoAsync.whenOrNull(data: (url) => url);

    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage:
                    resolvedLogo != null ? NetworkImage(resolvedLogo) : null,
                child: resolvedLogo == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: context.textOnBg,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    if (description != null && description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role,
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
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.business_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Sin organizaciones',
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea tu primera organización para\nempezar a gestionar eventos y clases.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Crear organización'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
