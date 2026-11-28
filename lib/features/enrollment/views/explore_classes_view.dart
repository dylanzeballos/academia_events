// lib/features/enrollment/views/explore_classes_view.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/organization_with_classes.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../providers/class_purchase_provider.dart';
import '../../../data/services/pagosya_service.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/schedule/weekly_schedule_grid.dart';
import '../../tickets/views/pagosya_checkout_screen.dart';

/// Explorar clases: elegís una academia y ves su horario semanal completo.
///
/// Antes se listaban las clases una debajo de otra; ahora el horario es la
/// superficie principal, con el selector de academias arriba.
class ExploreClassesView extends ConsumerStatefulWidget {
  const ExploreClassesView({super.key});

  @override
  ConsumerState<ExploreClassesView> createState() => _ExploreClassesViewState();
}

class _ExploreClassesViewState extends ConsumerState<ExploreClassesView> {
  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(organizationsWithPublishedClassesProvider);
    final selectedOrgId = ref.watch(selectedExploreOrgIdProvider);
    final selectedOrg = orgsAsync.value
        ?.where((o) => o.id == selectedOrgId)
        .firstOrNull;

    final vipAsync = selectedOrgId == null
        ? null
        : ref.watch(vipPlanProvider(selectedOrgId));
    final hasVipPlan = vipAsync?.value != null;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explorar clases',
              style: TextStyle(
                color: context.textOnBg,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            if (selectedOrg != null)
              Text(
                selectedOrg.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
          ],
        ),
        actions: [
          if (selectedOrgId != null && hasVipPlan)
            IconButton(
              tooltip: 'Pase VIP de la academia',
              icon: const Icon(Icons.stars_rounded, color: AppColors.warning),
              onPressed: () => _showVipPlan(selectedOrgId),
            ),
          IconButton(
            tooltip: 'Actualizar',
            icon: Icon(Icons.refresh_rounded, color: context.textMuted),
            onPressed: () {
              ref.invalidate(organizationsWithPublishedClassesProvider);
              if (selectedOrgId != null) {
                ref.invalidate(orgScheduleEntriesProvider(selectedOrgId));
              }
            },
          ),
        ],
      ),
      body: orgsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorState(
          message: friendlyError(e),
          onRetry: () =>
              ref.invalidate(organizationsWithPublishedClassesProvider),
        ),
        data: (orgs) {
          if (orgs.isEmpty) return const _NoOrganizations();

          final orgId = ref.read(selectedExploreOrgIdProvider);
          if (orgId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (ref.read(selectedExploreOrgIdProvider) == null) {
                ref
                    .read(selectedExploreOrgIdProvider.notifier)
                    .select(orgs.first.id);
              }
            });
          }

          return SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OrganizationSelector(
                  organizations: orgs,
                  selectedId: selectedOrgId,
                ),
                const Divider(height: 1),
                Expanded(
                  child: selectedOrgId == null
                      ? const _PickOrganization()
                      : WeeklyScheduleGrid(
                          key: ValueKey(selectedOrgId),
                          organizationId: selectedOrgId,
                          showAgendaView: true,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showVipPlan(String organizationId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.cardBg,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: _VipPlanCard(organizationId: organizationId),
      ),
    );
  }
}

/// Selector horizontal de academias: logo real (o ícono, nunca iniciales) y
/// cantidad de clases publicadas.
class _OrganizationSelector extends ConsumerWidget {
  const _OrganizationSelector({
    required this.organizations,
    required this.selectedId,
  });

  final List<OrganizationWithClasses> organizations;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: organizations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final org = organizations[index];
          final isSelected = org.id == selectedId;
          return _OrganizationChip(
            organization: org,
            isSelected: isSelected,
            onTap: () =>
                ref.read(selectedExploreOrgIdProvider.notifier).select(org.id),
          );
        },
      ),
    );
  }
}

class _OrganizationChip extends StatelessWidget {
  const _OrganizationChip({
    required this.organization,
    required this.isSelected,
    required this.onTap,
  });

  final OrganizationWithClasses organization;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final classCount = organization.publishedClassCount;

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${organization.name}, ${classCount == 1 ? '1 clase' : '$classCount clases'}',
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : context.cardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : context.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OrganizationAvatar(organization: organization),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organization.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        classCount == 1 ? '1 clase' : '$classCount clases',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganizationAvatar extends StatelessWidget {
  const _OrganizationAvatar({required this.organization});

  final OrganizationWithClasses organization;

  static const double _size = 34;

  @override
  Widget build(BuildContext context) {
    final logoUrl = organization.logoUrl;
    if (logoUrl == null || logoUrl.isEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.storefront_rounded,
          size: 17,
          color: AppColors.primary,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: _size,
          height: _size,
          color: context.divider.withValues(alpha: 0.25),
        ),
        errorWidget: (_, _, _) => Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.storefront_rounded,
            size: 17,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _PickOrganization extends StatelessWidget {
  const _PickOrganization();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Elegí una academia para ver su horario semanal.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textMuted, fontSize: 13.5),
        ),
      ),
    );
  }
}

class _NoOrganizations extends StatelessWidget {
  const _NoOrganizations();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Todavía no hay academias con clases',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                'Cuando una academia publique su horario va a aparecer acá.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VipPlanCard extends ConsumerStatefulWidget {
  const _VipPlanCard({required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<_VipPlanCard> createState() => _VipPlanCardState();
}

class _VipPlanCardState extends ConsumerState<_VipPlanCard> {
  bool _busy = false;

  Future<void> _buy() async {
    setState(() => _busy = true);
    try {
      final checkout = await const PagosyaService().createCheckout(
        kind: 'vip_membership',
        referenceId: widget.organizationId,
      );
      if (!mounted) return;
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PagosyaCheckoutScreen(checkout: checkout),
        ),
      );
      if (paid == true) {
        ref.invalidate(myVipMembershipsProvider);
        if (mounted) AppFeedback.success(context, 'Pase VIP activado.');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(vipPlanProvider(widget.organizationId));
    return planAsync.when(
      loading: () => const SizedBox(height: 120, child: LoadingIndicator()),
      error: (_, _) => const _NoVipPlan(),
      data: (plan) {
        if (plan == null) return const _NoVipPlan();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: AppColors.onPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${plan.priceMonthly.toStringAsFixed(0)} ${plan.currency}/mes',
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                plan.includesAllClasses
                    ? 'Acceso a todas las clases publicadas de la academia.'
                    : 'Acceso a ${plan.classCount} clases de los ritmos seleccionados.',
                style: TextStyle(
                  color: AppColors.onPrimary.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.onPrimary,
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: _busy ? null : _buy,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_2, size: 18),
                  label: Text(
                    _busy ? 'Generando cobro...' : 'Comprar pase VIP',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoVipPlan extends StatelessWidget {
  const _NoVipPlan();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'Esta academia no ofrece pase VIP por ahora.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.textMuted, fontSize: 13.5),
      ),
    );
  }
}
