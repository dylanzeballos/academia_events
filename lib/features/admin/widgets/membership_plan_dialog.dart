// lib/features/admin/widgets/membership_plan_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';

/// Formulario de alta/edición de un plan de membresía.
///
/// Devuelve un mapa con los valores listos para `AdminService.saveMembershipPlan`.
Future<Map<String, dynamic>?> showMembershipPlanDialog(
  BuildContext context, {
  Map<String, dynamic>? plan,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _MembershipPlanDialog(plan: plan),
  );
}

class _MembershipPlanDialog extends StatefulWidget {
  const _MembershipPlanDialog({this.plan});

  final Map<String, dynamic>? plan;

  @override
  State<_MembershipPlanDialog> createState() => _MembershipPlanDialogState();
}

class _MembershipPlanDialogState extends State<_MembershipPlanDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _currency;
  late final TextEditingController _maxEvents;
  late final TextEditingController _maxClasses;

  late String _interval;
  late bool _isActive;
  late bool _canCreateEvents;
  late bool _canCreateClasses;
  late bool _showInCalendar;

  bool get _isEdit => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _name = TextEditingController(text: plan?['name']?.toString() ?? '');
    _description = TextEditingController(
      text: plan?['description']?.toString() ?? '',
    );
    _price = TextEditingController(text: _formatPrice(plan?['price']));
    _currency = TextEditingController(
      text: (plan?['currency']?.toString().trim().isNotEmpty ?? false)
          ? plan!['currency'].toString().trim()
          : 'BOB',
    );
    _maxEvents = TextEditingController(
      text: plan?['max_events_per_month']?.toString() ?? '',
    );
    _maxClasses = TextEditingController(
      text: plan?['max_classes_per_month']?.toString() ?? '',
    );
    _interval = plan?['interval']?.toString() == 'yearly'
        ? 'yearly'
        : 'monthly';
    _isActive = plan?['is_active'] != false;
    _canCreateEvents = plan?['can_create_events'] == true;
    _canCreateClasses = plan?['can_create_classes'] == true;
    _showInCalendar = plan?['show_in_calendar'] == true;
  }

  String _formatPrice(Object? raw) {
    final value = double.tryParse(raw?.toString() ?? '');
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _currency.dispose();
    _maxEvents.dispose();
    _maxClasses.dispose();
    super.dispose();
  }

  int? _optionalInt(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = double.parse(_price.text.trim().replaceAll(',', '.'));
    Navigator.of(context).pop({
      'id': widget.plan?['id']?.toString(),
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price': price,
      'currency': _currency.text.trim().toUpperCase(),
      'interval': _interval,
      'isActive': _isActive,
      'canCreateEvents': _canCreateEvents,
      'canCreateClasses': _canCreateClasses,
      'showInCalendar': _showInCalendar,
      'maxEventsPerMonth': _optionalInt(_maxEvents),
      'maxClassesPerMonth': _optionalInt(_maxClasses),
    });
  }

  String? _validatePrice(String? value) {
    final price = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (price == null || price <= 0) {
      return 'Ingresá un precio mayor a cero';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Editar plan' : 'Nuevo plan'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'La app solo ofrece planes mensuales. El anual se guarda '
                  'pero no habilita publicar clases o eventos.',
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingMedium),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Mensual básico',
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Ingresá un nombre' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Precio',
                          prefixText: 'Bs ',
                        ),
                        validator: _validatePrice,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _currency,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: const InputDecoration(labelText: 'Moneda'),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.length != 3) return '3 letras';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _interval,
                  decoration: const InputDecoration(labelText: 'Frecuencia'),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                    DropdownMenuItem(value: 'yearly', child: Text('Anual')),
                  ],
                  onChanged: (value) =>
                      setState(() => _interval = value ?? 'monthly'),
                ),
                const SizedBox(height: 16),
                _PlanSwitch(
                  label: 'Plan activo',
                  helper: 'Solo los planes activos aparecen en la app.',
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                _PlanSwitch(
                  label: 'Puede crear eventos',
                  value: _canCreateEvents,
                  onChanged: (value) =>
                      setState(() => _canCreateEvents = value),
                ),
                _PlanSwitch(
                  label: 'Puede crear clases',
                  value: _canCreateClasses,
                  onChanged: (value) =>
                      setState(() => _canCreateClasses = value),
                ),
                _PlanSwitch(
                  label: 'Aparece en el calendario',
                  value: _showInCalendar,
                  onChanged: (value) => setState(() => _showInCalendar = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _maxEvents,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Máx. eventos / mes',
                          hintText: 'Sin límite',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxClasses,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Máx. clases / mes',
                          hintText: 'Sin límite',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _submit,
          child: Text(_isEdit ? 'Guardar cambios' : 'Crear plan'),
        ),
      ],
    );
  }
}

class _PlanSwitch extends StatelessWidget {
  const _PlanSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final String? helper;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        style: TextStyle(color: context.textOnBg, fontSize: 14),
      ),
      subtitle: helper == null
          ? null
          : Text(
              helper!,
              style: TextStyle(color: context.textMuted, fontSize: 11.5),
            ),
      value: value,
      onChanged: onChanged,
    );
  }
}
