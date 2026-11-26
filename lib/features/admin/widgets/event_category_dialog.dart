// lib/features/admin/widgets/event_category_dialog.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';

/// Formulario de alta/edición de una categoría de eventos.
///
/// Devuelve un mapa con los valores listos para `AdminService.saveEventCategory`.
Future<Map<String, dynamic>?> showEventCategoryDialog(
  BuildContext context, {
  Map<String, dynamic>? category,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _EventCategoryDialog(category: category),
  );
}

class _EventCategoryDialog extends StatefulWidget {
  const _EventCategoryDialog({this.category});

  final Map<String, dynamic>? category;

  @override
  State<_EventCategoryDialog> createState() => _EventCategoryDialogState();
}

class _EventCategoryDialogState extends State<_EventCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late bool _isActive;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.category?['name']?.toString() ?? '',
    );
    _isActive = widget.category?['is_active'] != false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'id': widget.category?['id']?.toString(),
      'name': _name.text.trim(),
      'isActive': _isActive,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Editar categoría' : 'Nueva categoría'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Las categorías inactivas dejan de aparecer en los filtros y '
                'en el alta de eventos, pero se conservan en los eventos que '
                'ya las usan.',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSizes.paddingMedium),
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Taller, competencia, muestra…',
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Ingresá un nombre' : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Categoría activa',
                  style: TextStyle(color: context.textOnBg, fontSize: 14),
                ),
                subtitle: Text(
                  'Solo las activas se ofrecen al crear o filtrar eventos.',
                  style: TextStyle(color: context.textMuted, fontSize: 11.5),
                ),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
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
          child: Text(_isEdit ? 'Guardar cambios' : 'Crear categoría'),
        ),
      ],
    );
  }
}
