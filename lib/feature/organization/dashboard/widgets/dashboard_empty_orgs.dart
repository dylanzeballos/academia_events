// lib/feature/organization/dashboard/views/dashboard/dashboard_empty_orgs.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart' show AppRoutes;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/app_button.dart';

class DashboardEmptyOrgs extends StatelessWidget {
  const DashboardEmptyOrgs({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Aún no perteneces a ninguna organización',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea la tuya para administrar clases, eventos, profesores y entradas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Crear mi organización',
            icon: Icons.add_business_outlined,
            onPressed: () => context.push(AppRoutes.organizationsCreate),
          ),
        ],
      ),
    );
  }
}