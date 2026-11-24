// lib/features/organization/views/organization_vip_plan_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/dance_category_model.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/class_purchase_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/vip_monthly_report_card.dart';

/// Configuración del pase VIP mensual de una organización.
class OrganizationVipPlanView extends ConsumerStatefulWidget {
  const OrganizationVipPlanView({super.key, required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<OrganizationVipPlanView> createState() =>
      _OrganizationVipPlanViewState();
}

class _OrganizationVipPlanViewState
    extends ConsumerState<OrganizationVipPlanView> {
  final _nameCtrl = TextEditingController(text: 'Pase VIP');
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  bool _includeAll = true;
  bool _active = true;
  final Set<String> _categoryIds = {};
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic>? config) {
    if (_loaded) return;
    _loaded = true;
    if (config == null) return;
    _nameCtrl.text = (config['name'] as String?) ?? 'Pase VIP';
    _descCtrl.text = (config['description'] as String?) ?? '';
    _priceCtrl.text = ((config['price_monthly'] as num?) ?? 0).toString();
    _includeAll = config['includes_all_classes'] as bool? ?? true;
    _active = config['is_active'] as bool? ?? true;
    final relations =
        (config['organization_vip_plan_categories'] as List?) ?? const [];
    for (final relation in relations.whereType<Map>()) {
      final id = relation['dance_category_id'] as String?;
      if (id != null) _categoryIds.add(id);
    }
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    if (price == null || price <= 0) {
      AppFeedback.warning(context, 'Ingresa un precio mensual mayor a 0.');
      return;
    }
    if (!_includeAll && _categoryIds.isEmpty) {
      AppFeedback.warning(
        context,
        'Selecciona al menos un ritmo o incluí todas las clases.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(classPurchaseRepositoryProvider)
          .saveVipPlan(
            organizationId: widget.organizationId,
            name: _nameCtrl.text,
            description: _descCtrl.text,
            priceMonthly: price,
            includesAllClasses: _includeAll,
            categoryIds: _categoryIds.toList(),
            isActive: _active,
          );
      ref.invalidate(vipPlanConfigProvider(widget.organizationId));
      ref.invalidate(vipPlanProvider(widget.organizationId));
      if (mounted) AppFeedback.success(context, 'Plan VIP guardado.');
    } catch (e) {
      if (mounted) AppFeedback.error(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isOrgAdminProvider);
    final configAsync = ref.watch(vipPlanConfigProvider(widget.organizationId));
    final categoriesAsync = ref.watch(danceCategoriesProvider);

    return configAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                friendlyError(e),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
                onPressed: () => ref.invalidate(
                  vipPlanConfigProvider(widget.organizationId),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (config) {
        _hydrate(config);

        if (!isAdmin) {
          if (config == null) {
            return Center(
              child: Text(
                'Esta academia todavía no ofrece pase VIP.',
                style: TextStyle(color: context.textMuted),
              ),
            );
          }
          return _VipSummary(
            organizationId: widget.organizationId,
            config: config,
            categories: categoriesAsync.value ?? const [],
          );
        }

        final categories =
            categoriesAsync.value ?? const <DanceCategoryModel>[];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pase VIP mensual',
                          style: TextStyle(
                            color: context.textOnBg,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Da acceso a varias sesiones de distintos ritmos '
                          'durante un mes. Elegí si incluye todas las clases '
                          'publicadas o solo algunos ritmos.',
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Datos del pase',
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              style: TextStyle(color: context.textOnBg),
              decoration: _decoration(context, 'Nombre del pase'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              style: TextStyle(color: context.textOnBg),
              decoration: _decoration(context, 'Descripción (opcional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: context.textOnBg),
              decoration: _decoration(context, 'Precio mensual (BOB)'),
            ),
            const SizedBox(height: 8),
            Text(
              'Disponibilidad',
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.primary,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: Text(
                'Ofrecer pase VIP',
                style: TextStyle(color: context.textOnBg),
              ),
              subtitle: Text(
                'Si está apagado, los alumnos no podrán comprarlo.',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.primary,
              value: _includeAll,
              onChanged: (v) => setState(() => _includeAll = v),
              title: Text(
                'Incluir todas las clases publicadas',
                style: TextStyle(color: context.textOnBg),
              ),
              subtitle: Text(
                'Desactivalo para elegir ritmos específicos.',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ),
            if (!_includeAll) ...[
              const SizedBox(height: 4),
              Text(
                'Ritmos incluidos',
                style: TextStyle(
                  color: context.textOnBg,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              if (categories.isEmpty)
                Text(
                  'No hay ritmos disponibles.',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final category in categories.where((c) => c.isActive))
                      FilterChip(
                        label: Text(category.name),
                        selected: _categoryIds.contains(category.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _categoryIds.add(category.id);
                          } else {
                            _categoryIds.remove(category.id);
                          }
                        }),
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.primary,
                      ),
                  ],
                ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _saving ? 'Guardando...' : 'Guardar plan VIP',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            VipMonthlyReportCard(organizationId: widget.organizationId),
          ],
        );
      },
    );
  }

  InputDecoration _decoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.textMuted),
      filled: true,
      fillColor: context.cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: BorderSide(color: context.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: BorderSide(color: context.divider),
      ),
    );
  }
}

class _VipSummary extends StatelessWidget {
  const _VipSummary({
    required this.organizationId,
    required this.config,
    required this.categories,
  });

  final String organizationId;
  final Map<String, dynamic> config;
  final List<DanceCategoryModel> categories;

  @override
  Widget build(BuildContext context) {
    final price = (config['price_monthly'] as num?) ?? 0;
    final includesAll = config['includes_all_classes'] as bool? ?? true;
    final active = config['is_active'] as bool? ?? false;
    final ids =
        ((config['organization_vip_plan_categories'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e['dance_category_id']?.toString())
            .whereType<String>()
            .toSet();
    final names = categories
        .where((c) => ids.contains(c.id))
        .map((c) => c.name)
        .join(', ');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          (config['name'] as String?) ?? 'Pase VIP',
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (config['description'] != null) ...[
          const SizedBox(height: 8),
          Text(
            config['description'] as String,
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          '${price.toStringAsFixed(2)} ${config['currency'] ?? 'BOB'} / mes',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          active ? 'Disponible para comprar' : 'No disponible por ahora',
          style: TextStyle(
            color: active ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          includesAll
              ? 'Incluye todas las clases publicadas de la academia.'
              : 'Incluye los ritmos: ${names.isEmpty ? 'sin ritmos configurados' : names}.',
          style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        VipMonthlyReportCard(organizationId: organizationId),
      ],
    );
  }
}
