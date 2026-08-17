import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

enum BannerType { error, warning, info, success }

/// Banner de estado (error, aviso, info, éxito) reutilizable en cualquier formulario.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.type = BannerType.error,
    this.onDismiss,
  });

  final String message;
  final BannerType type;
  final VoidCallback? onDismiss;

  Color get _color => switch (type) {
        BannerType.error => AppColors.error,
        BannerType.warning => AppColors.warning,
        BannerType.info => AppColors.primary,
        BannerType.success => AppColors.success,
      };

  IconData get _icon => switch (type) {
        BannerType.error => Icons.error_outline,
        BannerType.warning => Icons.warning_amber_rounded,
        BannerType.info => Icons.info_outline,
        BannerType.success => Icons.check_circle_outline,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingMedium,
        vertical: AppSizes.paddingSmall + 2,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: _color, fontSize: 13),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, color: _color, size: 16),
            ),
        ],
      ),
    );
  }
}
