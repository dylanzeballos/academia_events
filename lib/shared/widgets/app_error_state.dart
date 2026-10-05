import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/theme_extensions.dart';

/// Estado de error reutilizable con acción de reintento.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.message = 'Ocurrió un error. Inténtalo de nuevo.',
    this.onRetry,
    this.retryLabel = 'Reintentar',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.error),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textOnBg.withValues(alpha: 0.85),
                fontSize: 14,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
