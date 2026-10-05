import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Diálogo de confirmación estándar de la app.
///
/// Devuelve `true` si el usuario confirma y `false` si cancela o cierra.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool isDangerous = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      icon: Icon(
        icon ?? (isDangerous ? Icons.warning_amber_rounded : Icons.help_outline),
        color: isDangerous ? AppColors.error : AppColors.primary,
        size: 30,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: isDangerous
              ? FilledButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Diálogo de confirmación que además pide un texto (p. ej. un motivo).
///
/// Devuelve el texto introducido si se confirma, o `null` si se cancela.
/// Si [isRequired] es `true`, no permite confirmar con el campo vacío.
Future<String?> showAppPrompt(
  BuildContext context, {
  required String title,
  required String message,
  String label = 'Motivo',
  String hint = '',
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool isDangerous = false,
  bool isRequired = false,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final value = controller.text.trim();
          final canConfirm = !isRequired || value.isNotEmpty;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            ),
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 1,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hint.isEmpty ? null : hint,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(cancelLabel),
              ),
              FilledButton(
                onPressed: canConfirm
                    ? () => Navigator.pop(ctx, controller.text.trim())
                    : null,
                style: isDangerous
                    ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}
