import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Mensajes de feedback consistentes (SnackBar flotante con ícono y color).
abstract final class AppFeedback {
  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.success, Icons.check_circle_outline);

  static void error(BuildContext context, String message) =>
      _show(context, message, AppColors.error, Icons.error_outline);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.primary, Icons.info_outline);

  static void warning(BuildContext context, String message) =>
      _show(context, message, AppColors.warning, Icons.warning_amber_rounded);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          backgroundColor: color,
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

/// Traduce excepciones comunes a mensajes amigables en español.
String friendlyError(Object error) {
  final text = error.toString().replaceFirst('Exception: ', '');
  final lower = text.toLowerCase();
  if (lower.contains('permission') ||
      lower.contains('row-level security') ||
      lower.contains('not authorized') ||
      lower.contains('42501') ||
      lower.contains('no tienes permiso')) {
    return 'No tienes permiso para realizar esta acción.';
  }
  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('connection') ||
      lower.contains('timeout')) {
    return 'Revisa tu conexión e inténtalo de nuevo.';
  }
  if (lower.contains('duplicate') || lower.contains('already exists')) {
    return 'Ese registro ya existe.';
  }
  if (lower.contains('violates foreign key') ||
      lower.contains('constraint')) {
    return 'No se puede completar porque hay datos relacionados.';
  }
  if (text.isEmpty) return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  return 'No se pudo completar la operación. Inténtalo de nuevo.';
}
