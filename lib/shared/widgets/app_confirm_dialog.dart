import 'package:flutter/material.dart';
import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/theme/app_colors.dart';

/// Diálogo de confirmación estándar de la app.
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