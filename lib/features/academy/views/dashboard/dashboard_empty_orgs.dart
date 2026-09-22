import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
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
          Icon(
            Icons.storefront_outlined,
            size: 64,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no perteneces a ninguna organización',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea la tuya para administrar clases, eventos, profesores y entradas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
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