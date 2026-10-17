import 'package:flutter/material.dart';
import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

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
            const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.error),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 14,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
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