// lib/features/admin/widgets/pagosya_plans_card.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../shared/widgets/app_section_card.dart';

/// Lista de planes de membresía con acciones de alta, edición y activación.
class PagosyaPlansCard extends StatelessWidget {
  const PagosyaPlansCard({
    super.key,
    required this.plans,
    required this.busy,
    required this.error,
    required this.onCreate,
    required this.onEdit,
    required this.onToggle,
    required this.onRetry,
  });

  final List<Map<String, dynamic>> plans;
  final bool busy;
  final String? error;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onToggle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Planes de membresía',
      icon: Icons.card_membership_outlined,
      trailing: TextButton.icon(
        style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: busy ? null : onCreate,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Nuevo'),
      ),
      children: [
        Text(
          'Solo los planes mensuales activos se ofrecen en la app y habilitan '
          'publicar clases y eventos.',
          style: TextStyle(
            color: context.textMuted,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        if (error != null) ...[
          Text(
            'No se pudieron cargar los planes: $error',
            style: TextStyle(color: AppColors.error, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: busy ? null : onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
          ),
        ] else if (plans.isEmpty)
          _EmptyState(busy: busy, onCreate: onCreate)
        else
          for (var i = 0; i < plans.length; i++) ...[
            if (i > 0) Divider(height: 20, color: context.divider),
            _PlanRow(
              plan: plans[i],
              busy: busy,
              onEdit: () => onEdit(plans[i]),
              onToggle: () => onToggle(plans[i]),
            ),
          ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.busy, required this.onCreate});

  final bool busy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Todavía no hay planes. Creá el primero para que las academias '
          'puedan comprar su membresía.',
          style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: busy ? null : onCreate,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Crear plan'),
        ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
  });

  final Map<String, dynamic> plan;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  String get _name => plan['name']?.toString() ?? 'Plan';

  String get _price {
    final value = double.tryParse(plan['price']?.toString() ?? '');
    final currency = plan['currency']?.toString().trim() ?? 'BOB';
    if (value == null) return 'Precio a definir';
    final decimals = value == value.roundToDouble() ? 0 : 2;
    return '$currency ${value.toStringAsFixed(decimals)}';
  }

  String get _interval =>
      plan['interval']?.toString() == 'yearly' ? 'anual' : 'mensual';

  String get _period =>
      plan['interval']?.toString() == 'yearly' ? 'año' : 'mes';

  bool get _active => plan['is_active'] != false;

  String? get _description {
    final value = plan['description']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  String get _capabilities {
    final items = <String>[
      if (plan['can_create_events'] == true) 'Crear eventos',
      if (plan['can_create_classes'] == true) 'Crear clases',
      if (plan['show_in_calendar'] == true) 'Calendario',
    ];
    return items.isEmpty ? 'Solo membresía' : items.join(' · ');
  }

  String get _limits {
    final events = int.tryParse(plan['max_events_per_month']?.toString() ?? '');
    final classes = int.tryParse(
      plan['max_classes_per_month']?.toString() ?? '',
    );
    final parts = <String>[
      if (events != null) '$events ${events == 1 ? 'evento' : 'eventos'}/mes',
      if (classes != null) '$classes ${classes == 1 ? 'clase' : 'clases'}/mes',
    ];
    return parts.isEmpty
        ? 'Sin límites mensuales'
        : 'Hasta ${parts.join(' y ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          '$_name, $_price al $_period, ${_active ? 'activo' : 'inactivo'}. '
          '$_capabilities. $_limits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_price · $_interval',
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppStatusChip(
                label: _active ? 'Activo' : 'Inactivo',
                color: _active ? AppColors.success : context.textMuted,
              ),
            ],
          ),
          if (_description != null) ...[
            const SizedBox(height: 6),
            Text(
              _description!,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '$_capabilities · $_limits',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: _active
                      ? AppColors.warning
                      : AppColors.success,
                ),
                onPressed: busy ? null : onToggle,
                icon: Icon(
                  _active
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 17,
                ),
                label: Text(_active ? 'Desactivar' : 'Activar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
